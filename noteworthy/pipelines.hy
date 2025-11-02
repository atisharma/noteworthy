"
pdf -> markdown
img -> markdown
pdf -> latex
img -> latex
"

(require hyrule.argmove [-> ->>])

(import hyjinx.lib [spit])
(import hyjinx.llm [image-content _completion _msg])
(import noteworthy.util [chat-client load-prompt])
(import pathlib [Path])
(import fitz)


;; a nod to sn2md for inspiration
(setv latex-prompt (load-prompt "latex"))
(setv markdown-prompt (load-prompt "markdown"))

;; * Conversion from PDF (PDF -> pixmap -> png -> output)
;; -----------------------------------------------------------------------------

(defn pdf-to-pixmaps [fname]
  "Convert a pdf to an iterator over pages,
  returning pixmap each page."
  (let [document (fitz.open fname)]
    (gfor p (range document.page-count)
      (-> p
        (document.load-page)
        (.get-pixmap :dpi 300)))))

(defn pdf-to-format [fname * [output-format "tex"] [save True] [verbose False]]
  "Convert pdf to a latex or markdown snippet."
  (let [_client (chat-client "vision")
        basename (. (Path fname) stem)
        prompt (match output-format
                 "tex" latex-prompt
                 "md" markdown-prompt)
        output (.join "\n\n"
                 (gfor [p pixmap] (enumerate (pdf-to-pixmaps fname))
                   (let [png-name f"/tmp/nw_{basename}_p{p :04d}.png"]
                     (.save pixmap png-name)
                     (when verbose
                       (print png-name))
                     (let [msgs [(_msg "user" (image-content _client prompt png-name))]
                           text (.join "" (_completion _client msgs))]
                       (.unlink (Path png-name))
                       text))))]
    (if save
      (spit f"{basename}.{output-format}" output)
      output)))

(defn pdf-to-markdown [fname #** kwargs]
  "Convert pdf to a markdown snippet."
  (pdf-to-format fname :output-format "md" #** kwargs))

(defn pdf-to-latex [fname #** kwargs]
  "Convert pdf to a latex snippet."
  (pdf-to-format fname :output-format "tex" #** kwargs))


;; * Conversion from image (png, jpeg, etc)
;; -----------------------------------------------------------------------------

(defn img-to-format [fname [output-format "tex"] [save True] [verbose False]]
  "Convert an image in supported format to a latex or markdown snippet.
  Currently, Claude supports image/jpeg, image/png, image/gif and image/webp.
  OpenAI supports image/jpeg, image/png and image/webp.
  Other providers are probably similar."
  (let [_client (chat-client "vision")
        basename (. (Path fname) stem)
        prompt (match output-format
                 "tex" latex-prompt
                 "md" markdown-prompt)
        output (let [msgs [(_msg "user" (image-content _client prompt fname))]
                     text (.join "" (_completion _client msgs))]
                 (when verbose
                   (print fname))
                 text)]
    (if save
      (spit f"{basename}.{output-format}" output)
      output)))

(defn img-to-markdown [fname #** kwargs]
  "Convert img to a markdown snippet."
  (img-to-format fname :output-format "md" #** kwargs))

(defn img-to-latex [fname #** kwargs]
  "Convert img to a latex snippet."
  (img-to-format fname :output-format "tex" #** kwargs))
