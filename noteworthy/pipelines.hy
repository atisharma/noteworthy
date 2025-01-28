"
pdf -> markdown
pdf -> latex

Maybe these could all be within trag?
"

(require hyrule.argmove [-> ->>])

(import hyjinx.lib [spit])
(import hyjinx.llm [image-content _completion _msg])
(import noteworthy.util [chat-client])
(import pathlib [Path])
(import fitz)


;; a nod to sn2md for inspiration
(setv latex-prompt "Convert the image to valid latex. In your response, only include what would appear inside the document environment. Just start directly with the content, don't give any preamble.
If there is a diagram or image, and it is a simple diagram that you can create in tikz, create a tikz diagram for it. When it is unclear what an image is, don't output anything for it.
Assume text is not in a codeblock. Do not wrap any text in codeblocks.
Use the `equation` or `equation*` environments for equations. You can assume the `mathtools`, `tikz` and other common packages are already loaded.")

(setv markdown-prompt "Convert the image to valid markdown. Just start directly with the content, don't give any preamble.
If there is a diagram or image, and it is a simple diagram that you can create in mermaid, create a mermaid diagram for it. When it is unclear what an image is, don't output anything for it.
Assume text is not in a codeblock. Do not wrap any text in codeblocks.
You can use the inline latex equation environments, suitable for processing with mathjax or similar.")


(defn pdf-to-pixmaps [fname]
  "Convert a pdf to an iterator over pages,
  returning pixmap each page."
  (let [document (fitz.open fname)]
    (gfor p (range document.page-count)
      (-> p
        (document.load-page)
        (.get-pixmap :dpi 300)))))

(defn pdf-to-format [fname * [output-format "latex"] [save True] [verbose False]]
  "Convert pdf to a latex snippet."
  (let [client (chat-client "claude")
        basename (. (Path fname) stem)
        prompt (match output-format
                 "latex" latex-prompt
                 "markdown" markdown-prompt)]
    (.join "\n\n"
      (lfor [p pixmap] (enumerate (pdf-to-pixmaps fname))
        (let [png-name f"/tmp/nw_{basename}_p{p :04d}.png"]
          (.save pixmap png-name)   
          (when verbose
            (print png-name))
          (let [msgs [(_msg "user" (image-content client prompt png-name))]
                tex (.join "" (_completion client msgs))]
            (.unlink (Path png-name))
            (if save
              (spit f"{basename}.tex" tex)
              tex)))))))

(defn pdf-to-markdown [fname #** kwargs]
  (pdf-to-format fname :output-format "markdown" #** kwargs))

(defn pdf-to-latex [fname #** kwargs]
  (pdf-to-format fname :output-format "latex" #** kwargs))
