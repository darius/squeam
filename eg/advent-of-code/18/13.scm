;; (Use run.scm to run this.)

(let inputs (with-input-file _.read-all data-file))

(to (parse world-str)
  (surely (hide (let widths (each _.count world-str.split-lines))
                (= 1 widths.range.count)))
  (let width world-str.split-lines.first.count.up)
  (let carts (map<-))
  (let tracks (flexarray<-))
  (to (add-cart! i dir)
    (tracks .push! (erase-cart dir))
    (carts .set! i {cart dir 0}))
  (for each! ((`(,i ,ch) world-str.items))
    (may ch
      (be #\> (add-cart! i E))
      (be #\< (add-cart! i W))
      (be #\v (add-cart! i S))
      (be #\^ (add-cart! i N))
      (else   (tracks .push! ch))))
  {world (string<-list tracks.values) width carts})


;; Directions

(let N 0)
(let E 1)
(let S 2)
(let W 3)

(to (step width dir) ; we could prob. pass an array around instead of width
  (may dir
    (be 0 (- width))
    (be 1 1)
    (be 2 width)
    (be 3 -1)))

(to (erase-cart dir)
  ("|-|-" dir))

(to (show-cart {cart dir _})
  ("^>v<" dir))

(to (maybe-turn cart ch)
  (let {cart dir veer} cart)
  (may ch
    (be #\/ {cart (turn-1 dir) veer})
    (be #\\ {cart (turn-2 dir) veer})
    (be #\+ (swerve dir veer))
    (else   cart)))

(to (turn-1 dir) ; /  n e s w
                 ; -> e n w s
  (  '[1 0 3 2] dir))

(to (turn-2 dir) ; \  n e s w
                 ; -> w s e n
  (  '[3 2 1 0] dir))

(to (turn-right dir) ;    n e s w
                     ; -> e s w n
  (dir.up .modulo 4))

(to (turn-left dir)
  (dir.- .modulo 4))

(to (swerve dir veer)
  (may veer
    (be 0 {cart (turn-left dir) 1})
    (be 1 {cart dir 2})
    (be 2 {cart (turn-right dir) 0})))


;; Here we go

(let world0 (parse inputs))

(to (show {world tracks w carts})
  (for each! ((`(,i ,ch) tracks.items))
    (let opt-cart (carts .get i))
    (display (if opt-cart (show-cart opt-cart) ch)))
  (newline))

(to (part1)
;  (show world0)
  (begin ticking ((state world0) (t 0))
    (when (< t 20000)
;      (format "time ~w\n" t)
      (let `(,state1 ,crashes) (tick state))
;      (show state1)
      (if crashes.empty?
          (ticking state1 t.up)
          (xy-coords state crashes.first)))))

(to (xy-coords {world _ width _} pos)
  (reverse (pos ./mod width)))

(to (tick {world tracks width carts})
  (let carts1 carts.copy)
  (let crashes (flexarray<-))
  (for each! ((pos (sort carts.keys)))
    (unless (crashes .find? pos)
      (move! pos carts tracks width carts1 crashes)))
  (list<- {world tracks width carts1}
          crashes.values))

(to (move! pos carts tracks width carts1 crashes)
  (let {cart dir veer} (carts pos))
  (let new-pos (+ pos (step width dir)))
  (when (carts1 .maps? new-pos)
;    (format "splat!\n")
    (crashes .push! new-pos))
  (let new-cart (maybe-turn {cart dir veer} (tracks new-pos)))
  (let {cart new-dir _} new-cart)
;  (format "pos: ~w dir: ~w to new pos: ~w dir: ~w\n"
;          pos dir new-pos new-dir)
  (carts1 .delete! pos)
  (carts1 .set! new-pos new-cart))

(format "~w\n" (part1))


(display "\nPart 2\n")

(to (part2)
  (begin ticking ((state world0) (t 0))
    (when (< t 200000000)
      (let {world _ _ pre-carts} state)
      (when (1000 .divides? t)
        (format "time ~w pop ~w\n" t pre-carts.count))
      (if (= pre-carts.count 1)
          (xy-coords state pre-carts.keys.first)
          (do (let `(,state1 ,crashes) (tick state))
              (let {world tracks width carts} state1)
              (for each! ((pos crashes))
                (carts .delete! pos))
              (ticking state1 t.up))))))

(format "~w\n" (part2))
