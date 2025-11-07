"
Utilities that don't fit anywhere else.
"

(require hyrule [-> ->> of])
(require hyjinx [defmethod])

(import asyncio [Semaphore])
(import logging)
(import pathlib [Path])
(import platformdirs [user-state-path user-config-path])

(import hyjinx [first config llm slurp])
(import fvdb.config [cfg :as fvdb-config])
(import trag.template [file-exists])


(defclass NoteWorthyError [RuntimeError])
(defclass NoteWorthyWarning [UserWarning])

;; stop the client barfing retry messages
(.setLevel (.getLogger logging "openai._base_client") logging.ERROR)


;; * file and toml config utilities
;; -----------------------------------------------------------------------------

(defn load-config [#^ str [fname "config"]]
  "Load a config file from `$XDG_CONFIG_HOME/noteworthy/config.toml`.
  Defaults to `.config/noteworthy/config.toml`.
  The `vdb_path` defaults to `$XDG_STATE_HOME/noteworthy/`."
  (let [cfg (->> f"{fname}.toml"
              (Path (user-config-path __package__))
              (config))]
    {"vdb_path" (Path (user-state-path __package__ :ensure-exists True))
     #** cfg}))

;; has to appear after load-config function definition
(setv _config (load-config)
      _max-concurrent-tasks (:concurrency _config 4)
      api-limiter (Semaphore _max-concurrent-tasks))  

(defn chat-client [#^ str client]
  "Create a chat client object from the specification in the config file.
  See `hyjinx.llm` for methods and further documentation."
  (let [client-cfg (get (load-config) client)
        provider (.pop client-cfg "provider")
        model (.pop client-cfg "model" None)
        client (match provider
                 "anthropic" (llm.Anthropic #** client-cfg)
                 "openai" (llm.OpenAI #** client-cfg)
                 "tabby" (llm.TabbyClient #** client-cfg)
                 "huggingface" (llm.Huggingface #** client-cfg))]
    (when model
      (llm.model-load client model))
    client))

(defn async-chat-client [#^ str client #** kwargs]
  "Create a chat client object from the specification in the config file.
  See `hyjinx.llm` for methods and further documentation."
  (let [client-cfg (get (load-config) client)
        provider (.pop client-cfg "provider")
        model (.pop client-cfg "model" None)
        options (.pop client-cfg "options" {})
        client (match provider
                 "anthropic" (llm.AsyncAnthropic #** client-cfg)
                 "openai" (llm.AsyncOpenAI #** client-cfg)
                 "tabby" (llm.AsyncTabbyClient #** client-cfg)
                 "huggingface" (llm.AsyncHuggingface #** client-cfg))]
    (setv client.defaults options)
    (when model
      (llm.model-load client model))
    client))

(defn :async instruct [client #^ str system-prompt #^ str text #** kwargs]
  "Private LLM instruction.
  OpenAI-compatible only."
  (with [:async _ api-limiter]
    (let [messages [{"role" "system" "content" system-prompt}
                    {"role" "user" "content" text}]
          response (await
                     (client.chat.completions.create
                       :messages messages
                       :model client.model
                       :stream False
                       #** client.defaults
                       #** kwargs))]
      (. (. (first response.choices) message) content))))

(defn find-prompt [#^ str name * [caller "."]]
  "Locate a prompt file, `name.prompt`.
  It will look under, in order:
    - `$pwd/prompts/`               -- prompts in the current dir
    - `$XDG_CONFIG_DIR/nwy`         -- user-defined prompts
    - `$module_dir/prompts`         -- the standard templates

  Reads the path to the file.
  "
  (let [fname f"{name}.prompt"]
    (or
      (file-exists (Path "prompts" fname))
      (file-exists (Path (user-config-path __package__) fname))
      (file-exists (Path (. (Path caller) parent) "prompts" fname))
      (file-exists (Path (. (Path __file__) parent) "prompts" fname))
      (raise (FileNotFoundError [fname
                                 (Path "prompts" fname)
                                 (Path (user-config-path __package__) fname)
                                 (Path (. (Path caller) parent) "prompts" fname)
                                 (Path (. (Path __file__) parent) "prompts" fname)])))))

(defn load-prompt [#^ str name * [caller "."]]
  "Return the contents of a prompt file as a string."
  (slurp (find-prompt name)))

(defmethod validate [#^ dict d #^ (of list str) keys]
  "Enforce that a dict has the listed keys, defaulting to value None, removing extraneous keys."
  (dfor key keys key (d.get key)))

(defmethod validate [#^ (of list dict) records #^ (of list str) keys]
  "Enforce that every dict in the list has the listed keys, defaulting to value None, removing extraneous keys."
  (lfor record records
    (validate record keys)))

(defmethod validate [#^ list records #^ (of list str) keys]
  "Enforce that every dict in the list has the listed keys, defaulting to value None, removing extraneous keys."
  (lfor record records
    (validate record keys)))

(defmethod validate [#^ str records #^ (of list str) keys]
  "Enforce that every dict in the list has the listed keys, defaulting to value None, removing extraneous keys."
  [{"error" f"JSON validation failed: {records} -> {(.join ", " keys)}"}])
