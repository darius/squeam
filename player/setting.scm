(library (player setting)
(export setting? make-setting setting-a-list
        setting-binds? setting-extend-promises
        mutable-setting?
        setting/missing
        setting-lookup global-lookup
        setting-extend-promises setting-resolve!
        setting-extend
        setting-ensure-bound
        setting-inner-variables

        global-lookup global-init! 
        global-defined? really-global-define!
        )
(import (chezscheme) (player util) (player thing))

;; Wrapper for settings
;; The representation will change soon

(define-record-type setting (fields a-list))

(define setting/missing (list '*missing*))

(define (setting-extend variables values setting)
  (make-setting
   (append (map cons variables values)
           (setting-a-list setting))))

(define (setting-lookup setting variable)
  (let ((r (setting-a-list setting)))
    (cond ((assq variable r) => cdr)
          (else (global-lookup variable)))))

(define (setting-ensure-bound setting variables)
  (cond ((null? variables) setting)
        ((mutable-setting? setting)
         ;; Not currently needed, but a placeholder for what will be
         (for-each (lambda (v)
                     (insist (not (already-bound? setting v)) "Already bound" v)
                     (global-init! v uninitialized))
                   variables)
         setting)
        (else
         (setting-extend-promises setting variables))))

;; TODO skip if vs null
(define (setting-extend-promises setting vs)
  (let consing ((vs vs)
                (r (setting-a-list setting)))
    (if (null? vs)
        (make-setting r)
        (consing (cdr vs) (cons (cons (car vs) uninitialized) r)))))

;; Return #f on success, else a complaint.
(define (setting-resolve! setting name value)
  (let ((r (setting-a-list setting)))
    (cond ((assq name r)
           => (lambda (pair)
                (if (eq? (cdr pair) uninitialized)
                    (begin (set-cdr! pair value) #f)
                    "Multiple definition")))
          ((null? r)
           (really-global-define! name value)
           #f)
          (else "Tried to bind in a non-environment"))))

(define (mutable-setting? setting)
  (null? (setting-a-list setting)))

;; XXX hackety hack hack hack
(define (already-bound? setting variable)
  (or (assq variable (setting-a-list setting))
      (not (eq? uninitialized (eq-hashtable-ref globals variable uninitialized)))))

(define (setting-binds? setting variable)
  (or (assq variable (setting-a-list setting))
      (global-defined? variable)))

(define (setting-inner-variables setting)
  ;; TODO dedupe
  (map car (setting-a-list setting)))



;; scaffolding XXX

(define globals (make-eq-hashtable))

(define (global-defined? v)
  ;;XXX or (not (eq? value uninitialized))
  (eq-hashtable-contains? globals v))

(define (global-lookup v)
  (eq-hashtable-ref globals v setting/missing))

(define (global-init! v value)
  (eq-hashtable-set! globals v value))

(define (really-global-define! v value)
  ;;XXX as a hack, allow global redefinition for
  ;; now. This aids development at the repl, but we
  ;; need a more systematic solution.
  ;;(signal k "Global redefinition" v)
  (let ((value (eq-hashtable-ref globals v setting/missing)))
    (unless (or (eq? value setting/missing)
                (eq? value uninitialized))
      (display "\nWarning: redefined ")
      (write v)
      (newline)))
  (eq-hashtable-set! globals v value))

)
