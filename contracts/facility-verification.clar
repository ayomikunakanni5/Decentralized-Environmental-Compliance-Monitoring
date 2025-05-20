;; Facility Verification Contract
;; Validates industrial sites and maintains their registration status

(define-data-var admin principal tx-sender)

;; Facility data structure
(define-map facilities
  { facility-id: (string-ascii 32) }
  {
    owner: principal,
    name: (string-ascii 100),
    location: (string-ascii 100),
    industry-type: (string-ascii 50),
    verified: bool,
    registration-date: uint,
    verification-date: (optional uint)
  }
)

;; Public function to register a new facility
(define-public (register-facility
    (facility-id (string-ascii 32))
    (name (string-ascii 100))
    (location (string-ascii 100))
    (industry-type (string-ascii 50)))
  (let ((caller tx-sender))
    (if (map-insert facilities
          { facility-id: facility-id }
          {
            owner: caller,
            name: name,
            location: location,
            industry-type: industry-type,
            verified: false,
            registration-date: block-height,
            verification-date: none
          })
        (ok true)
        (err u1))))  ;; Error code 1: Facility ID already exists

;; Admin function to verify a facility
(define-public (verify-facility (facility-id (string-ascii 32)))
  (let ((caller tx-sender))
    (if (is-eq caller (var-get admin))
      (match (map-get? facilities { facility-id: facility-id })
        facility (begin
          (map-set facilities
            { facility-id: facility-id }
            (merge facility {
              verified: true,
              verification-date: (some block-height)
            }))
          (ok true))
        (err u2))  ;; Error code 2: Facility not found
      (err u3))))  ;; Error code 3: Not authorized

;; Read-only function to get facility details
(define-read-only (get-facility (facility-id (string-ascii 32)))
  (map-get? facilities { facility-id: facility-id }))

;; Read-only function to check if a facility is verified
(define-read-only (is-facility-verified (facility-id (string-ascii 32)))
  (match (map-get? facilities { facility-id: facility-id })
    facility (get verified facility)
    false))

;; Admin function to transfer admin rights
(define-public (set-admin (new-admin principal))
  (let ((caller tx-sender))
    (if (is-eq caller (var-get admin))
      (begin
        (var-set admin new-admin)
        (ok true))
      (err u3))))  ;; Error code 3: Not authorized
