#lang racket

(require json
         data/maybe
         data/monad
         data/applicative)

(struct database (host port name user password)
  #:guard (λ (host port name user password type-name)
            (cond [(not (integer? port)) (error "Port must be an integer")]
                  [else (values host port name user password)])))

(struct config (database)
  #:guard (λ (database type-name)
            (cond [(not (database? database)) (error "Not valid db configuration")]
                  [else (values database)])))

(define (read-db-cfg cfg-hash)
  (let ([db-hash (hash-ref cfg-hash 'database nothing)])
    (if (andmap (curry hash-has-key? db-hash) '(host port database user password))
        (just (apply database (map (curry hash-ref db-hash) '(host port database user password))))
        nothing)))

(define (read-config cfg-in)
  (let ([cfg-hash (read-json cfg-in)])
    (do [db <- (read-db-cfg cfg-hash)]
        [test <- (just 1)]
        (config db))))

(define (database-cfg cfg)
  (config-database cfg))
    
(provide read-config
         database-cfg
         database-host
         database-port
         database-user
         database-name
         database-password)
