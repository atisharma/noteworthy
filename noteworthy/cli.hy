(import click)

(import noteworthy.pipelines [pdf-to-latex
                              pdf-to-markdown
                              img-to-latex
                              img-to-markdown])


;; TODO: option to override the default model, multiple files as args

(defn [(click.group)]
      cli [])

(defn [(click.command)
       (click.argument "path")]
  pdf2latex [path]
  (click.echo
    (pdf-to-latex path :save True)))

(cli.add-command pdf2latex)


(defn [(click.command)
       (click.argument "path")]
  pdf2md [path]
  (click.echo
    (pdf-to-markdown path :save True)))

(cli.add-command pdf2md)


(defn [(click.command)
       (click.argument "path")]
  img2latex [path]
  (click.echo
    (img-to-latex path :save True)))

(cli.add-command img2latex)


(defn [(click.command)
       (click.argument "path")]
  img2md [path]
  (click.echo
    (img-to-markdown path :save True)))

(cli.add-command img2md)

