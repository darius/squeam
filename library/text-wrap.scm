;; Like Python's textwrap.
;; TODO try using Parson
;; TODO the Python names are pretty arbitrary

(to (fill text width)
  ("\n" .join (wrap text width)))

(to (wrap text width)
  (surely (< 0 width))  ;TODO 'require' or something, for preconditions
  (wrap-into (flexarray<-) (parse-tokens text) width))

(to (flush buffer)
  (string<-list buffer.values))

(to (parse-tokens text)
  (if text.empty?
      '()
      (may text.first
        (be #\newline (link {break} (parse-tokens text.rest)))
        (be #\space   (link {space} (parse-tokens text.rest)))
        (be (? _.whitespace? ch)
          (error "I don't know how to fill whitespace like" ch))
        (else
          (let word (flexarray<- text.first))
          (begin eating ((text text.rest))
            (if (or text.empty? text.first.whitespace?)
                (link {word (flush word)} (parse-tokens text))
                (do (word .push! text.first)
                    (eating text.rest))))))))

(to (wrap-into line tokens width)
  (begin scanning ((spaces 0) (tokens tokens))
    (if tokens.empty?
        (if line.empty? '() `(,(flush line)))
        (may tokens.first
          (be {break}
            (link (flush line) (wrap-into (flexarray<-) tokens.rest width)))
          (be {space}
            (scanning (+ spaces 1) tokens.rest))
          (be {word s}
            (if (<= (+ line.count spaces s.count) width)
                (do (line .extend! (chain (" " .repeat spaces) s))
                    (scanning 0 tokens.rest))
                (link (flush line)
                      (hide
                        (let new-line (flexarray<-))
                        (new-line .extend! s)
                        (wrap-into new-line tokens.rest width)))))))))


(to (main `(,_ ,width-str ,@words))
  (let lines (wrap (" " .join words)
                   (number<-string width-str)))
  (each! print lines))

(export fill wrap)