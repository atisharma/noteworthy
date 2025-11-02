;; TODO move to hyjinx
"
A simple ncurses-based table viewer for a list of dictionaries.
"

(require hyrule [of unless -> ->>])
(require hyjinx [defmethod])

(import curses)
(import json)
(import textwrap [wrap])

(import hyjinx.lib [first])
(import hyjinx.screen [Screen])


(defclass DictViewer []
  "A viewer for a list of dictionaries using the Screen class."

  (defn __init__ [self data stdscr]
    (setv self.screen (Screen stdscr)
          self.data data
          self.index 0
          self.key-index 0
          self.search-string ""
          self.search-direction 1)
    (curses.halfdelay 1))

  (defn __del__ [self])

  (defn __enter__ [self]
    self)

  (defn __exit__ [self exc-type exc-val exc-tb]
    (curses.nocbreak)
    (stdscr.keypad False)
    (curses.echo))

  (defn _draw [self]
    "Draw the entire screen: headers, data, and status bar."
    (.clear self.screen.window)
    (setv [h w] (.getmaxyx self.screen.window))
    (setv self.view-height (- h 1)) ; Reserve one line for the status bar
    (when self.data
      ;; Data Rows
      (setv visible-data (get self.data self.index)
            keys (list (.keys visible-data))
            key (get keys (% self.key-index (len keys)))
            value (wrap (str (get visible-data key)) w :replace-whitespace False :drop-whitespace False))
      (for [[y line] (enumerate (.split (json.dumps visible-data :indent 2) "\n"))]
        (.put self.screen (+ 1 y) 0 line))
      (.put self.screen (+ 3 y) 0 (* "-" w))
      (.put self.screen (+ y 5) 0 key :style curses.A_BOLD)
      (for [[y2 line] (enumerate value)]
        (.put self.screen (+ y 7 y2) 0 line)))

    ;; Status Bar
    (when (>= self.view-height 2)
      (setv num-rows (len self.data)
            status-line f"{self.index}/{num-rows}"
            y-bottom (- self.view-height 1) ; The UI class `bottom` can also be used
            prompt "  q:quit  j/k:↓/↑  h/l:key  g:top  G:bottom  /:search  n:next  N:prev")
      (unless (not self.search-string)
        (setv status-line (+ status-line f" Search: '{self.search-string}'")))
      (.put self.screen y-bottom 0 status-line :style curses.A_REVERSE)
      (.put self.screen y-bottom (- w (len prompt)) prompt :col 0))

    (.refresh self.screen.window))

  (defn _move-to [self index]
    "Move the cursor to an index."
    (setv self.index (% index (len self.data))))

  (defn _move [self amount]
    "Move the cursor forward by amount."
    (self._move-to (+ self.index amount)))

  (defn _move-key [self amount]
    "Move the key cursor forward by amount."
    (setv self.key-index (+ amount self.key-index)))

  (defn _prompt-goto [self]
    "Prompt the user for a line number to go to."
    (setv instr (.input self.screen ":goto "))
    (try
      (setv line-num (int instr))
      (except [ValueError]
        (self.screen.error "Invalid number: {line-num}")
        (return)))
    (self._move-to line-num))

  (defn run [self]
    "Main event loop for the viewer."
    (unless self.data
      (print "No data to display.")
      (return))

    (while True
      (self._draw)
      (setv key (self.screen.getkey))
      
      (cond
        (= key "q") (break)
        ; Basic navigation
        (in key ["j" "KEY_DOWN" "KEY Codes 605 606"]) (self._move 1)
        (in key ["k" "KEY_UP"]) (self._move -1)
        (in key ["h" "KEY_LEFT"]) (self._move-key 1)
        (in key ["l" "KEY_RIGHT"]) (self._move-key -1)
        (in key ["KEY_NPAGE" "6"]) (self._move 50) ; PageDown
        (in key ["KEY_PPAGE" "2"]) (self._move -50) ; PageUp
        (in key ["g" "KEY_HOME"]) (setv self.index 0)
        (in key ["G" "KEY_END"]) (setv self.index (- (len self.data) 1))
        ; Goto
        (= key ":") (self._prompt-goto)
        ; Refresh on resize
        (= key "KEY_RESIZE") (do
                               (setv [h w] (.getmaxyx self.screen.window))
                               (setv self.view-height (- h 1))
                               (continue))))))


(defmethod view [#^ (of list dict) records]
  (defn run-viewer [stdscr]
    (let [viewer (DictViewer records stdscr)]
      (.run viewer)))

  (let [stdscr (.initscr curses)]
    (curses.wrapper run-viewer)))

(defmethod view [#^ dict vdb]
  (view (:records vdb)))
