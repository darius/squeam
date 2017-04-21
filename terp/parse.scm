;; Parse expressions and patterns to ASTs

(define (parse-exp e . opt-context)
  (parse-e e (optional-context 'parse-exp opt-context)))

(define (parse-pat p . opt-context)
  (parse-p p (optional-context 'parse-pat opt-context)))

(define (optional-context caller opt-context)
  (cond ((null? opt-context) '())
        ((null? (cdr opt-context)) (car opt-context))
        (else (error caller "Too many arguments" opt-context))))

(define (nest-context name ctx)
  (cons name ctx))

(define (parse-e e ctx)
  (cond
    ((and (pair? e) (look-up-macro (car e)))
     => (lambda (expand) (parse-e (expand e) ctx)))
    (else
     (mcase e
       ((: __ symbol?)
        (term<- 'variable e))
       (('quote datum)
        (term<- 'constant datum))
       ((: __ self-evaluating?)
        (term<- 'constant e))
       ((: __ term?)
        (term<- 'term
                (term-tag e)
                (parse-es (term-parts e) ctx)))
       (('let p e1)
        (term<- 'let (parse-p p ctx) (parse-e e1 ctx)))
       (('make '_ . clauses)
        (parse-make '_ clauses ctx))
       (('make (: name symbol?) . clauses)
        (term<- 'let (parse-p name ctx) (parse-make name clauses ctx)))
       (('make (: name string?) . clauses)
        (parse-make name clauses ctx))
       (('make . clauses)
        (parse-make '_ clauses ctx))
       (('do e1)
        (parse-e e1 ctx))
       (('do e1 ('XXX-halp-spot start end) . es)
        (term<- 'do (parse-e `(__halp-log ,start ,end ,e1) ctx)  ;XXX hygiene
                (parse-e `(do ,@es) ctx)))
       (('do e1 . es)
        (term<- 'do (parse-e e1 ctx) (parse-e `(do ,@es) ctx)))
       (('do)
        (term<- 'constant #f))          ;I guess
       (('call e1 e2)
        (term<- 'call (parse-e e1 ctx) (parse-e e2 ctx)))
       ((addressee (: cue cue?) . operands)
        (term<- 'call
                (parse-e addressee ctx)
                (term<- 'term cue (parse-es operands ctx))))
       ((addressee . operands)
        (term<- 'call
                (parse-e addressee ctx)
                (term<- 'list (parse-es operands ctx))))
       ))))

(define (parse-es es ctx)
  (map (lambda (e) (parse-e e ctx)) es))

(define (parse-ps ps ctx)
  (map (lambda (p) (parse-p p ctx)) ps))

(define (parse-clauses clauses ctx)
  (map (lambda (clause) (parse-clause clause ctx)) clauses))

;; what's the syntax for a macro in pattern context?
(define (parse-p p ctx)
  (cond
    ((and (pair? p) (look-up-pat-macro (car p)))
     => (lambda (expand) (parse-p (expand p) ctx)))
    (else
     (mcase p
       ('_
        (term<- 'any-pat))
       ((: __ symbol?)
        (term<- 'variable-pat p))
       ((: __ self-evaluating?)
        (term<- 'constant-pat p))
       (('quote datum)
        (term<- 'constant-pat datum))
       (('and . ps)
        (parse-and-pat ps ctx))
       (('view e1 p1)
        (term<- 'view-pat (parse-e e1 ctx) (parse-p p1 ctx)))
       ;; XXX complain if you see a bare , or ,@. but this will fall out of disallowing defaulty lists.
       (('list<- . ps)
        (parse-list-pat ps ctx))
       (('cons car-p cdr-p)
        (make-cons-pat (parse-p car-p ctx) (parse-p cdr-p ctx)))
       ((: __ term?)
        (let ((tag (term-tag p))
              (parts (term-parts p)))
          (if (any (mlambda (('@ __) #t) (__ #f)) parts)  ;XXX really only need to check the last one
              (term<- 'view-pat
                      explode-term-exp
                      (term<- 'term-pat 'term (list (term<- 'constant-pat tag)
                                                    (parse-list-pat parts ctx))))
              (term<- 'term-pat tag (parse-ps parts ctx)))))
       (('@ __)                      ;XXX make @vars be some disjoint type
        (error 'parse "An @-pattern must be at the end of a list" p))
       ((: __ list?)
        (error 'parse "Old-style list pattern" p)))))) ;TODO better plaint

(define (parse-and-pat ps ctx)
  (mcase ps
    (()         (term<- 'any-pat))
    ((p)        (parse-p p ctx))
    ((p1 . ps1) (term<- 'and-pat (parse-p p1 ctx) (parse-and-pat ps1 ctx)))))

(define (look-up-pat-macro key)
  (mcase key
    ('?      (mlambda
              ((__ e)
               `(view ,e #t))
              ((__ e p1)
               `(and (view ,e #t) ,p1))))
    ('optional (mlambda
                ((__ . ps)
                 `(view ,(optional-match-exp (length ps))
                        ,(make-term 'ok (reverse ps))))))
    ('quasiquote (mlambda
                  ((__ quoted)
                   (expand-quasiquote-pat quoted))))
    (__ #f)))

(define (up-to-n-optional n)
  (lambda (arguments)
    (let eating ((n n) (xs arguments) (values '()))
      (cond ((null? xs)
             (let filling ((n n) (values values))
               (if (= n 0)
                   (make-term 'ok values)
                   (filling (- n 1) (cons #f values)))))
            ((= n 0)
             #f)
            (else
             (eating (- n 1) (cdr xs) (cons (car xs) values)))))))

(define (optional-match-exp<- n)
  `',(up-to-n-optional n))

(define optional-matcher-cache
  (list->vector (map optional-match-exp<- '(0 1 2 3))))

(define (optional-match-exp n)
  (if (< n (vector-length optional-matcher-cache))
      (vector-ref optional-matcher-cache n)
      (optional-match-exp<- n)))

(define (expand-definition-pattern dp)
 (mcase dp
   (((: cue cue?) . rest)
    (make-term cue rest))
   ((: __ list?)
    `(list<- ,@dp))
   ((: __ term?)
    dp)
   (__ (error 'parse "Bad definition pattern" dp))))

(define (explode-term thing)
  (and (term? thing)
       (term<- 'term (term-tag thing) (term-parts thing))))

(define explode-term-exp
  (term<- 'constant explode-term))

(define (parse-list-pat ps ctx)
  (if (all (mlambda (('@ __) #f) (__ #t)) ps)
      (term<- 'list-pat (parse-ps ps ctx)) ; Special-cased just for speed
      (mcase ps
        (()
         (term<- 'constant-pat '()))
        ((('@ v))
         (term<- 'and-pat list?-pat (parse-p v ctx)))
        ((head . tail)
         (make-cons-pat (parse-p head ctx)
                        (parse-list-pat tail ctx))))))

(define list?-pat (term<- 'view-pat
                          (term<- 'constant list?) ;XXX just check pair?/null?
                          (term<- 'constant-pat #t)))

(define (make-cons-pat car-pat cdr-pat)
  (if (and (eq? (term-tag car-pat) 'constant-pat)
           (eq? (term-tag cdr-pat) 'constant-pat))
      (term<- 'constant-pat (cons (car (term-parts car-pat))
                                  (car (term-parts cdr-pat))))
      (term<- 'view-pat
              (term<- 'variable '__as-cons)
              (term<- 'term-pat 'cons (list car-pat cdr-pat)))))

(define (self-evaluating? x)
  (or (boolean? x)
      (number? x)
      (char? x)
      (string? x)))

;; XXX what about stamp?
(define (parse-make name stuff ctx)
  (let ((name (cond ((symbol? name) (symbol->string name))
                    ((string? name) name)
                    (else (error 'parse "Illegal name type" name)))))
    (let* ((ctx (nest-context name ctx))
           (qualified-name (string-join ":" ctx)))
      (mcase stuff
        (((: decl term?) . clauses)
         (assert (eq? (term-tag decl) 'extending) "bad syntax" decl)
         (assert (= (length (term-parts decl)) 1) "bad syntax" decl)
         (term<- 'make qualified-name none-exp
                 (parse-e (car (term-parts decl)) ctx)
                 (parse-clauses clauses ctx)))
        (clauses
         (term<- 'make qualified-name none-exp
                 none-exp
                 (parse-clauses clauses ctx)))))))

(define none-exp (term<- 'constant '#f))

(define (parse-clause clause ctx)
  (mcase clause
    ((pat . body)
     (let ((p (parse-p pat ctx))
           (e (parse-e `(do ,@body) ctx)))
       (list p (pat-vars-defined p) (exp-vars-defined e) e)))))

(define (look-up-macro key)
  (mcase key
    ('hide   (mlambda
              ((__ . es)
               `((given () ,@es)))))
    ('make-trait
             (mlambda
              ((__ (: v symbol?) (: self symbol?) . clauses) ;XXX allow other patterns?
               (let ((msg (gensym)))
                 ;; TODO leave out miranda-trait if there's a catchall already
                 `(to (,v ,self ,msg)
                    (match ,msg
                      ,@clauses
                      (_ (miranda-trait ,self ,msg)))))))) ;XXX hygiene, and XXX make it overridable
    ('match  (mlambda
              ((__ subject . clauses)
               `((make _ ,@(map (lambda (clause)
                                  (assert (pair? clause)
                                          "invalid clause" clause)
                                  `((list<- ,(car clause)) ,@(cdr clause)))
                                clauses))
                 ,subject))))
    ('to     (mlambda
              ((__ (head . param-spec) . body)
               (let ((pattern (expand-definition-pattern param-spec)))
                 (if (symbol? head)
                     `(make ,head (,pattern ,@body))
                     `(to ,head (make _ (,pattern ,@body))))))))
    ('given  (mlambda
              ((__ dp . body)
               `(to (_ ,@dp) ,@body))))
    ('for    (mlambda
              ((__ fn bindings . body)
               (let ((name-for (if (symbol? fn)
                                   (string-append "for_" (symbol->string fn))
                                   "for:_")))
                 (parse-bindings bindings
                   (lambda (ps es)
                     `(,fn (make ,name-for
                             ((list<- ,@ps) ,@body))
                           ,@es)))))))
    ('begin  (mlambda
              ((__ (: proc symbol?) bindings . body)
               (parse-bindings bindings
                 (lambda (ps es)
                   `((hide (make ,proc ((list<- ,@ps) ,@body)))
                     ,@es))))))
    ('if     (mlambda
              ((__ test if-so if-not)
               `(match ,test
                  (#f ,if-not)
                  (_ ,if-so)))))
    ('when   (mlambda
              ((__ test . body)
               `(if ,test (do ,@body) #f))))
    ('unless (mlambda
              ((__ test . body)
               `(if ,test #f (do ,@body)))))
    ('case   (mlambda
              ((__) #f)                 ;TODO: generate an error-raising?
              ((__ ('else . es)) `(do ,@es))
;;              ((__ (e) . clauses) `(or ,e (case ,@clauses))) ;TODO: do I ever use this?
              ((__ (e e1 . es) . clauses)
               `(if ,e (do ,e1 ,@es) (case ,@clauses)))))
    ('and    (mlambda
              ((__) #t)
              ((__ e) e)
              ((__ e . es) `(if ,e (and ,@es) #f))))
    ('or     (mlambda
              ((__) #f)
              ((__ e) e)
              ((__ e . es)
               (let ((t (gensym)))
                 `((given (,t) (if ,t ,t (or ,@es)))
                   ,e)))))
    ('import (mlambda
              ((__ m . names)
               (assert (all symbol? names) "bad syntax" names)
               (let ((map-var (gensym)))
                 `(let (list<- ,@names)
                    (hide (let ,map-var ,m)
                          (',list ,@(map (lambda (name) `(,map-var ',name))
                                         names))))))))
    ('export (mlambda
              ((__ . names)
               (assert (all symbol? names) "bad syntax" names)
               (list `',the-map<-
                     (list 'quasiquote
                           (map (lambda (name) (list name (list 'unquote name)))
                                names))))))
    ('quasiquote (mlambda
                  ((__ q) (expand-quasiquote q))))
    (__ #f)))

(define (parse-bindings bindings receiver)
  (for-each (lambda (binding)
              (mcase binding
                ((__ __)   ; (used to check here for a variable, but now can be any pattern)
                 'ok)))
            bindings)
  (receiver (map car bindings) (map cadr bindings)))

(define (expand-quasiquote-pat qq)
  (mcase qq
    (('unquote p)
     p)
    ((('unquote-splicing p))
     `(? ',list? ,p))
    ((('unquote-splicing p) . __)
     (error 'parse "A ,@-pattern must be at the end of a list" qq))
    ((qcar . qcdr)
     `(cons ,(expand-quasiquote-pat qcar)
            ,(expand-quasiquote-pat qcdr)))
    ((: __ term?)
     (expand-qq-term-pat qq))
    ;; TODO what about e.g. vectors with a ,pat inside?
    ;;  We should probably at least try to notice them and complain.
    (__ `',qq)))

(define (expand-qq-term-pat term)
  (let ((tag (term-tag term))
        (parts (term-parts term)))
    (unless (symbol? tag)
      ;; XXX for now:
      (error 'parse "A term pattern must be tagged with a constant symbol" term))
    ;; XXX duplicate and ugly code. also, TESTME.
    (if (any (mlambda (('unquote-splicing __) #t) (__ #f)) parts)
        `(view ',explode-term ,(make-term tag (expand-quasiquote-pat parts)))
;XXX        `(: ',explode-term {term ',tag ,(expand-quasiquote-pat parts)})
        (make-term tag (map expand-quasiquote-pat parts)))))

(define (expand-quasiquote e)
  (mcase e
    (('unquote e1) e1)
    ((('unquote-splicing e1)) e1)
    ((('unquote-splicing e1) . qcdr)
     `(',append ,e1 ,(expand-quasiquote qcdr))) ;XXX call .chain method instead?
    ((qcar . qcdr)
     (qq-cons e (expand-quasiquote qcar)
                (expand-quasiquote qcdr)))
    (__ (if (term? e)
            (expand-qq-term e)
            `',e))))

(define (expand-qq-term term)
  (let ((tag (term-tag term))
        (parts (term-parts term)))
    (let ((tag-e (expand-quasiquote tag)))
      (if (or (not (qq-constant? tag-e))
              (any (mlambda (('unquote-splicing __) #t) (__ #f))
                   parts))
          `(',make-term ,tag-e ,(expand-quasiquote parts))
          (let ((part-es (map expand-quasiquote parts)))
            (if (all qq-constant? part-es)
                `',term
                (make-term tag part-es)))))))

(define qq-constant?
  (mlambda (('quote __) #t) (__ #f)))

(define (qq-cons pair qq-car qq-cdr)
  (mcase `(,qq-car ,qq-cdr)
    ((('quote a) ('quote d))
     `',(reuse-cons pair a d))
    (__ `(',cons ,qq-car ,qq-cdr))))

(define (reuse-cons pair a d)
  (if (and (eqv? (car pair) a)
           (eqv? (cdr pair) d))
      pair
      (cons a d)))


;; Variables defined

(define (pat-vars-defined p)
  (let ((parts (term-parts p)))
    (case (term-tag p)
      ((any-pat constant-pat)
       '())
      ((variable-pat)
       parts)
      ((list-pat)
       (let ((p-args (car parts)))
         (flatmap pat-vars-defined p-args)))
      ((term-pat)
       (let ((p-args (cadr parts)))
         (flatmap pat-vars-defined p-args)))
      ((and-pat)
       (let ((p1 (car parts)) (p2 (cadr parts)))
         (append (pat-vars-defined p1)
                 (pat-vars-defined p2))))
      ((view-pat)
       (let ((e (car parts)) (p (cadr parts)))
         (append (exp-vars-defined e)
                 (pat-vars-defined p))))
      (else
       (error 'parse "Bad pattern type" p)))))

(define (exp-vars-defined e)
  (let ((parts (term-parts e)))
    (case (term-tag e)
      ((constant variable make)
       '())
      ((call do)
       (let ((e1 (car parts)) (e2 (cadr parts)))
         (append (exp-vars-defined e1)
                 (exp-vars-defined e2))))
      ((let)
       (let ((p (car parts)) (e (cadr parts)))
         (append (pat-vars-defined p)
                 (exp-vars-defined e))))
      ((term)
       (let ((es (cadr parts)))
         (flatmap exp-vars-defined es)))
      ((list)
       (let ((es (car parts)))
         (flatmap exp-vars-defined es)))
      (else
       (error 'parse "Bad expression type" e)))))
