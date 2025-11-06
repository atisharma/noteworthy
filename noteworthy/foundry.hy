"
The information foundry.

Here, we manage knowledge distillation and
synthesis, and record it in vector databases.
"

(require hyrule [-> ->> of])
(require hyjinx.llm [definstruct])

(import asyncio [run gather Lock])
(import collections.abc [Generator])
(import itertools [chain])

(import hyrule [assoc])
(import json-repair.json-repair [repair-json])
(import json)
(import datetime [datetime])
(import logging)
(import pathlib [Path])
(import warnings [warn])

(import hyjinx.lib [slurp now hash-id
                    first last second
                    flatten chain
                    hash-id now
                    filenames filetype
                    mkdir])

(import tqdm.asyncio [tqdm :as async-tqdm])
(import tqdm [tqdm])

(import fvdb [db split])
(import fvdb.embeddings [embed max-length tokenize token-count])

(import noteworthy.util [NoteWorthyError
                         NoteWorthyWarning
                         load-config 
                         instruct
                         async-chat-client
                         load-prompt
                         validate])

(setv config (load-config))

(setv logger (logging.getLogger __package__))

(setv facts-vdb (db.faiss (Path (:vdb-path config) "facts"))
      insights-vdb (db.faiss (Path (:vdb-path config) "insights")))

(setv _distil-token-length (:token-length config 7000))

;; The vdb write and insert lock
(setv lock (Lock))

;; Connections are closed when these client objects are garbage collected.
(setv distil-client (async-chat-client "distillation"))
(setv synth-client (async-chat-client "synthesis"))


