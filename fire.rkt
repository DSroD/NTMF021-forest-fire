#lang racket/base

(require racket/string
         racket/list
         racket/vector
         racket/function
         racket/future
         threading)

; constants
(define TREE 't)
(define FIRE 'f)
(define EMPTY 'e)
; some helper functions...
(define (take-up-to n xs)
  (let recur ([xs xs]
              [n n]
              [result '()])
    (if (or (zero? n) (empty? xs))
        (reverse result)
        (recur (cdr xs) (sub1 n) (cons (car xs) result)))))

(define (drop-up-to n xs)
  (if (or (zero? n) (empty? xs)) xs
      (drop-up-to (sub1 n) (cdr xs))))

(define (chunks-of n xs)
  (let recur ([xs xs]
              [result '()])
    (if (empty? xs)
        (reverse result)
        (recur (drop-up-to n xs) (cons (take-up-to n xs) result)))))
; forest - side size and vector of contents
(struct forest (size [contents #:mutable])
  #:guard (lambda (size contents type-name)
            (cond
              [(< size 1) (error type-name "Size must be positive")]
              [(not (= (* size size) (vector-length contents))) (error type-name "Size does not correspond to content size")]
              [else (values size contents)]
              )))
; human-readable representation of forest
(define (forest->string forest)
  (~> (forest-contents forest) (vector-map (lambda (el)
                (cond [(eq? el TREE) #\🌲]
                      [(eq? el FIRE) #\🔥]
                      [else #\❌])) _)
      vector->list
      (chunks-of (forest-size forest) _)
      (map list->string _)
      (string-join _ "\n")))
; generate forest and set top row ON FIRE
(define (generate-forest n p)
  (forest n (build-vector (* n n) (lambda (k) (if (> (random) p)
                                                  EMPTY
                                                  (if (< k n) FIRE TREE))))))
; get grid cell (forest) contents
(define (cell-at forest index)
  (vector-ref (forest-contents forest) index))
; set grid cell
(define (set-cell-at! forest index val)
  (vector-set! (forest-contents forest) index val))
; is index in forest bounds?
(define (is-in-grid? grid-size index)
    (and (< -1 index (* grid-size grid-size))))
; indices of neighbouring cells
(define (neighbours-indices grid-size index)
  (filter (curry is-in-grid? grid-size)
          (list (add1 index) (- index 1)
                (+ index grid-size) (- index grid-size))))
; values of neighbouring cells
(define (neighbour-values forest index)
  (let ([indices (neighbours-indices (forest-size forest) index)])
    (let fill ([vals (map (curry cell-at forest) indices)])
      (if (= (length vals) 4)
          vals
          (fill (cons EMPTY vals))))))
; decides if el should be set ON FIRE
(define (burn el up down left right)
  (if (and (eq? el TREE) (or (eq? up FIRE) (eq? down FIRE) (eq? left FIRE) (eq? right FIRE)))
      (cons FIRE #t)
      (cons el #f)))
; sweeps and burns trees in a mutable way
(define (sweep forest)
  (let recur ([n 0]
              [idempotent #f])
    (let* ([size (forest-size forest)]
           [change (apply (curry burn (cell-at forest n)) (neighbour-values forest n))])
      (begin (set-cell-at! forest n (car change))
             (if (= n (sub1 (* size size))) ; last...
                 (or idempotent (cdr change)) ; return if this sweep changed anything...
                 (recur (add1 n) (or idempotent (cdr change))))))))
; sweep until no changes are made...
(define (do-sweep forest)
  (let recur ([n 0])
    (if (sweep forest)
        (recur (add1 n))
        n)))

(define (generate-forests n a p)
  (build-list n (thunk* (generate-forest a p))))

(define (sweep/future forest)
  (future (lambda () (do-sweep forest))))

; mean over 1024 runs
(define (mean-time/future a p)
  (let* ([forests (generate-forests 1024 a p)]
         [futures (map sweep/future forests)])
    (/ (apply + (map touch futures)) 1024)))

; (visualize-futures (time (mean-time/future 128 64 0.5)))

(provide mean-time/future)