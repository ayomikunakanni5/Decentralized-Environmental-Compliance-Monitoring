;; Sensor Data Contract
;; Tracks real-time environmental metrics from monitoring sensors

(define-data-var admin principal tx-sender)

;; Sensor data structure
(define-map sensors
  { sensor-id: (string-ascii 32) }
  {
    facility-id: (string-ascii 32),
    sensor-type: (string-ascii 32),
    location: (string-ascii 100),
    active: bool,
    registration-date: uint,
    last-maintenance: uint
  }
)

;; Sensor readings data structure
(define-map sensor-readings
  {
    sensor-id: (string-ascii 32),
    timestamp: uint
  }
  {
    pollutant-type: (string-ascii 32),
    reading-value: uint,
    unit: (string-ascii 10),
    submitter: principal
  }
)

;; Track the latest readings for each sensor
(define-map latest-readings
  { sensor-id: (string-ascii 32) }
  {
    timestamp: uint,
    reading-value: uint
  }
)

;; Public function to register a new sensor
(define-public (register-sensor
    (sensor-id (string-ascii 32))
    (facility-id (string-ascii 32))
    (sensor-type (string-ascii 32))
    (location (string-ascii 100)))
  (let ((caller tx-sender))
    (if (is-eq caller (var-get admin))
      (if (map-insert sensors
            { sensor-id: sensor-id }
            {
              facility-id: facility-id,
              sensor-type: sensor-type,
              location: location,
              active: true,
              registration-date: block-height,
              last-maintenance: block-height
            })
        (ok true)
        (err u1))  ;; Error code 1: Sensor ID already exists
      (err u2))))  ;; Error code 2: Not authorized

;; Public function to submit sensor reading
(define-public (submit-reading
    (sensor-id (string-ascii 32))
    (pollutant-type (string-ascii 32))
    (reading-value uint)
    (unit (string-ascii 10)))
  (let ((caller tx-sender)
        (current-time block-height))
    (match (map-get? sensors { sensor-id: sensor-id })
      sensor (if (get active sensor)
              (begin
                ;; Store the reading
                (map-insert sensor-readings
                  {
                    sensor-id: sensor-id,
                    timestamp: current-time
                  }
                  {
                    pollutant-type: pollutant-type,
                    reading-value: reading-value,
                    unit: unit,
                    submitter: caller
                  })

                ;; Update latest reading
                (map-set latest-readings
                  { sensor-id: sensor-id }
                  {
                    timestamp: current-time,
                    reading-value: reading-value
                  })

                (ok true))
              (err u3))  ;; Error code 3: Sensor not active
      (err u4))))  ;; Error code 4: Sensor not found

;; Admin function to mark sensor maintenance
(define-public (record-maintenance (sensor-id (string-ascii 32)))
  (let ((caller tx-sender))
    (if (is-eq caller (var-get admin))
      (match (map-get? sensors { sensor-id: sensor-id })
        sensor (begin
          (map-set sensors
            { sensor-id: sensor-id }
            (merge sensor { last-maintenance: block-height }))
          (ok true))
        (err u4))  ;; Error code 4: Sensor not found
      (err u2))))  ;; Error code 2: Not authorized

;; Read-only function to get sensor details
(define-read-only (get-sensor (sensor-id (string-ascii 32)))
  (map-get? sensors { sensor-id: sensor-id }))

;; Read-only function to get a specific sensor reading
(define-read-only (get-reading (sensor-id (string-ascii 32)) (timestamp uint))
  (map-get? sensor-readings { sensor-id: sensor-id, timestamp: timestamp }))

;; Read-only function to get the latest reading for a sensor
(define-read-only (get-latest-reading (sensor-id (string-ascii 32)))
  (map-get? latest-readings { sensor-id: sensor-id }))

;; Admin function to transfer admin rights
(define-public (set-admin (new-admin principal))
  (let ((caller tx-sender))
    (if (is-eq caller (var-get admin))
      (begin
        (var-set admin new-admin)
        (ok true))
      (err u2))))  ;; Error code 2: Not authorized
