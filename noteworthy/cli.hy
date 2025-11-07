(import click)
(import asyncio [run])
(import json [dumps])

(import noteworthy.pipelines [pdf-to-latex
                              pdf-to-markdown
                              img-to-latex
                              img-to-markdown])


;; TODO: option to override the default fvdb model

(defn [(click.group)]
      cli [])


;; vision / conversion tools
;; -------------------------------------------------------------------------

(defn ; pdf2latex
  [(click.command)
   (click.argument "path")]
  pdf2latex [path]
  (click.echo
    (pdf-to-latex path :save True)))

(cli.add-command pdf2latex)

(defn ; pdf2md
  [(click.command)
   (click.argument "path")]
  pdf2md [path]
  (click.echo
    (pdf-to-markdown path :save True)))

(cli.add-command pdf2md)

(defn ; img2latex
  [(click.command)
   (click.argument "path")]
  img2latex [path]
  (click.echo
    (img-to-latex path :save True)))

(cli.add-command img2latex)

(defn ; img2md
  [(click.command)
   (click.argument "path")]
  img2md [path]
  (click.echo
    (img-to-markdown path :save True)))

(cli.add-command img2md)


;; knowledge distillation and synthesis vdb tools
;; -------------------------------------------------------------------------

(defn ; distil
  [(click.command)
   (click.argument "files_or_directories" :nargs -1)]
  distil [files-or-directories]
  (import noteworthy [foundry])
  (for [file-or-directory files-or-directories]
    (foundry.distil-files file-or-directory)))
  
(cli.add-command distil)

(defn ; distil-urls
  [(click.command)
   (click.argument "urls" :nargs -1)]
  distil-url [urls]
  (import noteworthy [mcp-server])
  (for [url urls]
    (run (mcp-server.distil-url url))))
  
(cli.add-command distil-url)

(defn ; distil-arxiv
  [(click.command)
   (click.argument "arxiv-ids" :nargs -1)]
  distil-arxiv [arxiv-ids]
  (import noteworthy [mcp-server])
  (for [arxiv-id arxiv-ids]
    (run (mcp-server.distil-arxiv arxiv-id))))
  
(cli.add-command distil-arxiv)

(defn ; recall
  [(click.command)
   (click.option "-m" "--mode" :default "hybrid" :help "Recall mode (hybrid | facts | insights).")
   (click.option "-r" "--top" :default 6 :type int :help "Return just top n results.")
   (click.argument "query")]
  recall [query * mode top]
  (import noteworthy [foundry])
  (let [facts (foundry.recall query :mode mode :top top)]
    (click.echo
      (dumps facts :indent 2))))

(cli.add-command recall)

(defn ; synthesize
  [(click.command)
   (click.option "-m" "--mode" :default "hybrid" :help "Recall mode (hybrid | facts | insights).")
   (click.option "-r" "--top" :default 6 :type int :help "Return just top n results.")
   (click.argument "context")]
  synthesize [insight * mode top]
  (import noteworthy [foundry]) 
  (let [facts (foundry.recall query :mode mode :top top)
        insight (foundry.synthesize facts :context context)]
    (click.echo
      (dumps facts :indent 2)
      (dumps insight :indent 2))))

(cli.add-command synthesize)

(defn ; prune
  [(click.command)]
  prune []
  (import noteworthy [foundry])
  (click.echo
    (foundry.prune "insights-vdb")
    (foundry.prune "facts-vdb")))

(cli.add-command prune)

(defn ; info
  [(click.command)]
  nwy-info []
  (import noteworthy [foundry])
  (click.echo
    (foundry.info "insights-vdb")
    (foundry.info "facts-vdb")))

(cli.add-command nwy-info)

