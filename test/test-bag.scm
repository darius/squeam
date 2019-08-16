;; TODO this is a dupe of test-hashmap, c'mon

(let a (bag<-))
(print a)
(print (a .get 42))
(a .add! 'x)
(print a)
(print (a .get 'x))
(a .add! 'x)
(print a)
(print (a .get 'x))
(print (a .get 'y 'nope))

(a .add! 'z)
(print a)
(print (a .get 'x))
(print (a .get 'y))
(print (a .get 'z))
(print (list<- a.keys a.values a.items a.none? a.count))
(print (a 'z))

;; TODO more tests

(import (use 'random) rng<-)

(let rng (rng<- 1234567))

(to (random-tests n-trials)            ;TODO use squickcheck
  (for each! ((_ (0 .to< n-trials)))
    (exercise-em (for each ((value (0 .to< 50))) ;TODO did I mean to use the value?
                   (rng .random-integer 5)))))

(to (exercise-em keys)
  (let m (bag<-))     ;; The bag under test.
  (let a (box<- '())) ;; A list of keys seen so far.
  (for each! ((key keys))
    (let m-val (m .get key 0))
    (let a-val (tally-by (-> (= key it)) a.^))
    (surely (= m-val a-val) "mismatch" key m-val a-val)

    (m .add! key)
    (a .^= (link key a.^))))

(random-tests 13)
