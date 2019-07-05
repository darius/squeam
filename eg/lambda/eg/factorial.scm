;; Factorial of Church numbers

(let one (succ zero))

(to (Pair a b take) (take a b))

(to (factorial n)
  (to (step pair)
    (pair ([k p]
           (let k1 (succ k))
           (Pair k1 (* k1 p)))))
  (n step
     (Pair zero one)
     ([k p] p)))

(count<-church (factorial (church<-count 5)))
