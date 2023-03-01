#lang racket

(require "fire-at-home/config.rkt"
         "fire-at-home/database.rkt"
         "fire-at-home/server.rkt"
         "fire-at-home/job-service.rkt"
         "fire-at-home/render-service.rkt"
         "fire-at-home/utils.rkt"
         racket/runtime-path
         web-server/servlet-env)

(create-server-folder (build-path "static" "img"))

(define cfg (read-config-env))

(define db-conn (database-connect (database-cfg cfg)))
(database-scaffold db-conn)
; create service...
(define job-service-worker (job-service db-conn))
(define render-service-worker (render-service db-conn))

(serve/servlet (fire-at-home-srv db-conn)
               #:extra-files-paths (list (build-path (current-directory) "./static/"))
               #:file-not-found-responder err404
               #:listen-ip "0.0.0.0"
               #:servlet-path ""
               #:launch-browser? #f
               #:servlet-regexp #rx"")

; explicitly kill services...
(kill-thread job-service-worker)
(kill-thread render-service-worker)
