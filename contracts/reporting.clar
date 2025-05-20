;; Reporting Contract
;; Generates authenticated compliance disclosures

;; Contract dependencies
(use-trait facility-trait .facility-verification.get-facility)
(use-trait violation-trait .violation-detection.get-violation)

;; Report data structure
(define-map reports
  {
    report-id: uint
  }
  {
    facility-id: (string-ascii 32),
    report-type: (string-ascii 32),  ;; "monthly", "quarterly", "annual", "incident"
    start-period: uint,
    end-period: uint,
    creation-timestamp: uint,
    creator: principal,
    violations: (list 50 uint),  ;; List of violation IDs
    status: (string-ascii 20),  ;; "draft", "submitted", "approved", "rejected"
    hash: (optional (buff 32)),  ;; Hash of the report content
    approval-details: (optional (string-ascii 200))
  }
)

;; Counter for report IDs
(define-data-var report-counter uint u0)

;; Admin principal
(define-data-var admin principal tx-sender)

;; Public function to create a new report
(define-public (create-report
    (facility-id (string-ascii 32))
    (report-type (string-ascii 32))
    (start-period uint)
    (end-period uint)
    (violations (list 50 uint)))
  (let ((caller tx-sender)
        (current-time block-height)
        (new-report-id (+ (var-get report-counter) u1)))

    ;; Check if the facility exists
    (asserts! (is-some (contract-call? .facility-verification get-facility facility-id)) (err u1))

    ;; Create the report
    (var-set report-counter new-report-id)
    (map-insert reports
      { report-id: new-report-id }
      {
        facility-id: facility-id,
        report-type: report-type,
        start-period: start-period,
        end-period: end-period,
        creation-timestamp: current-time,
        creator: caller,
        violations: violations,
        status: "draft",
        hash: none,
        approval-details: none
      })
    (ok new-report-id)))

;; Public function to submit a report
(define-public (submit-report
    (report-id uint)
    (report-hash (buff 32)))
  (let ((caller tx-sender))
    (match (map-get? reports { report-id: report-id })
      report (if (and
                   (is-eq (get creator report) caller)
                   (is-eq (get status report) "draft"))
                (begin
                  (map-set reports
                    { report-id: report-id }
                    (merge report {
                      status: "submitted",
                      hash: (some report-hash)
                    }))
                  (ok true))
                (err u2))  ;; Error code 2: Not authorized or report not in draft status
      (err u3))))  ;; Error code 3: Report not found

;; Admin function to approve a report
(define-public (approve-report
    (report-id uint)
    (approval-details (string-ascii 200)))
  (let ((caller tx-sender))
    (if (is-eq caller (var-get admin))
      (match (map-get? reports { report-id: report-id })
        report (if (is-eq (get status report) "submitted")
                  (begin
                    (map-set reports
                      { report-id: report-id }
                      (merge report {
                        status: "approved",
                        approval-details: (some approval-details)
                      }))
                    (ok true))
                  (err u4))  ;; Error code 4: Report not in submitted status
        (err u3))  ;; Error code 3: Report not found
      (err u5))))  ;; Error code 5: Not admin

;; Admin function to reject a report
(define-public (reject-report
    (report-id uint)
    (rejection-reason (string-ascii 200)))
  (let ((caller tx-sender))
    (if (is-eq caller (var-get admin))
      (match (map-get? reports { report-id: report-id })
        report (if (is-eq (get status report) "submitted")
                  (begin
                    (map-set reports
                      { report-id: report-id }
                      (merge report {
                        status: "rejected",
                        approval-details: (some rejection-reason)
                      }))
                    (ok true))
                  (err u4))  ;; Error code 4: Report not in submitted status
        (err u3))  ;; Error code 3: Report not found
      (err u5))))  ;; Error code 5: Not admin

;; Read-only function to get report details
(define-read-only (get-report (report-id uint))
  (map-get? reports { report-id: report-id }))

;; Read-only function to verify a report hash
(define-read-only (verify-report-hash (report-id uint) (check-hash (buff 32)))
  (match (map-get? reports { report-id: report-id })
    report (match (get hash report)
             stored-hash (is-eq stored-hash check-hash)
             false)
    false))

;; Read-only function to get the total number of reports
(define-read-only (get-report-count)
  (var-get report-counter))

;; Admin function to transfer admin rights
(define-public (set-admin (new-admin principal))
  (let ((caller tx-sender))
    (if (is-eq caller (var-get admin))
      (begin
        (var-set admin new-admin)
        (ok true))
      (err u5))))  ;; Error code 5: Not admin
