;;; Trying out the new syntax scheme, with a little new semantics.

;;; pair.scm

(let (pair? pair-stamp) (stamp<- "pair"))

(define (cons head tail)
  ;; XXX where do we define the selflessness and equality?
  ;;     also, the pattern-matching syntax?
  (make pair
    {stamped pair-stamp}
    {extending list-trait}              ;XXX syntax?
    ({.empty?} #no)
    ({.first}  head)
    ({.rest}   tail)))


;;; stdlib.scm

(define (vector<-list xs)
  (let v (vector<-count xs.count))
  (for each! ((i x) (enumerate xs))
    (v .set! i x))
  v)


;; dd.scm
;; Decision diagrams

(let infinity 999999)  ;; N.B. we don't have floats yet

(define (constant<- value)
  (make
    ({.rank}           infinity)
    ({.constant-value} value)
    ({.evaluate env}   value)
    ({.choose nodes}   (nodes value))))

(define (all-same? xs)
  (let set (set<-list xs))
  (= 1 set.count))

(define (choice<- rank branches)
  (assert (< rank infinity))
  (make choice
    ({.rank}           rank)
    ({.constant-value} #no)
    ({.evaluate env}   ((branches (env rank)) .evaluate env))
    ({.branches}       branches)
    ({.choose nodes}
     (case ((all-same? nodes)
            (nodes 0))
           ((= (each '.constant-value nodes)
               (range<- nodes.count))
            choice)
           (else
            (memo-choice choice nodes))))))

(let memo-node (memoize choice<-))

(define (variable<- rank arity)
  (memo-node rank (each constant<- (range<- arity))))

(let memo-choice
  (memoize
   (given (node branches)
     (let top (minimum-by (cons node branches) '.rank))
     (let rank top.rank)
     (make-node rank
                (for each ((c (range<- top.branches.count)))
                  ((subst rank c node)
                   .choose (subst-each rank c branches)))))))

(define (make-node rank branches)
  (if (all-same? branches)
      (branches 0)
      (memo-node rank branches)))

(define (subst-each rank value nodes)
  (for each ((e nodes)) (subst rank value e)))

(define (subst rank value node)
  (case ((< rank node.rank)
         node) ; N.B. node must be a constant, iff we arrived here (XXX why?)
        ((= rank node.rank)
         (node.branches value))
        (else
         (make-node node.rank
                    (subst-each rank value node.branches)))))

(define (valid? node)
  (not (satisfy node 0)))

;; XXX ugly
(define (satisfy node goal)
  (let env (map<-))
  (begin walking ((node node))
    (if node.constant-value
        (and (= goal node.constant-value)
             env)
        (begin trying ((rank node.rank)
                       (value 0)
                       (branches node.branches))
          (and (not branches.empty?)
               (case ((`(#no ,goal) .maps-to? branches.first.constant-value)
                      (env .set! rank value)
                      (walking branches.first))
                     (else
                      (trying rank (+ value 1) branches.rest))))))))


;; kanren.scm

(define (fail s)
  '())

(define (succeed s)
  `(,s))

(define ((== val1 val2) s)
  (let s1 (unify s val1 val2))
  (if s1 `(,s1) '()))

(define ((either goal1 goal2) s)
  (interleave (goal1 s) (goal2 s)))

;; TODO: probably ought to be lazy in the head as well as the tail
(define (interleave xs ys)
  (if xs.empty?
      ys
      (cons/lazy xs.first
                 (given () (interleave ys xs.rest)))))

(define ((both goal1 goal2) s)
  (gather/lazy goal2 (goal1 s)))

(define (cons/lazy x thunk)
  (make lazy-list
    ({.empty?} #no)
    ({.first} x)
    ({.rest} (thunk))  ;XXX memoize?
    ;; ... XXX use list-trait? except it'd need a rewrite for laziness
    ))

(define (gather/lazy f xs)
  (for foldr/lazy ((x xs)
                   (rest-thunk (given () '())))
    (chain/lazy (f x) rest-thunk)))

(define (chain/lazy xs ys-thunk)
  (foldr/lazy cons/lazy xs ys-thunk))

(define (foldr/lazy f xs z-thunk)
  (if xs.empty?
      (z-thunk)
      (f xs.first
         (given () (foldr/lazy f xs.rest z-thunk)))))


;; read.scm
;; A Lisp reader.
;; Planned extensions:
;; - Better error reporting
;; - Source-location tracking
;; - (Minor) new syntax like #yes/#no.

;; It's a drag to keep saying 'in-port' here, so let's just say 'port'.
;; TODO: better short names for in-port and out-port

;; XXX (read port default) is still not a POLA-respecting interface;
;; eof-object is better. But I'd prefer a uniform interface that's
;; like the answer for iterators, getting from a collection, etc.

(make eof)

(define (read-atom port char)
  XXX)

(let the-readtable (vector<-count 256 read-atom))

(define (set-read-macro char reader)
  (the-readtable .set! char.code reader))

(define (read port)
  (let char port.read-char)
  (if (= char eof)
      eof
      ((the-readtable char.code) port char)))

;; '(' tree* ')' -- where we've just eaten the '('.
;; XXX the extra must-read is ugly
(define (read-list port _)
  (begin reading ()
    (skip-blanks port)
    (let peek port.peek-char)
    (case ((= peek eof)
           (read-error port "Unexpected EOF in list"))
          ((= peek #\) ) 
           port.read-char
           '())
          (else 
           (cons (must-read port) (reading))))))

(define (skip-blanks port) ;; and comments too
  XXX)

(define (read-number port radix)
  XXX)

(define (read-error port plaint)
  (error (chain "Read error: " plaint)))

;; White space
(for each! ((white '(#\space #\tab #\newline #\return)))
  (set-read-macro white 
    (given (port _) 
      (skip-blanks port)
      (read port))))

(set-read-macro #\;
  (given (port _)
    (flush-input-line port)
    (read port)))

(set-read-macro #\( read-list)

(set-read-macro #\)
  (given (port _)
    (read-error port "Unbalanced parentheses")))

(let radix-map '((#\x 16) (#\X 16)      ;TODO: hashmap
                 (#\d 10) (#\D 10)
                 (#\o  8) (#\O  8)
                 (#\b  2) (#\B  2)))

(set-read-macro #\#
  (given (port _)
    (let peek port.peek-char)
    (case ((assq peek radix-map) ;XXX can conflict with read-hash-symbol
           => (given (pair)
                port.read-char
                (read-number port (pair 1))))
          ((= peek #\\)
           port.read-char
           (read-char-literal port))
          (peek.alphabetic?
           (read-hash-symbol (read-symbol port)))
          ((= peek #\( )	; vector constant
           (vector<-list (read-list port port.read-char)))
          (else
           (read-error port "Unknown '#' read macro")))))

(set-read-macro #\"
  (given (port _)
    (begin scanning ((prev-chars '()))    ;TODO use growable-vector
      (let char port.read-char)
      (case ((= char eof)
             (read-error port "Unexpected EOF in string constant"))
            ((= char #\")
             (string<-list (reverse prev-chars)))
            ((= char #\\)
             (let next port.read-char)
             (case ((= next eof)
                    (read-error port "Unexpected EOF in escape sequence"))
                   ((assq next '((#\\ #\\)
                                 (#\" #\")
                                 (#\n #\newline)
                                 (#\t #\tab)
                                 (#\r #\return)))
                    => (given (pair)
		         (scanning (cons (pair 1) prev-chars))))
                   (else
                    (read-error port 
                                "Unknown escape sequence in string"))))
            (else (scanning (cons char prev-chars)))))))

(set-read-macro #\'
  (given (port _)
    `',(must-read port)))
    
(define (must-read port)
  (let tree (read port))
  (when (= tree eof)
    (read-error port "Unexpected EOF"))
  tree)

(set-read-macro #\`
  (given (port _)
    (list<- 'quasiquote (must-read port))))

(set-read-macro #\,
  (given (port _)
    (list<- (case ((= port.peek-char #\@)
                   port.read-char
                   'unquote-splicing)
                  (else
                   'unquote))
            (must-read port))))


;; self-terp.scm

(define (constant<- value)
  (make
    ({.evaluate r} value)))

(define (variable<- name)
  (make
    ({.evaluate r} (r name))))

(define (make<- script)
  (make
    ({.evaluate r} (object<- script r)))) ;XXX needs expansion

(define (letrec<- defns body)
  (make
    ({.evaluate r}
     (let new-r (env-extend-promises r (map '.first defns)))
     (for each! ((defn defns))
       (env-resolve! new-r
                     (defn 0)
                     ((defn 1) .evaluate new-r)))
     (evaluate body new-r))))

(define (call<- addressee cue operands) ;XXX not necessarily with a cue anymore
  (make
    ({.evaluate r}
     (call (addressee .evaluate r) cue (map '.evaluate operands)))))


;; spell1.scm
;; Norvig's (simpler) spelling corrector
;; http://norvig.com/spell-correct.html
;; TODO: try imitating https://en.wikibooks.org/wiki/Clojure_Programming/Examples/Norvig_Spelling_Corrector
;; TODO: uses pattern matching

(define (correct word)
  (let candidates (or (if-any (known `(,word)))
                      (if-any (known (edits1 word)))
                      (if-any (known-edits2 word))
                      `(,word)))
  (max-by candidates (given (w) (NWORDS .get w 0))))

(define (if-any xs)
  (if xs.empty? #no xs))

(define (known words)  ;TODO: iter instead of list? set comprehension?
  (set<-list (for filter ((w words))
               (NWORDS .maps? w))))

(define (known-edits2 word)
  (set<-list (for gather ((e1 (edits1 word)))
               (for filter ((e2 (edits1 e1)))
                 (NWORDS .maps? e2)))))

(define (edits1 word)
  (let splits     (for each ((i (range<- (+ word.count 1))))
                    `(,(word .slice 0 i)
                      ,(word .slice i))))
  (let deletes    (for each (((a b) (for filter (((a b) splits))
                                      (not b.empty?))))
                    (chain a (b .slice 1))))
  (let transposes (for each (((a b) (for filter (((a b) splits))
                                      (< 1 b.count))))
                    (chain a (string<- (b 1) (b 0)) (b .slice 2))))
  (let replaces   (for gather ((a b) splits)
                    (if b.empty?
                        '()
                        (for each ((c alphabet))
                          (chain a (string<- c) (b .slice 1))))))
  (let inserts    (for gather ((a b) splits)
                    (for each ((c alphabet))
                      (chain a (string<- c) b))))
  (set<-list (chain deletes transposes replaces inserts)))

(let alphabet "abcdefghijklmnopqrstuvwxyz")

(define (train features)
  (let model (map<-))
  (for each! ((f features))
    (model .set! f (+ 1 (model .get f 1))))
  model)

(define (words<-string string)
  (re:findall "[a-z]+" string.lowercase))  ;TODO

(let NWORDS (train (words<-string (call-with-open-file "big.txt" '.read-all)))) ;TODO


;; star2.scm
;; Like https://github.com/darius/regexercise_solutions/blob/master/star.py
;; ~/git/regexercise_solutions/star.py

(define (search re chars)
  (or (nullable? re)
      (do (let states (box<- (set<- re)))
          (for some ((char chars))
            (states .^= (set<-sequence (for gather ((state states.^))
                                         (after state char))))
            (some nullable? states.^)))))

(define (nullable? r)
  (match r
    ({empty}      #yes)
    ({literal _}  #no)
    ({either s t} (or (nullable? s) (nullable? t)))
    ({chain s t}  (and (nullable? s) (nullable? t)))
    ({star _}     #yes)))

;; Or equivalently:
(make nullable?
  (({empty})      #yes)
  (({literal _})  #no)
  (({either s t}) (or (nullable? s) (nullable? t)))
  (({chain s t})  (and (nullable? s) (nullable? t)))
  (({star _})     #yes))

(define (after r char)
  (match r
    ({empty}       '())
    ({literal lit} (if (= char lit) '({empty}) '()))
    ({either s t}  (chain (after s char) (after t char)))
    ({chain s t}
     (let dr+s (for each ((r-rest (after r char)))
                 (chain<- r-rest s)))
     (if (nullable? r)
         (chain dr+s (after s char))
         dr+s))
    ({star s}
     (for each ((r-rest (after r char)))
       (chain<- r-rest star)))))

(define (chain<- r s)
  (if (= r {empty}) s {chain r s}))


;; um.scm
;; Universal Machine from http://www.boundvariable.org/task.shtml
;; Ported from https://github.com/darius/superbench
;; ~/git/superbench/um/um.lua
;; (using not-yet-implemented features and syntax)

;; TODO: s/vector/array?

;;XXX .u<op> means small, unsigned op
;; and I'm gonna assume 32-bit here
;; Similar for .s<op> (signed).
;; Do these mix OK? Is this reasonable?

;; TODO: mem could also be a typed vector, but neither the vector
;; nor the type is as simple...

(define (run program sink source)
  (let mem (fillvector<-))         ;TODO: shorter name? flexlist?
  (mem .push! program)
  (let free-list (fillvector<-))
  (let reg (vector<-count 8 0))         ;TODO: typed vector, for efficiency

  (begin running ((program program) (pc 0))

    (define (next)
      (running program (pc .u+ 1)))

    (let inst (program pc))
    (let opcode (inst .u>> 28))

    (match opcode
      (13 (reg .set! (7 .and (inst .u>> 25))
               (inst .and 0x1FFFFFF))
          (next))
      (_
       (let a (7 .and (inst .u>> 6)))
       (let b (7 .and (inst .u>> 3)))
       (let c (7 .and inst))
       (match opcode

         (0 (when (not= (reg c) 0)
              (reg .set! a (reg b)))
            (next))

         (1 (reg .set! a ((mem (reg b))
                          (reg c)))
            (next))

         (2 ((mem (reg a)) .set! (reg b) (reg c))
            (next))

         (3 (reg .set! a ((reg b) .s+ (reg c)))
            (next))

         (4 (reg .set! a ((reg b) .s* (reg c)))
            (next))

         (5 (reg .set! a ((reg b) .u/ (reg c)))
            (next))

         (6 (reg .set! a (((reg b) .and (reg c)) .not))
            (next))

         (7 "Successful exit")

         (8 (let chunk (vector<-count (reg c) 0)) ;TODO: typed vector again
            (reg .set! b
                 (case (free-list.empty?
                        (mem .push! chunk))
                       (else
                        (let i free-list.pop!)
                        (mem .set! i chunk)
                        i)))
            (next))

         (9 (mem .set! (reg c) none)    ;XXX what was 'none' about again?
            (free-list .push! (reg c))
            (next))

         (10 (sink .write-char (char<- (reg c)))
             (next))

         (11 (let s source.read-char)
             (reg .set! c
                  (if (eof-object? s) 0xFFFFFFFF (string<- s)))
             (next))

         (12 (case ((= (reg b) 0)
                    (running program (reg c)))
                   (else
                    (let new-program ((mem (reg b)) .shallow-copy))
                    (mem .set! 0 new-program)
                    (running new-program (reg c)))))

         (_ (error "Bad opcode")))))))

(define (read-program source)
  (let program (fillvector<-))
  (begin reading ()
    (let c3 source.read-char)
    (unless (eof-object? c3)
      (let c2 source.read-char)
      (let c1 source.read-char)
      (let c0 source.read-char)
      ;; TODO: a syntax for int-guard coercion instead?
      (program .push!
               (u32<-bytes c3.code c2.code c1.code c0.code))
      (reading)))
  program)                              ;TODO: snapshot it

(define (u32<-bytes b3 b2 b1 b0)
  (append-byte (append-byte (append-byte b3 b2) b1) b0))

(define (append-byte u byte)
  (byte .u+ (u .u<< 8)))
