;; Generic sorting

(make sort
  ((xs)
   (sort-by xs compare))
  ((xs {reverse})            ;TODO design a better keyword-args scheme
   (sort-by xs compare-reversed))
  ;; ...
  )

(define (compare-reversed x y)
  (compare y x))

(define (sort-by sequence cmp)

  (define (merge-sort seq)
    (begin splitting ((seq seq) (xs '()) (ys '()))
      (if seq.empty?
          (if xs.empty?
              ys
              (merge (merge-sort xs) (merge-sort ys)))
          (splitting seq.rest ys (cons seq.first xs)))))

  (define (merge xs ys)
    (case (xs.empty? ys)
          (ys.empty? xs)
          (else (if (<= (cmp xs.first ys.first) 0) ;TODO error if cmp result is not in -1..1?
                    `(,xs.first ,@(merge xs.rest ys))
                    `(,ys.first ,@(merge xs ys.rest))))))

  (merge-sort sequence))

(export sort sort-by)
