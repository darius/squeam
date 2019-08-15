;; Continuations

(to (__unexp e)         (unparse-exp (ast-exp<- e)))
(to (__unpat p)         (unparse-pat (ast-pat<- p)))
(to (__unclause clause) (unparse-clause (ast-clause<- clause)))

;; For the non-halt cont types.
;; For these, the __raw-k layout is [my-tag parent-raw-k ...data...].
;; For the kinds having an environment in the data, it's in the first data slot
;; (the slot after parent-raw-k).
(make-trait __cont-trait me
  (to _.none?         #no)
  (to _.rest
    ;; The parent cont is another raw-k, in slot 1 (except __halt-cont which has no parent).
    (__wrap-cont (me.__raw-k 1)))
  (to (_ .selfie sink)   (sink .display "<cont>")) ;TODO at least give out the tag
  (to _.env
    ;; Commonly this, but needs to be overridden when there's no env.
    ;; When present, it's always in the same slot, mentioned above.
    (me.__raw-k 2))
  (to (_ .answer result) (__reply me.__raw-k result))
  (to message
    (list-trait me message))) ;XXX use trait syntax instead

(make-trait __cont-halt me
  (to _.none?         #yes)
  (to _.first         (error "No more frames" me))
  (to _.rest          (error "No more frames" me))
  (to (_ .selfie sink)   (sink .display "<halt-cont>"))
  (to (_ .answer result) (__reply me.__raw-k result))
  (to message (list-trait me message)))

(make-trait __cont-match-clause me
  (to _.first
    (let `(,pat-r ,body ,rest-clauses ,object ,script ,datum ,message) me.__data)
    `((^ ,(__unexp (body 1)))
      ,@(each __unclause rest-clauses)))
  (to message
    (__cont-trait me message)))

(make-trait __cont-ev-trait-make me
  (to _.first
    (let `(,r ,name ,clauses) me.__data)
    `(make ,name ^
       ,@(each __unclause clauses)))
  (to message
    (__cont-trait me message)))

(make-trait __cont-ev-do-rest me
  (to _.first
    (let `(,r ,e2) me.__data)
    (__unexp e2))
  (to message
    (__cont-trait me message)))

(make-trait __cont-ev-let-match me
  (to _.first
    (let `(,r ,p) me.__data)
    `(<match> ,(__unpat p)))          ;XXX lousy presentation
  (to message
    (__cont-trait me message)))

(make-trait __cont-ev-let-check me
  (to _.first
    (let `(,val) me.__data)
    `(<assert-matched-then> ',val))
  (to _.env
    '())
  (to message
    (__cont-trait me message)))

(make-trait __cont-ev-arg me
  (to _.first
    (let `(,r ,e2) me.__data)
    `(^ ,(__unexp e2)))
  (to message
    (__cont-trait me message)))

(make-trait __cont-ev-call me
  (to _.first
    (let `(,receiver) me.__data)
    `(call ',receiver ^))
  (to _.env
    '())
  (to message
    (__cont-trait me message)))

(make-trait __cont-ev-rest-args me
  (to _.first
    (let `(,r ,es ,vals) me.__data)
    (to (quotify v) `',v)
    `(,@(each quotify (reverse vals)) ^ ,@(each __unexp es)))
  (to message
    (__cont-trait me message)))

(make-trait __cont-ev-tag me
  (to _.first
    (let `(,tag) me.__data)
    `{,tag ^^^})
  (to _.env
    '())
  (to message
    (__cont-trait me message)))

(make-trait __cont-ev-and-pat me
  (to _.first
    (let `(,r ,subject ,p2) me.__data)
    `(<and-match?> ,(__unpat p2)))
  (to message
    (__cont-trait me message)))

(make-trait __cont-ev-view-call me
  (to _.first
    (let `(,r ,subject ,p) me.__data)
    `(? _ ^ ,(__unpat p)))
  (to message
    (__cont-trait me message)))

(make-trait __cont-ev-view-match me
  (to _.first
    (let `(,r ,p) me.__data)
    (__unpat p))
  (to message
    (__cont-trait me message)))

(make-trait __cont-ev-match-rest me
  (to _.first
    (let `(,r ,subject ,ps) me.__data)
    `(<all-match?> ,@(each __unpat ps)))
  (to message
    (__cont-trait me message)))

(make-trait __cont-disable-ejector me
  (to _.first
    '<disable-ejector>)                          ;TODO show more
  (to _.env
    '())
  (to message
    (__cont-trait me message)))

(make-trait __cont-call-unwind-thunk me
  (to _.first
    '<disable-ejector>)                          ;TODO show more
  (to _.env
    '())
  (to message
    (__cont-trait me message)))

(make-trait __cont-keep-unwinding me
  (to _.first
    '<keep-unwinding>)                  ;TODO show more
  (to _.env
    '())
  (to message
    (__cont-trait me message)))

(make-trait __cont-replace-answer me
  (to _.first
    (let `(,value) me.__data)
    `(<replace-answer> ',value))
  (to _.env
    '())
  (to message
    (__cont-trait me message)))

(let __cont-trait-array
  [__cont-halt
   __cont-match-clause
   __cont-ev-trait-make
   __cont-ev-do-rest
   __cont-ev-let-match
   __cont-ev-let-check
   __cont-ev-arg
   __cont-ev-call
   __cont-ev-rest-args
   __cont-ev-tag
   __cont-ev-and-pat
   __cont-ev-view-call
   __cont-ev-view-match
   __cont-ev-match-rest
   __cont-disable-ejector
   __cont-call-unwind-thunk
   __cont-keep-unwinding
   __cont-replace-answer])

(to (__wrap-cont raw-k)
  (make wrapped-cont {extending (__cont-trait-array (raw-k 0))}
    ;; TODO shouldn't need these methods
    (to _.__raw-k
      raw-k)
    (to _.__data
      (((__vector->list raw-k) .rest) .rest))))

(let the-signal-handler (box<- panic))

(to (__handle-error raw-k evil)
  ;; TODO set the-signal-handler to a backup handler before invoking the current one.
  ;; There's logic for this in top.scm, but let's try to not mix this with the fancier
  ;; stuff there.
  (the-signal-handler.^ (__wrap-cont raw-k) evil))
