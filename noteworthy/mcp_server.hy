#!/usr/bin/env hy
"
Noteworthy MCP server

A Model Context Protocol (MCP) server that exposes knowledge distillation,
synthesis and RAG tools.
"

(require hyrule [defmain -> ->>])

(import os)
(import logging)
(import typing [List Dict Optional])
(import mcp.server.fastmcp [FastMCP Context])

(import hyjinx.lib [slurp ls filenames])
(import noteworthy [__version__])
(import trag) 
(import fvdb) 
(import noteworthy [foundry])
(import trag [retrieve])


(logging.basicConfig :level logging.INFO)
(setv logger (logging.getLogger __package__))

(setv mcp-config (:server (load-config) {}))
(setv mcp (FastMCP "noteworthy_mcp_server"
            :host (:host mcp-config "0.0.0.0")
            :port (:port mcp-config 3000)))


;; tools from the foundry
;;-----------------------------------------------------------------------------

(defn :async [(mcp.tool)] distil-url [#^ str url]
  "Retrieves content from a URL, converts it to markdown and then distils it
  into a list of self-contained knowledge atoms, stored for later retrieval.

  This function sends the URL's text to an LLM with a specialized prompt
  to identify and structure every distinct idea, event, or finding into a
  consistent JSON format, and stores it in the facts vdb for later recall.

  Args:
    url (str): The URL to retrieve

  Returns:
    list[dict]: A list of dictionaries, where each dictionary is a knowledge atom.

  Example:
    distil-url('https://example.org')
  "
  (await
    (-> url
      (retrieve.url)
      (foundry.distil :source url))))

(defn :async [(mcp.tool)] distil-arxiv [#^ str arxiv-id]
  "Retrieves content from the LaTeX source files from arXiv, and then distils it
  into a list of self-contained knowledge atoms, stored for later retrieval.

  This function sends the text to an LLM with a specialized prompt to identify
  and structure every distinct idea, event, or finding into a consistent JSON
  format, and stores it in the facts vdb for later recall.

  Args:
    arxiv_id (str): The arXiv ID of the paper (e.g. 1001.3100 or 1706.03762).
    remove_appendix_section (bool): Whether to remove the appendix section and
      everything after it

  Returns:
    list[dict]: A list of dictionaries, where each dictionary is a knowledge atom.

  Example:
    distil-arxiv('1706-03762')"
  (await
    (-> arxiv-id
      (arxiv-latex)
      (foundry.distil :source url))))

(defn :async [(mcp.tool)] distil-youtube [#^ str youtube-id]
  "Retrieves a YouTube transcript, and then distils it into a list of
  self-contained knowledge atoms, stored for later retrieval.

  This function sends the transcript to an LLM with a specialized prompt
  to identify and structure every distinct idea, event, or finding into a
  consistent JSON format, and stores it in the facts vdb for later recall.

  Args:
    youtube_id (str): the id of the youtube video

  Returns:
    list[dict]: A list of dictionaries, where each dictionary is a knowledge atom.
    
  Example:
    distil-youtube('xyz123')
  "
  (await (-> url
           (retrieve.youtube)
           (foundry.distil :source url))))


(defn :async [(mcp.tool)] record-insight [#^ str text * #^ int [top 5]] 
  "Record an important insight arising from the conversation.

  This function sends `text` to an LLM with a specialized prompt
  to forge a novel, non-obvious connection between the text and
  previous knowledge.

  Args:
    text (str): The noteworthy observation or idea, typically
      arising from a chat with a user. This should convey the 
      theme and novel understanding and insight.
    top (int, optional): The number of similar results to recall
      when comparing against previous ideas.

  Returns:
    dict: A dictionary representing the candidate synthesis note.
    Returns None if synthesis fails."
  (let [facts (foundry.recall text :top top)] 
    (await (foundry.synthesize facts :context text))))


((mcp.tool) foundry.recall)
((mcp.tool) foundry.distil)

;; vdb management tools
((mcp.tool) foundry.delete-bad)
((mcp.tool) foundry.delete)
((mcp.tool) foundry.prune)

;; tools from trag
;;-----------------------------------------------------------------------------

((mcp.tool :name "arxiv_summaries") retrieve.arxiv)
((mcp.tool) retrieve.book-search)
((mcp.tool) retrieve.ddg-news)
((mcp.tool) retrieve.location)
((mcp.tool) retrieve.url)
((mcp.tool) retrieve.weather)

(defn [(mcp.tool)] arxiv-latex [#^ str arxiv-id]
  "Process LaTeX source files from arXiv and return the combined content.

  Args:
    arxiv_id (str): The arXiv ID of the paper (e.g. 1001.3100 or 1706.03762).
    remove_appendix_section (bool): Whether to remove the appendix section and
      everything after it

  Returns:
    The whole LaTeX content (str) or None if processing fails"
  (retrieve.arxiv-latex arxiv-id :keep-comments False :use-cache True))

(defn [(mcp.tool)] wikipedia [#^ str topic]
  "Get the full Wikipedia page on a topic (as text).
  Disambiguates onto the first disambiguation.
  
  Args:
    topic (str): the Wikipedia topic.
  
  Returns:
    str: the full Wikipedia text on the topic."
  (retrieve.wikipedia topic))

(defn [(mcp.tool)] youtube [#^ str youtube-id]
  "Fetch the transcript of a youtube video.

  Args:
    youtube_id: the id of the youtube video

  Returns:
    the transcript of the video as a string.
    
  Example:
    youtube('xyz123')
  "
  (retrieve.youtube youtube-id))


;; other tools
;;-----------------------------------------------------------------------------

((mcp.tool) os.listdir)

(defn [(mcp.tool)] read-file [#^ str fname] 
  "Read a file in the filesystem and return it as a string.

  Args:
    fname (str): the filename to read.

  Returns:
    str: the file as a string."
  (slurp fname))


;; main entry point
;;-----------------------------------------------------------------------------

(defmain []
  "Main entry point for the noteworthy server."
  (logger.info f"Starting noteworthy MCP Server.")
  (logger.info f"noteworthy {__version__}")
  (logger.info f"fvdb {fvdb.__version__}")
  (logger.info f"trag {trag.__version__}")
  (mcp.run :transport "streamable-http"))

