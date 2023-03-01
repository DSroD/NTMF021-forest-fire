#lang racket

(require threading
         "database.rkt"
         "computation.rkt")

(define GRID-SIZES '(32 64 128 256 512 1024 2048 4096))

(define (populate-grid-size conn grid)
  (let ([gr-size (grid-size grid)]
        [new-gr-resolution (* 2 (grid-resolution grid))])
    (~> (generate-new-jobs gr-size new-gr-resolution) (insert-new-jobs conn _))
    (update-grid-resolution conn (grid-id grid) new-gr-resolution)))

(define (job-service conn)
  (thread (λ () (let loop ()
                  (displayln "Job service performing tasks...")
                  ; create grids if none found
                  (if (empty? (get-grids conn))
                      (insert-new-grids conn GRID-SIZES)
                      (void 0))
                  ; restore timed out jobs
                  (restore-timed-out-jobs conn)
                  ; if there are no unqueued jobs create new
                  (if (= 0 (get-unqueued-jobs/count conn))
                      (let ([grids (get-grids conn)])
                        (map (curry populate-grid-size conn) grids))
                      (void 0))
                  (sleep 60)
                  (loop)
                  ))))

(provide job-service)