#lang racket

(require threading
         data/maybe
         data/monad
         data/applicative)

(define (drop-up-to n xs)
  (if (or (zero? n) (empty? xs)) xs
      (drop-up-to (sub1 n) (cdr xs))))

(define (any-empty? . a)
  (not (andmap (compose1 not empty?) a)))

(define (zip-with f . a)
  (let recur ([a a]
              [result '()])
    (if (or (empty? a) (apply any-empty? a)) (reverse result)
        (recur (map stream-rest a) (cons (apply f (map stream-first a)) result)))))

(define (linspace num min max)
  (~> num in-range (sequence-map (curry * (- max min)) _) (sequence-map (curryr / num) _) (sequence-map (curry + min) _)))

(define (association-list-ref/maybe list key)
  (cond [(empty? list) nothing]
        [(eq? (car (car list)) key) (just (cdr (car list)))]
        [else (association-list-ref/maybe (cdr list) key)]))

(define (maybe-from-pred pred val)
  (if (pred val) (just val) nothing))

(define (create-server-folder path)
  (do (false->maybe (not (directory-exists? path)))
      (pure (make-directory path))))

(provide drop-up-to
         zip-with
         any-empty?
         linspace
         association-list-ref/maybe
         maybe-from-pred
         create-server-folder)