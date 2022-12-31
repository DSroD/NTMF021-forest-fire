#lang racket

(require threading
         "utils.rkt")

(struct job (id grid-size tree-probability job-finished job-assigned-date result time-seconds done-by))
(struct grid (id size resolution))

(define (generate-new-jobs grid-size resolution)
  (~> (linspace resolution 1 0) (sequence-map (λ (p) (job 'null grid-size p #f 'null 'null 'null 'null)) _)))

(define (job->queue-hash job)
  (make-hasheq (list (cons 'job-id (job-id job))
                     (cons 'grid-size (job-grid-size job))
                     (cons 'tree-probability (job-tree-probability job)))))

(provide (struct-out job)
         job->queue-hash
         (struct-out grid)
         generate-new-jobs)