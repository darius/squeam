;; Parson's concrete language-independent syntax
;; XXX untested
;; XXX leaving out regexes, fnord, anonymous start
;; XXX need to parameterize by semantics

(import (use "lib/hashset.scm") union)
(import (use "lib/parson.scm")
        invert capture either then feed-list feed push seclude delay maybe many at-least-1
        fail empty end skip-1 take-1 any-1 skip-any-1 lit-1 lit
        parse)

(let hug (feed-list identity))

(define (rule-ref<- name)
  (list<- (set<- name)
          (given (_ rules _)
            (delay (given () (rules name))))))

(define (constant<- p)
  (list<- (set<-)
          (given (_ _ _) p)))

(define (lift peg-op)
  (feed-list
   (given (lifted)
     (list<- (call union (for each (((refs _) lifted))
                           refs))
             (given (builder rules subs)
               (call peg-op (for each (((_ f) lifted))
                              (f builder rules subs))))))))

(define (literal<- string)
  (list<- (set<-)
          (given (builder _ _) (builder .literal string))))

(define (keyword<- string)
  (list<- (set<-)
          (given (builder _ _) (builder .keyword string))))

(define (unquote<- name)
  (list<- (set<-)
          (given (_ rules subs) (subs name))))

(define (push-lit<- string)
  (constant<- (push string)))

(define (word-char? c)
  (or c.alphanumeric? (= c #\_)))       ;right?

(let eat-line
    (delay (given ()
             (either (lit-1 #\newline)
                     (then skip-any-1 eat-line)
                     empty))))

(let whitespace
    (at-least-1 (either (skip-1 '.whitespace?)
                        (then (lit-1 #\#) eat-line))))

(let __ (maybe whitespace))

(let name 
    (then (capture (then (skip-1 (given (c) (or c.alphabetic? (= c #\_))))
                         (many (skip-1 word-char?))))
          __))

(let word
    (then (capture (many (skip-1 word-char?)))
          __))

(define (string-quoted-by q-char)
  (let q (lit-1 q-char))
  (let quoted-char
    (either (then (lit-1 #\\) any-1)
            (then (invert q) any-1)))
  (seclude
   (then q (many quoted-char) q
         __
         (feed-list string<-list))))

(let qstring  (string-quoted-by #\'))
(let dqstring (string-quoted-by #\"))

(let pe
    (delay (given ()
             (seclude
              (either (then term (maybe (then (lit "|") __ pe (lift either))))
                      (lift (given () empty)))))))

(let term
    (delay (given ()
             (seclude
              (then factor (maybe (then term (lift chain))))))))

(let factor
    (delay (given ()
             (seclude
              (either (then (lit "!") __ factor (lift invert))
                      (then primary
                            (either (then (lit "**") __ primary (lift many))
                                    (then (lit "++") __ primary (lift at-least-1))
                                    (then (lit "*") __ (lift many))
                                    (then (lit "+") __ (lift at-least-1))
                                    (then (lit "?") __ (lift maybe))
                                    empty)))))))

(let primary
    (seclude
     (either (then (lit "(") __ pe (lit ")") __)
             (then (lit "[") __ pe (lit "]") __   (lift seclude))
             (then (lit "{") __ pe (lit "}") __   (lift capture))
             (then qstring (feed literal<-))
             (then dqstring (feed keyword<-))
             (then (lit ":") (either (then word    (feed unquote<-))
                                     (then qstring (feed push-lit<-))))
             (then name (feed rule-ref<-)))))

(let rule
    (seclude
     (then name
           (either (then (lit "=") __ pe)
                   (then (lit ":") whitespace
                         (seclude (then pe (lift seclude)))))
           (lit ".") __
           hug)))

(let grammar
    (then (at-least-1 rule) end))

(export grammar)