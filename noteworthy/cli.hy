(import click)

(import noteworthy.pipelines [pdf-to-latex pdf-to-markdown])


(defn [(click.group)]
      cli [])

(defn [(click.command)
       (click.argument "path")]
  pdftolatex [path]
  (click.echo
    (pdf-to-latex path :save True)))

(cli.add-command pdftolatex)


(defn [(click.command)
       (click.argument "path")]
  pdftomd [path]
  (click.echo
    (pdf-to-markdown path :save True)))

(cli.add-command pdftomd)

