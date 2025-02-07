"
Utilities that don't fit anywhere else.
"

(require hyrule [->>])

(import hyjinx [config llm])

(import pathlib [Path])
(import platformdirs [user-config-dir])


(defclass NoteWorthyError [RuntimeError])

;; * file and toml config utilities
;; -----------------------------------------------------------------------------

(defn load-config [#^ str [fname "config"]]
  "Load a config file from `$XDG_CONFIG_DIR/noteworthy/config.toml`.
  Defaults to `.config/noteworthy/config.toml`."
  (->> fname
    (Path (user-config-dir __package__))
    (find-toml-file)
    (config)))

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