(defn :async distil [#^ str text * #^ str source]
  "Distils the provided text into a list of self-contained knowledge atoms,
  stored for later retrieval.

  This function sends the full source text to an LLM with a specialized prompt
  to identify and structure every distinct idea, event, or finding into a
  consistent JSON format, and stores it in the facts vdb for later recall.

  Args:
    text (str): The raw text to be processed, from a document or recent
      chat context.
    source (str): A verbatim citation for the source.

  Returns:
    list[dict]: A list of dictionaries, where each dictionary is a knowledge atom.
    Returns empty list on failure."
  (try
    (let [response (await (instruct distil-client (load-prompt "distil") text))
          atoms (-> response
                  (repair-json :return-objects True)
                  (validate ["title" "date" "idea" "details"]))]
      (when atoms
        (with [:async lock]
          (db.ingest facts-vdb (lfor atom atoms
                                 {"added" (now)
                                  "embedding" (embed (json.dumps atom))
                                  "hash" (hash-id (json.dumps atom))
                                  "source" source
                                  #** atom}))
          (db.write facts-vdb))
        atoms))
    (except [e [Exception]]
      (logger.warn f"Error in `foundry.distil` over {source}: {e}")
      [{"error" f"Error in `foundry.distil` over {source}: {e}"}])))

(defn :async synthesize [#^ (of list dict) atoms * #^ str [context ""]]
  "Synthesizes a new, higher-order understanding from notes.

  This function sends the provided notes to an LLM with a specialized prompt
  to forge a novel, non-obvious connection between them.

  Args:
    atoms (list[dict]): A list of note dictionaries, typically
      the output of a `recall` call.
    context (str, optional): A noteworthy observation or idea, typically
      from a chat with a user.

  Returns:
    dict: A dictionary representing the candidate synthesis note.
    Returns None if synthesis fails."
  (let [text (.join "\n---\n" [(json.dumps atoms) context])
        insight (-> (await (instruct synth-client (load-prompt "synthesize") text))
                  (repair-json :return-objects True)
                  (validate ["theme"
                             "understanding"
                             "analysis" 
                             "sources"
                             "questions"]))
        decision (await (referee insight))
        is-good (and decision
                     (= (:decision decision None) "RECORD")
                     (> (:confidence decision 0) 0.8))]
    (with [:async lock]
      (db.ingest insights-vdb [{"added" (now)
                                "embedding" (embed (json.dumps insight))
                                "hash" (hash-id (json.dumps insight))
                                "source" (hash-id (json.dumps (:sources insight)))
                                "is_good" is-good
                                #** decision
                                #** insight}])
      (db.write insights-vdb))
    {#** insight #** decision}))

(defn :async referee [#^ dict insight]
  "Determines if a candidate synthesis entry is novel enough to record.

  This function evaluates the candidate against a set of prior entries and
  strict novelty criteria.

  Args:
    insight (dict): The dictionary containing the candidate synthesis.

  Returns:
    dict: A dictionary with the decision (RECORD or REJECT), novelty type,
      reasoning and confidence; or None if the referee fails."
  (let [similar-insights (db.similar insights-vdb (json.dumps insight))
        text (+ (json.dumps similar-insights) "\n---\n" (json.dumps insight))
        decision (-> (await (instruct synth-client (load-prompt "referee") text))
                   (repair-json :return-objects True)
                   (validate ["decision"
                              "novelty_type"
                              "one_sentence_punchline"
                              "confidence"
                              "reason"]))]
    ;; enforce a numerical confidence
    (try
      (assoc decision "confidence" (float (:confidence decision)))
      (except [ValueError]
        (assoc decision "confidence" 0.0)))
    decision))

(defn recall [#^ str query * #^ str [mode "hybrid"] #^ int [top 5] #^ float [threshold 0.75] #^ bool [rerank True]]
  "Retrieves relevant context from the dual-store knowledge base.

  Performs a semantic search across distilled fact and synthesis notes,
  with options for reranking for higher precision.

  Args:
    query (str): The natural language query.
    search-mode (str): \"facts\", \"insights\", or \"hybrid\". Default \"hybrid\".
    top (int): The maximum number of results to return. Default 5.
    threshold (float): The minimum relevance score. Default 0.75.
    rerank (bool): Whether to apply a cross-encoder re-ranking step. Default True.

  Returns:
    list[dict:] A list of dictionaries containing the retrieved facts and/or insights.
    Returns None on failure."
  ;; TODO rerank
  (if (= mode "hybrid")
    (+ (recall query :mode "insights" :top top :threshold threshold :rerank rerank)
       (recall query :mode "facts" :top top :threshold threshold :rerank rerank))
    (let [vdb (match mode
                "insights" insights-vdb
                "facts" facts-vdb)
          results (db.similar vdb query :top top)]
      (lfor result results
        :if (> (:score result) threshold)
        result))))

(defn delete [#^ dict vdb * #^ str hash]
  "Marks a knowledge atom or synthesis note for later deletion.

  This is a soft delete. The entry is flagged for removal and will be excluded
  from future calls to recall. Calling `prune` will permanently delete flagged
  entries.

  Args:
    vdb (str): the name of the vdb, must be either 'facts-vdb' or 'insights-vdb'.
    hash (str): The unique identifier for the note to be deleted.

  Returns:
    vdb-info: info about the vdb."
  (let [_vdb (match vdb
               "facts-vdb" facts-vdb
               "insights-vdb" insights-vdb
               "else" (raise (NoteWorthyError "Bad argument: vdb must be either 'facts-vdb' or 'insights-vdb'.")))
        records (:records _vdb)
        deletion-time (now)]
    (assoc _vdb
           "records" (lfor record records
                       (if (= (:hash record) hash)
                         {#** record "error" f"marked for deletion at {deletion-time}"}
                         record))
           "dirty" True)
    (db.write _vdb)
    (db.info _vdb)))

(defn delete-bad []
  "Marks all 'bad' (rejected) knowledge synthesis notes for later deletion.

  This is a soft delete. The entry is flagged for removal and will be excluded
  from future calls to recall. Calling `prune` and writing will permanently
  delete flagged entries.

  Args: None

  Returns:
    vdb-info: info about the vdb."
  (let [records (:records insights-vdb)
        deletion-time (now)]
    (assoc insights-vdb
           "records" (lfor record records
                       (if (:is-good record True)
                         record
                         {#** record "error" f"marked for deletion at {deletion-time}"}))
           "dirty" True)
    (db.write insights-vdb)
    (db.info insights-vdb)))

(defn prune [#^ str [vdb "facts-vdb"]]
  "Actually delete all entries flagged for removal.

  Args:
    vdb (str): the name of the vdb, must be either 'facts-vdb' or 'insights-vdb'.

  Returns:
    vdb-info: info about the vdb."
  (let [_vdb (match vdb
               "facts-vdb" facts-vdb
               "insights-vdb" insights-vdb
               "else" (raise (NoteWorthyError "Bad argument: vdb must be either 'facts-vdb' or 'insights-vdb'.")))]
    (db.prune _vdb)
    (db.write _vdb)
    (db.info _vdb)))

(defn info [#^ str [vdb "facts-vdb"]]
  "Give information about the chosen vdb.

  Args:
    vdb (str): the name of the vdb, must be either 'facts-vdb' or 'insights-vdb'.

  Returns:
    vdb-info: info about the vdb."
  (let [_vdb (match vdb
               "facts-vdb" facts-vdb
               "insights-vdb" insights-vdb
               "else" (raise (NoteWorthyError "Bad argument: vdb must be either 'facts-vdb' or 'insights-vdb'.")))]
    (db.info _vdb)))


(defn distil-files [#^ (| Path str) fname-or-directory]
  "Distil file or all files under a directory (recursively).
  Splits are made according to file type.
  Returns a list of knowledge atoms."
  (cond
    (.is-file (Path fname-or-directory))
    (run (distil-file fname-or-directory))

    (.is-dir (Path fname-or-directory))
    (run (distil-dir fname-or-directory))

    :else
    (raise (FileNotFoundError fname-or-directory))))

(defn :async distil-dir [#^ (| Path str) directory]
  "Distil all files under a directory (recursively).
  Splits are made according to file type.
  Returns a list of knowledge atoms."
  ;; `filenames` ignores certain directories by default
  (let [pbar (async-tqdm (filenames directory) :desc directory)]
    (for [:async fname pbar]
      (await (distil-file fname)))))

(defn :async distil-file [#^ (| Path str) fname]
  "Distils the contents of the text file with path `fname` into a list of
  self-contained knowledge atoms, stored for later retrieval.

  This function sends the full source text to an LLM with a specialized prompt
  to identify and structure every distinct idea, event, or finding into a
  consistent JSON format, and stores it in the facts vdb for later recall.

  Args:
    fname (str): The local path for the file to be processed.

  Returns:
    list[dict]: A list of dictionaries, where each dictionary is a knowledge atom.
    Returns empty list on failure."
  ;; TODO overlap of approx. 900 tokens
  (let [ft (filetype fname)
        chunks (try
                 (split._chunk-by-filetype (slurp fname) ft :max-length _distil-token-length)
                 (except [e [Exception]]
                   (logger.error f"Error in `foundry/distil-file` while splitting {fname}: {e}.")))]

    (defn :async distil-fname [text]
      (try
        (await (distil text :source fname))
        (except [e [NoteWorthyError]]
          (logger.error f"Error in `foundry/distil-file` distilling {fname}: {e}."))))

    (await (async-tqdm.gather #* (map distil-fname chunks)
                              :leave False
                              :desc (. (Path fname) name)))))
