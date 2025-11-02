(import click)

(import noteworthy.pipelines [pdf-to-latex
                              pdf-to-markdown
                              img-to-latex
                              img-to-markdown])


;; TODO: option to override the default model, multiple files as args

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

;; TODO foundry

(defn ; distil
  [(click.command)
   (click.argument "files_or_directories" :nargs -1)]
  distil [files-or-directories]
  (import foundry [distil-files])
  (for [file-or-directory files-or-directories]
    (let [records (distil-files file-or-directory)])))
  
(cli.add-command distil)

(defn ; recall
  [(click.command)
   (click.option "-m" "--mode" :default "hybrid" :help "Recall mode (hybrid | facts | insights).")
   (click.option "-r" "--top" :default 6 :type int :help "Return just top n results.")
   (click.argument "query")]
  recall [query * mode top]
  (import foundry [recall])
  (let [facts (recall query :mode mode :top top)]
    (click.echo
      (dumps facts :indent 2))))

(cli.add-command recall)

(defn ; synthesize
  [(click.command)
   (click.option "-m" "--mode" :default "hybrid" :help "Recall mode (hybrid | facts | insights).")
   (click.option "-r" "--top" :default 6 :type int :help "Return just top n results.")
   (click.argument "context" :help "The thought to consider.")]
  recall [insight * mode top]
  (import foundry [synthesize recall])
  (let [facts (recall query :mode mode :top top)
        insight (synthesize facts :context context)]
    (click.echo
      (dumps facts :indent 2)
      (dumps insight :indent 2))))

(cli.add-command synthesize)
