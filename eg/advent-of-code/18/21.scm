;; (Use run.scm to run this.)

(let input (with-input-file _.read-lines data-file))

(let the-ip (number<-string (input.first.split 1)))
(print the-ip)

(let the-program (array<-list
                  (for each ((line input.rest))
                    (let v line.split)
                    `(,(symbol<- v.first) ,@(each number<-string v.rest)))))
(to (print-insn (list<- op a b c))
  (format "[~w,~w,~w,~w],\n" op a b c))

;(each! print-insn the-program)
;(print the-program.count)
;(exit 0)

(to (show insn)
  ("~d ~w ~w ~w" .format @insn))

(to (vm<- regs ip program)
  (make vm

    (to _.run
      (begin running ()
;       (when vm.step (running))))
        (when (program .maps? (regs ip))
          (format "ip=~w ~w ~d " (regs ip) regs (show (program (regs ip))))
          vm.step
          (format " ~w\n" regs)
          (running))))

    (to _.step
      (let here (regs ip))
      (may (program .get here)
        (be #no #no)
        (be `(,op ,a ,b ,c)
          (vm .do op a b c)
          (regs .set! ip (+ (regs ip) 1))
          (when (= here 7)
            (format "ip=~w ~w ~d " (regs ip) regs (show (program (regs ip)))))
          #yes)))

    (to (_ .do op a b c)
      (let result
        (may op

          (be 'addr  (+ (regs a) (regs b)))
          (be 'addi  (+ (regs a) b))

          (be 'mulr  (* (regs a) (regs b)))
          (be 'muli  (* (regs a) b))

          (be 'banr  ((regs a) .and (regs b)))
          (be 'bani  ((regs a) .and b))
       
          (be 'borr  ((regs a) .or (regs b)))
          (be 'bori  ((regs a) .or b))
       
          (be 'setr  (regs a))
          (be 'seti  a)
       
          ;; TODO I'm not sure about this method name claim.count
          (be 'gtir  (_.count (> a (regs b))))
          (be 'gtri  (_.count (> (regs a) b)))
          (be 'gtrr  (_.count (> (regs a) (regs b))))
       
          (be 'eqir  (_.count (= a (regs b))))
          (be 'eqri  (_.count (= (regs a) b)))
          (be 'eqrr  (_.count (= (regs a) (regs b))))
       
         ))
      (regs .set! c result))

    (to _.get-regs
      regs)
    ))

(display "\nPart 1\n")

(let the-regs (array<-count 6 0))
(let the-vm (vm<- the-regs the-ip the-program))

(to (part-1)
  the-vm.run
  (the-regs 0))

(format "~w\n" (part-1))


(display "\nPart 2\n")

(to (part-2)
  'xxx)

;(format "~w\n" (part-2))
