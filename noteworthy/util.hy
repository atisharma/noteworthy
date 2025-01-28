"
Utilities that don't fit anywhere else.
"

;; TODO: move what we can back to hyjinx

(import hyjinx [config llm])

(import os)
(import pathlib [Path])
(import platformdirs [user-config-dir])


(defclass NoteWorthyError [RuntimeError])

;; * file and toml utilities (taken from trag)
;; -----------------------------------------------------------------------------

(defn file-exists [path]
  "Return Path object if it exists as a file, otherwise None."
  (when (.exists path)
    path))

(defn find-toml-file [#^ str name]
  "Locate a toml file.
  It will look under, in order:
    - `$pwd/templates/`         -- templates in the current dir
    - `$XDG_CONFIG_DIR/trag/`   -- user-defined config templates
    - `$module_dir/templates/`  -- the standard templates
  "
  (let [fname (+ name ".toml")]
    (or
      (file-exists (Path "templates" fname))
      (file-exists (Path (user-config-dir __package__) fname))
      (file-exists (Path (os.path.dirname __file__) "templates" fname)) ; TODO: use Path not os
      (raise (FileNotFoundError fname)))))

(defn load-config [#^ str [fname "config"]]
  "Load a config file.
  Defaults to `.config/noteworthy/config.toml`.
  See `find-toml-file` for search order."
  (config (find-toml-file fname)))

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
