#lang racket

(require threading)

(define FIRE 'f)
(define TREE 't)
(define EMPTY 'e)

(define (generate-tree-row n p)
  (build-list n (lambda (k)
                  (if (> (random) p) EMPTY TREE))))

(define (generate-forest n p)
  (build-list n (lambda (k)
                  (generate-tree-row n p))))

(define (any-empty? . a)
  (not (andmap (compose1 not empty?) a)))

(define (zip-with f . a)
  (let recur ([a a]
              [result '()])
    (if (or (empty? a) (apply any-empty? a)) (reverse result)
        (recur (map cdr a) (cons (apply f (map car a)) result)))))

(define (lefts forest)
  (map (curry cons EMPTY) forest))

(define (rights forest)
  (map (compose1 cdr reverse (curry cons EMPTY) reverse) forest))

(define (uppers forest)
  (~> forest (cons (map (const EMPTY) (car forest)) _)))

(define (lowers forest)
  (~> forest reverse (cons (map (const EMPTY) (car forest)) _) reverse cdr))

(define (burn el up down left right)
  (if (and (eq? el TREE) (or (eq? up FIRE) (eq? down FIRE) (eq? left FIRE) (eq? right FIRE)))
      (cons FIRE #t)
      (cons el #f)))

(define (burn-first-row forest)
  (cons (map (lambda (el) (if (eq? el TREE) FIRE el))
             (car forest))
        (cdr forest)))

(define (sweep forest)
  (zip-with (curry zip-with burn)
            forest (uppers forest) (lowers forest) (lefts forest) (rights forest)))

(define (did-burn? after-sweep)
  (ormap identity
         (flatten (map
                   (curry map cdr)
                   after-sweep))))

(define (next-forest after-sweep)
  (map (curry map car) after-sweep))

(define (do-sweeps forest)
  (let recur ([forest (burn-first-row forest)]
              [n 0])
    (let ([next (sweep forest)])
      (if (did-burn? next)
          (recur (next-forest next) (add1 n))
          n))))

(define test-forest (list (list TREE  EMPTY EMPTY EMPTY)
                          (list TREE  EMPTY TREE  EMPTY TREE)
                          (list TREE  TREE  TREE  EMPTY TREE)
                          (list EMPTY TREE  TREE  EMPTY EMPTY)
                          (list EMPTY EMPTY TREE  TREE  TREE)))

(define initial-fire (burn-first-row test-forest))