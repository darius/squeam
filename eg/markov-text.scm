;; Markov text generator
;; TODO:
;; - separate a module from the main program

(import (use 'random) random-rng<-)
(import (use 'text-wrap) fill)

(let order 2) ; Length of the context. TODO parameterize at command line
(let start ('("START") .repeat order)) 

(to (main argv)
  (let model (map<-))
  (for each! ((filename argv.rest))
    (train model (tokenize (with-input-file '.read-all filename))))
  (unless model.empty?
    (let text (spew (random-rng<-) model start))
    (display (fill (" " .join text) ;TODO a lazy text-wrap
                   72))
    (newline)))

(to (tokenize string)
  string.lowercase.split)               ;TODO better

(to (train model input)
  (let data (chain start input '("END"))) ;TODO as array?
  (for each! ((datum (k-slices<- data (+ order 1))))
    (let context (datum .slice 0 order))
    ((model .get-set! context bag<-) .add! (datum order))))

(to (k-slices<- xs k)                   ;ugly: better name?
  (for each ((i (0 .to (- xs.count k))))
    (xs .slice i (+ i k))))

(to (spew rng model state)
  (begin spewing ((state state))
    (match (sample-from-bag rng (model state))
      ("END"  '())
      (choice (let next-state `(,@(state .slice 1) ,choice))
              `(,choice ,@(spewing next-state))))))

(to (sample-from-bag rng bag)           ;TODO dedupe: similar in squickcheck.scm
  (let n bag.total)  ;; Pre: n > 0
  (begin counting ((k (rng .random-integer n))
                   (items bag.items))
    (let `(,key ,count) items.first)
    (if (< k count)
        key
        (counting (- k count) items.rest))))
