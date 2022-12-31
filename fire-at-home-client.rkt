#lang racket/base

(define QUERY-SERVER "http://corona-mc.eu:8000")

(require racket/string
         racket/function
         threading
         net/url
         json
         data/maybe
         data/monad
         data/applicative
         "fire.rkt")

(struct job (id grid-size tree-probability))

(define (response->job/maybe response)
  (let ([jsexpr (read-json response)])
    (if (and (hash? jsexpr) (andmap (curry hash-has-key? jsexpr) '(job-id grid-size tree-probability)))
        (just (apply job (map (curry hash-ref jsexpr) '(job-id grid-size tree-probability))))
        nothing)))

(define (get-job/maybe username)
  (~> (string-join (list QUERY-SERVER "queue" username) "/") string->url get-pure-port response->job/maybe))

(define (get-result job)
  (define-values (result-list cpu-time real-time gc-time)
    (time-apply mean-time/future (list (job-grid-size job) (job-tree-probability job))))
  (cons (exact->inexact (car result-list)) (exact->inexact (/ real-time 1000))))

(define (result->post-bytes result)
  (~> (make-hasheq (list (cons 'result (car result))
                         (cons 'elapsed (cdr result))))
      jsexpr->bytes))

(define (post-result username id result)
  (~> (string-join (list QUERY-SERVER "result" username (number->string id)) "/") string->url (post-pure-port _ (result->post-bytes result))))

(define (compute username)
  (do [job <- (get-job/maybe username)]
      (pure (println (string-append "Fetched job " (number->string (job-id job)) ". Starting work...")))
      [result <- (pure (get-result job))] ; perform job
      (pure (println (string-append "Computation finished. Real time: " (number->string (cdr result)) "s. Sending result to server...")))
      [response <- (pure (post-result username (job-id job) result))] ; send result to server
      (pure (println (if (eq? (read-json response) #t) "Success." "Could not send data to server...")))
    ))

(define (main)
  (display "Username:")
  (define username (read-line (current-input-port) 'any))
  (let loop ()
    (compute username)
    (loop)))

(main)