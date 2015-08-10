;; Let's work out a source-level debugger in a simpler setting,
;; the call-by-value lambda calculus.
;; (That's the goal; not there yet.)

(load "stdlib.scm")
(load "traceback.scm")

;; Conventions:
;;  lexp    source form of lambda expression
;;  c       constant value
;;  v       variable name (a symbol)
;;  r       environment
;;  k       continuation
;;  others  an AST or a value

(define (parse lexp)
  (cond ((symbol? lexp)
         (var-ref<- lexp))
        ((number? lexp)
         (constant<- lexp))
        ((is? (lexp 0) 'lambda)
         (abstraction<- ((lexp 1) 0)
                        (parse (lexp 2))))
        (else
         (call<- (parse (lexp 0))
                 (parse (lexp 1))))))

(define (interpret lexp)
  (.evaluate (parse lexp) global-env halt))


;; ASTs and continuations

(define halt
  (make (.empty? () #t)
        (.inject (k<-) halt)
        (.take-step (val) val)
        (.take (val) val)))


;; Constant
(define (constant<- c)
  (make constant
    (.source () c)
    (.eval-step (r k) (debugging (value-step<- constant r k)))
    (.evaluate (r k) (.take k c))))

;; Variable reference
(define (var-ref<- v)
  (make var-ref
    (.source () v)
    (.eval-step (r k) (debugging (value-step<- var-ref r k)))
    (.evaluate (r k) (lookup r v k))))

;; Lambda expression
(define (abstraction<- v body)
  (make abstraction
    (.source () (list<- '& v (.source body)))
    (.eval-step (r k) (debugging (value-step<- abstraction r k)))
    (.evaluate (r k)
      (.take k (make
                 (.survey () (list<- v '-> '...))
                 (.call (arg k2)
                   (.evaluate body (extend r v arg) k2))
                 (.call-step (arg k2)
                   (.eval-step body (extend r v arg) k2)))))))

;; Application
(define (call<- operator operand)
  (make app
    (.source () (list<- (.source operator) (.source operand)))
    (.eval-step (r k)
      (debugging (subeval-step<- operator r (ev-arg-cont<- operand r k))))
    (.evaluate (r k)
      (.evaluate operator r (ev-arg-cont<- operand r k)))))

(define (ev-arg-cont<- operand r k)
  (make (.empty? () #f)
        (.rest () k)
        (.first () (list<- '^ (.source operand)))
        (.inject (k<-) (ev-arg-cont<- operand r (k<- k)))
        (.take (fn)
           (.evaluate operand r (call-cont<- fn k)))
        (.take-step (fn)
           (.eval-step operand r (call-cont<- fn k)))
        ))

(define (call-cont<- fn k)
  (make (.empty? () #f)
        (.rest () k)
        (.first () (list<- (survey fn) '^))
        (.inject (k<-) (call-cont<- fn (k<- k)))
        (.take (arg)
           (.call fn arg k))
        (.take-step (arg)
           (.call-step fn arg k))
        ))


;; Built-in values

(define (survey value)
  (if (or (number? value) (symbol? value))
      value
      (.survey value)))

(define prim+
  (make (.survey () '+)
        (.call-step (arg1 k1)
          XXX)
        (.call (arg1 k1)
          (if (number? arg1)
              (.take k1 (make (.survey () (list<- '+ (survey arg1)))
                              (.call-step (arg2 k2)
                                XXX)
                              (.call (arg2 k2)
                                (if (number? arg2)
                                    (.take k2 (+ arg1 arg2))
                                    ;; XXX should supply self, too:
                                    (debug k2 "Bad arg2 to +" (survey arg2))))))
              (debug k1 "Bad arg1 to +" (survey arg1))))))


;; Environments

(define global-env
  (list<- (list<- '+ prim+)))

(define (extend r v val)
  (cons (list<- v val) r))

(define (lookup r v k)
  (cond ((assq v r) => (given (record) (.take k (record 1))))
        (else (debug k "Unbound var" v))))


;; Debugger
;; Instead of interacting at a prompt, it takes a list of commands,
;; for now, for ease of rerunning during development.

(define command-queue (box<- '()))

(define (next-command)
  (display "debug> ")
  (let ((cmds (command-queue)))
    (cond ((.empty? cmds)
           (newline)
           #f)
          (else
           (print (.first cmds))
           (.set! command-queue (.rest cmds))
           (.first cmds)))))

(define (debug k plaint culprit)
  (complain plaint culprit)
  (traceback k)
  (debugging (out-step<- k 'default-error-value)))

(define (complain plaint culprit)
  (display "Lambdaterp error: ")
  (write plaint)
  (display ": ")
  (write culprit)
  (newline))

(define (traceback k)
  (for-each print k))

(define (debugging state)
  (let ((cmd (next-command)))
    (if cmd (call state cmd) #f)))

(define (value-step<- e r k)
  (make value-step
    (.show ()
      (display "ev-> ") (print (.source e)))
    (.b ()
      (traceback k)
      (debugging value-step))
    (.continue ()
      (.evaluate e r k))
    (.hop ()
      (.evaluate e r (.inject k debugger-trap-cont<-)))
    (.step ()
      (.hop value-step))
    ))

(define (subeval-step<- e r k)
  (make subeval-step
    (.show ()
      (display "ev-> ") (print (.source e)))
    (.b ()
      (traceback k)
      (debugging subeval-step))
    (.continue ()
      (.evaluate e r k))
    (.hop ()
      (.evaluate e r (.inject k debugger-trap-cont<-)))
    (.step ()
      (.eval-step e r k))
    ))

(define (out-step<- k value)
  (make out-step
    (.show ()
      (display "<-ret ") (print (survey value)))
    (.b ()
      (traceback k)
      (debugging out-step))
    (.continue ()
      (.take k value))
    (.hop ()
      (.take (.inject k debugger-trap-cont<-) value))
    (.step () 
      (.take-step k value))
    (.value (new-value)
      (debugging (out-step<- k new-value)))
    ))

(define (debugger-trap-cont<- k)
  (if (is? k halt)
      k
      (make
        (.take (value) (debugging (out-step<- k value)))
        ;; XXX (.inject ...) ?
        (else (cue arguments) (call cue k arguments)))))


;; Smoke test

(define try
  (make (.run (lexp)
          (try lexp '()))
        (.run (lexp commands)
          (.set! command-queue commands)
          (let ((result (interpret lexp)))
            (if result (print (survey result)) 'failed)))))

(try '(lambda (x) x))
(try '((lambda (x) ((+ x) 2)) 1))

(try '((lambda (x) ((+ y) 1)) 42))
(try '((+ (lambda (z) z)) y))
(try '(((+ 1) y) 2))

(try '((lambda (x) ((+ y) 1)) 42)
     '((.value 42) (.continue)))
(try '((lambda (x) ((+ y) 1)) 42)
     '((.value 42) (.hop) (.b) (.hop)))
