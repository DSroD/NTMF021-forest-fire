#lang racket

(require web-server/servlet
         web-server/templates
         web-server/dispatch
         web-server/http/json
         web-server/configuration/responders
         json
         xml
         db
         data/maybe
         data/monad
         data/applicative
         "computation.rkt"
         "database.rkt")

(define (queue-and-register/maybe conn name)
  (do [job <- (get-unqueued-jobs/maybe-first conn)]
      (register-job conn (job-id job) name)
      (pure job)))

(define (get-result-data/maybe raw-data)
  (let ([expr (bytes->jsexpr raw-data)])
    (if (and (hash? expr) (andmap (curry hash-has-key? expr) '(result elapsed)))
        (just (apply cons (map (curry hash-ref expr) '(result elapsed))))
        nothing)))

(define (insert-result conn req id name)
  (do [data <- (get-result-data/maybe (request-post-data/raw req))]
      (insert-job-result conn id name (car data) (cdr data))))

(define (index conn req)
  (response/xexpr (include-template/xml "./pages/index.html")))

(define (queue conn req n)
  (response/jsexpr (maybe 'null job->queue-hash (queue-and-register/maybe conn n))))

(define (result conn req n i)
  (response/jsexpr (maybe #f positive? (insert-result conn req i n))))

(define (err404 req)
  (response/xexpr #:code 404 (include-template/xml "./pages/404.html")))

(define (dispatch-rules-with-conn conn)
  (dispatch-rules
   [("") (curry index conn)]
   [("queue" (string-arg)) (curry queue conn)]
   [("result" (string-arg) (integer-arg)) #:method "post" (curry result conn)]))
  

(define (fire-at-home-srv conn)
  (define-values (server-dispatch url)
    (dispatch-rules-with-conn conn))
  (λ (req)
    (server-dispatch req)))
    

(provide fire-at-home-srv
         err404)