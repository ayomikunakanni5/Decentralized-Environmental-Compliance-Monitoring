;; Permit Management Contract
;; Records authorized emission levels for facilities

(define-data-var admin principal tx-sender)

;; Permit data structure
(define-map permits
  {
    facility-id: (string-ascii 32),
    pollutant-type: (string-ascii 32)
  }
  {
    max-emission-level: uint,
    unit: (string-ascii 10),
    issue-date: uint,
    expiry-date: uint,
    issuer: principal,
    active: bool
  }
)

;; Track all permits for a facility
(define-map facility-permits
  { facility-id: (string-ascii 32) }
  { permit-list: (list 20 (tuple (pollutant-type (string-ascii 32)))) }
)

;; Admin function to issue a new permit
(define-public (issue-permit
    (facility-id (string-ascii 32))
    (pollutant-type (string-ascii 32))
    (max-emission-level uint)
    (unit (string-ascii 10))
    (validity-period uint))
  (let ((caller tx-sender)
        (current-height block-height)
        (expiry (+ current-height validity-period)))
    (if (is-eq caller (var-get admin))
      (begin
        ;; Insert the permit
        (map-set permits
          {
            facility-id: facility-id,
            pollutant-type: pollutant-type
          }
          {
            max-emission-level: max-emission-level,
            unit: unit,
            issue-date: current-height,
            expiry-date: expiry,
            issuer: caller,
            active: true
          })

        ;; Update the facility's permit list
        (match (map-get? facility-permits { facility-id: facility-id })
          existing-permits (map-set facility-permits
                            { facility-id: facility-id }
                            { permit-list: (unwrap-panic (as-max-len?
                                            (append (get permit-list existing-permits)
                                                   {pollutant-type: pollutant-type})
                                            u20)) })
          ;; If no permits exist yet, create a new list
          (map-insert facility-permits
            { facility-id: facility-id }
            { permit-list: (list {pollutant-type: pollutant-type}) })
        )

        (ok true))
      (err u1))))  ;; Error code 1: Not authorized

;; Admin function to revoke a permit
(define-public (revoke-permit
    (facility-id (string-ascii 32))
    (pollutant-type (string-ascii 32)))
  (let ((caller tx-sender))
    (if (is-eq caller (var-get admin))
      (match (map-get? permits { facility-id: facility-id, pollutant-type: pollutant-type })
        permit (begin
          (map-set permits
            { facility-id: facility-id, pollutant-type: pollutant-type }
            (merge permit { active: false }))
          (ok true))
        (err u2))  ;; Error code 2: Permit not found
      (err u1))))  ;; Error code 1: Not authorized

;; Read-only function to get permit details
(define-read-only (get-permit (facility-id (string-ascii 32)) (pollutant-type (string-ascii 32)))
  (map-get? permits { facility-id: facility-id, pollutant-type: pollutant-type }))

;; Read-only function to get all permits for a facility
(define-read-only (get-facility-permits (facility-id (string-ascii 32)))
  (map-get? facility-permits { facility-id: facility-id }))

;; Read-only function to check if a permit is active
(define-read-only (is-permit-active (facility-id (string-ascii 32)) (pollutant-type (string-ascii 32)))
  (match (map-get? permits { facility-id: facility-id, pollutant-type: pollutant-type })
    permit (and (get active permit) (<= block-height (get expiry-date permit)))
    false))

;; Admin function to transfer admin rights
(define-public (set-admin (new-admin principal))
  (let ((caller tx-sender))
    (if (is-eq caller (var-get admin))
      (begin
        (var-set admin new-admin)
        (ok true))
      (err u1))))  ;; Error code 1: Not authorized
