(for each! ((n (range<- 1 31)))
  (display (match `(,(n .remainder 3) ,(n .remainder 5))
             ((0 0) "FizzBuzz")
             ((0 _) "Fizz")
             ((_ 0) "Buzz")
             (_     n)))
  (newline))
