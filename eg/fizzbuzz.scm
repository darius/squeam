(for each! ((n (1 .to 30)))
  (format "~d\n" (may [(n .remainder 3)
                       (n .remainder 5)]
                   (be [0 0] "FizzBuzz")
                   (be [0 _] "Fizz")
                   (be [_ 0] "Buzz")
                   (else     n))))
