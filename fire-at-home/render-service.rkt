#lang racket/base

(require racket/string
         racket/function
         racket/list
         plot/no-gui
         plot/utils
         data/maybe
         data/monad
         data/applicative
         "utils.rkt"
         "database.rkt"
         "computation.rkt")

(define (get-results/maybe conn grid-sizes)
  (let ([pts (map (curry get-results conn) grid-sizes)])
    (if (or (empty? pts) (andmap empty? pts))
        nothing
        (just pts))))

(define (map-renderers grid-sizes pts)
  (zip-with (λ (symbol color size pt)
               (points #:y-min 0.1 #:color (->pen-color color) #:size 12 #:sym symbol #:label (number->string size) pt))
            (drop-up-to 2 known-point-symbols) (in-naturals) grid-sizes pts))
         

(define (plot-grid conn grid-sizes file-name)
  (parameterize ([plot-y-transform  log-transform]
                 [plot-y-ticks (log-ticks #:base 10)]
                 [plot-x-label "Tree probability"]
                 [plot-y-label "Burn time"]
                 [plot-legend-anchor 'top-right])
  (do [results <- (get-results/maybe conn grid-sizes)]
      [renderers <- (pure (map-renderers grid-sizes results))]
      (pure (plot-file renderers (string-append "./static/img/" file-name ".jpg"))))))

(define (get-grid-sizes conn)
  (let ([grids (get-grids conn)])
    (if (empty? grids)
        nothing
        (just (map grid-size grids)))))

(define (plot-graph conn)
  (do [sizes <- (get-grid-sizes conn)]
      (pure (plot-grid conn sizes "fire"))))

(define (render-service conn)
  (thread (λ () (let loop ()
                  (displayln "Rendering graph...")
                  (plot-graph conn)
                  (sleep 300)
                  (loop)))))

(provide render-service)
                  
                        