#lang racket

(require db
         threading
         "config.rkt"
         "computation.rkt"
         "utils.rkt"
         data/maybe
         data/monad)

(define (database-connect database)
  (mysql-connect #:server (database-host database)
                 #:port (database-port database)
                 #:database (database-name database)
                 #:user (database-user database)
                 #:password (database-password database)
                 #:allow-cleartext-password? #t
                 #:ssl 'yes))

(define (affected-rows result)
  (cond [(not (simple-result? result)) nothing]
        [else (association-list-ref/maybe (simple-result-info result) 'affected-rows)]))

(define (database-scaffold conn)
  (begin (query-exec conn "CREATE TABLE IF NOT EXISTS ComputationJobs
(Id INT AUTO_INCREMENT PRIMARY KEY,
 GridSize INT NOT NULL,
 TreeProbability DOUBLE NOT NULL,
 JobFinished TINYINT(1) NOT NULL DEFAULT 0,
 JobAssignedDate TIMESTAMP,
 Result DOUBLE,
 ComputationTimeS DOUBLE,
 ComputationDoneBy VARCHAR(64))")
         (query-exec conn "CREATE TABLE IF NOT EXISTS Grids
(Id INT AUTO_INCREMENT PRIMARY KEY,
 GridSize INT NOT NULL UNIQUE,
 Resolution INT NOT NULL)")
         (if (= 0 (query-value conn "SELECT COUNT(1) indexExists FROM INFORMATION_SCHEMA.STATISTICS WHERE table_schema=DATABASE() AND table_name='ComputationJobs' AND index_name='idx_grid_size_tree_probability'"))
             (query-exec conn "CREATE UNIQUE INDEX idx_grid_size_tree_probability ON ComputationJobs (GridSize, TreeProbability)")
             (void 0))
         ))

(define (bind-prepared-statement/new-job statement job)
  (~> (list (job-grid-size job) (job-tree-probability job)) (bind-prepared-statement statement _)))

(define (get-grid-sizes conn)
  (query-list conn "SELECT GridSize FROM Grids"))

(define (get-grids conn)
  (map (compose1 (curry apply grid) vector->list) (query-rows conn "SELECT * FROM Grids")))

(define (insert-new-grids conn grid-sizes/list)
  (let* ([insert-pst (prepare conn "INSERT IGNORE INTO Grids (GridSize, Resolution) VALUES ( ? , 50 )")]
         [queries (map (compose1 (curry bind-prepared-statement insert-pst) list) grid-sizes/list)])
    (start-transaction conn)
    (sequence-for-each (curry query-exec conn) queries)
    (commit-transaction conn)))

(define (update-grid-resolution conn id new-resolution)
  (query-exec conn "UPDATE Grids SET Resolution=? WHERE Id=?" new-resolution id))

(define (insert-new-jobs conn jobs/sequence)
  (let* ([insert-pst (prepare conn "INSERT IGNORE INTO ComputationJobs (GridSize, TreeProbability, JobFinished)
VALUES ( ? , ? , 0 )")]
         [queries (sequence-map (curry bind-prepared-statement/new-job insert-pst) jobs/sequence)])
    (start-transaction conn)
    (sequence-for-each (curry query-exec conn) queries)
    (commit-transaction conn)))

(define (get-unfulfilled-jobs conn)
  (map (compose1 (curry apply job) vector->list)
       (query-rows conn "SELECT * FROM ComputationJobs WHERE JobFinished=0")))

(define (get-unfulfilled-jobs/count conn)
  (query-value conn "SELECT COUNT(*) FROM ComputationJobs WHERE JobFinished=0"))

(define (get-unqueued-jobs/count conn)
  (query-value conn "SELECT COUNT(*) FROM ComputationJobs
WHERE JobFinished = 0 AND JobAssignedDate IS NULL"))

(define (get-unqueued-jobs/maybe-first conn)
  (let ([job-row (query-maybe-row conn "SELECT * FROM ComputationJobs
 WHERE JobFinished = 0 AND JobAssignedDate IS NULL
 ORDER BY Id ASC
 LIMIT 1")])
    (if (eq? job-row #f)
        nothing
        (just (apply job (vector->list job-row))))))

(define (register-job conn id username)
  (do [rows <- (affected-rows (query conn "UPDATE ComputationJobs SET JobAssignedDate=NOW(), ComputationDoneBy=?
  WHERE Id=? AND ComputationDoneBy IS NULL AND JobAssignedDate IS NULL" username id))]
    (maybe-from-pred positive? rows)))

(define (insert-job-result conn id username result seconds-spent)
  (do [rows <- (affected-rows (query conn "UPDATE ComputationJobs SET Result=?, ComputationTimeS=?, JobFinished=1
 WHERE Id=? AND ComputationDoneBy=?" result seconds-spent id username))]
    (maybe-from-pred positive? rows)))

(define (restore-timed-out-jobs conn)
  (query-exec conn "UPDATE ComputationJobs
SET JobAssignedDate = NULL, ComputationDoneBy = NULL
WHERE JobFinished = 0 AND JobAssignedDate < (NOW() - INTERVAL 1 HOUR)"))

(define (get-contributors conn)
  (map (compose1 (curry apply cons) vector->list)
       (query-rows conn "SELECT ComputationDoneBy, SUM(ComputationTimeS) as t FROM ComputationJobs WHERE ComputationDoneBy IS NOT NULL GROUP BY ComputationDoneBy ORDER BY t")))

(define (get-results conn grid-size)
  (query-rows conn "SELECT TreeProbability, Result FROM ComputationJobs WHERE GridSize=? AND JobFinished=1" grid-size))

(provide database-connect
         database-scaffold
         insert-new-grids
         get-grid-sizes
         get-grids
         update-grid-resolution
         insert-new-jobs
         get-unfulfilled-jobs
         get-unfulfilled-jobs/count
         get-unqueued-jobs/count
         get-unqueued-jobs/maybe-first
         register-job
         insert-job-result
         restore-timed-out-jobs
         get-contributors
         get-results)

