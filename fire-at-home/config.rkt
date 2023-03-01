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
        (config db))))

(define (read-config-env)
  (let ([cfg-hash (hash 'database (hash 'host (getenv "DB_HOST")
                                        'port (getenv "DB_PORT")
                                        'database (getenv "DB_NAME")
                                        'user (getenv "DB_USER")
                                        'password (getenv "DB_PASSWORD")))])
    (do [db <- (read-db-cfg cfg-hash)]
        (config db))))

(define (database-cfg cfg)
  (config-database cfg))
    
(provide read-config
         read-config-env
         database-cfg
         database-host
         database-port
         database-user
         database-name
         database-password)
