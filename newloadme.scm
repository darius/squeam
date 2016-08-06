(load "util.scm")
(load "read.scm")
;(snarf "later/new.scm" squeam-read)  ; or readtest.scm?
(define eg-program (snarf "later/compact-lambda.scm" squeam-read))
(load "parse.scm")
(map parse-exp eg-program)
(map parse-exp (snarf "newboot.scm" squeam-read))

(load "newestterp.scm")

(define (print x)
  (write x)
  (newline))

(print (interpret 42))
(print (interpret ''hello))
(print (interpret '(make _)))
(print (interpret '((make (xs xs)))))
(print (interpret '((make (xs xs)) 1 2 3)))
(print (interpret '(if #f 1 2)))
(print (interpret '(if #t 1 2)))
(print (interpret '((make ((#f) 'no) (_ 'yes)) #f)))
(print (interpret '((make ((#f) 'no) (_ 'yes)) #t)))
(print (interpret '`(hello ,(if #t 'yes 'no))))
(print (interpret '(2 .+ 3)))
(pp (parse-exp '(let x 55)))
(print (interpret '(let x 55)))



(pp (parse-exp '(define (f) 42)))
(print (interpret '(define (f) 42)))
(print (interpret '(do (define (factorial n)
                         (match n
                           (0 1)
                           (_ (n .* (factorial (n .- 1))))))
                       (factorial 5))))
