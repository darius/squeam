;; A bit of Forth with local variables

(to (stack-op-2-1<- op)
  (to (stack-op-2-1 {state (link z y s) r})
    {state (link (op y z) s)
           r}))

(to (push<- literal)
  (to (push {state s r})
    {state (link literal s)
           r}))

(to (grab<- count)
  (to (grab {state s r})
    {state (s .slice count)
           (chain (s .slice 0 count) r)}))

(to (local<- k)
  (to (local {state s r})
    {state (link (r k) s)
           r}))

(to (ungrab<- count)
  (to (ungrab {state s r})
    {state s
           (r .slice count)}))

(let dictionary
  (map<- `((+ ,(stack-op-2-1<- +))
           (- ,(stack-op-2-1<- -))
           (* ,(stack-op-2-1<- *))
           (/ ,(stack-op-2-1<- /))
           )))

(to (compile tokens)
  (let code (flexarray<-))
  (begin compiling ((frames '()) (tokens tokens))
    (hm (when tokens.empty?
          (surely frames.empty?))      ;XXX require
        (else
          (may tokens.first
            (be (? number? n)
              (code .push! (push<- n))
              (compiling frames tokens.rest))
            (be '<<
              (let `(,locals ,tail)
                (split-on (-> (= it '--)) tokens.rest))
              (code .push! (grab<- locals.count))
              (compiling (link (reverse locals) frames)
                         tail.rest))
            (be '>>
              (surely (not frames.empty?)) ;XXX require
              (code .push! (ungrab<- frames.first.count))
              (compiling frames.rest tokens.rest))
            (be (? symbol? word)
              (code .push! (or (compile-local frames word)
                               (dictionary word)))
              (compiling frames tokens.rest))))))
  code.values)

(to (compile-local frames word)
  (let locals (chain @frames))      ;I think
  (mayhap local<- (locals .find word #no)))

(to (run xts)
  (for foldl ((state {state '() '()})
              (xt xts))
    (xt state)))

(let eg1 '(4 3 * 2 /))
(let eg2 '(5 3 << a b -- a a * b - >>))

(to (main _)
  (let {state s1 _} (run (compile eg1)))
  (print s1)
  (let {state s2 _} (run (compile eg2)))
  (print s2)
  )

(export main)
