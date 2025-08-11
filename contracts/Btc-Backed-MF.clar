(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_PARAMS (err u101))
(define-constant ERR_POLICY_NOT_FOUND (err u102))
(define-constant ERR_POLICY_EXPIRED (err u103))
(define-constant ERR_POLICY_ALREADY_CLAIMED (err u104))
(define-constant ERR_INSUFFICIENT_FUNDS (err u105))
(define-constant ERR_POLICY_NOT_ACTIVE (err u106))
(define-constant ERR_ORACLE_NOT_AUTHORIZED (err u107))
(define-constant ERR_WEATHER_DATA_NOT_FOUND (err u108))
(define-constant ERR_NO_CLAIM_CONDITIONS (err u109))
(define-constant ERR_POLICY_LIMIT_REACHED (err u110))
(define-constant ERR_POLICY_ALREADY_CANCELLED (err u111))
(define-constant ERR_POLICY_NOT_FOR_SALE (err u112))
(define-constant ERR_TRANSFER_TO_SELF (err u113))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u114))
(define-constant ERR_RISK_SCORE_NOT_FOUND (err u115))

(define-constant MIN_PREMIUM u1000000)
(define-constant MAX_PREMIUM u100000000)
(define-constant MIN_COVERAGE u5000000)
(define-constant MAX_COVERAGE u1000000000)
(define-constant MIN_DURATION u144)
(define-constant MAX_DURATION u52560)
(define-constant MAX_POLICIES_PER_USER u50)
(define-constant DROUGHT_THRESHOLD u10)
(define-constant FLOOD_THRESHOLD u200)
(define-constant BASE_RISK_SCORE u50)
(define-constant MAX_RISK_SCORE u100)
(define-constant RISK_ADJUSTMENT_FACTOR u10)

(define-data-var policy-counter uint u0)
(define-data-var total-premiums uint u0)
(define-data-var total-payouts uint u0)
(define-data-var total-policies uint u0)

(define-map policies uint {
    farmer: principal,
    premium: uint,
    coverage: uint,
    start-block: uint,
    end-block: uint,
    latitude: int,
    longitude: int,
    claimed: bool,
    cancelled: bool,
    active: bool
})

(define-map user-policy-count principal uint)

(define-map authorized-oracles principal bool)

(define-map weather-data {location-lat: int, location-lng: int, report-height: uint} {
    rainfall: uint,
    temperature: uint,
    oracle: principal,
    timestamp: uint
})

(define-map policy-transfers uint {
    seller: principal,
    asking-price: uint,
    active: bool
})

(define-map location-risk-scores {lat: int, lng: int} uint)

(define-map location-claim-history {lat: int, lng: int} {
    total-claims: uint,
    total-policies: uint,
    last-claim-height: uint
})

(define-read-only (get-policy (policy-id uint))
    (map-get? policies policy-id)
)

(define-read-only (get-user-policy-count (user principal))
    (default-to u0 (map-get? user-policy-count user))
)

(define-read-only (get-contract-stats)
    {
        total-policies: (var-get total-policies),
        total-premiums: (var-get total-premiums),
        total-payouts: (var-get total-payouts),
        contract-balance: (stx-get-balance (as-contract tx-sender))
    }
)

(define-read-only (is-oracle-authorized (oracle principal))
    (default-to false (map-get? authorized-oracles oracle))
)

(define-read-only (get-weather-data (lat int) (lng int) (report-height uint))
    (map-get? weather-data {location-lat: lat, location-lng: lng, report-height: report-height})
)

(define-read-only (get-policy-transfer (policy-id uint))
    (map-get? policy-transfers policy-id)
)

(define-read-only (is-policy-for-sale (policy-id uint))
    (match (map-get? policy-transfers policy-id)
        transfer (get active transfer)
        false
    )
)

(define-read-only (get-location-risk-score (lat int) (lng int))
    (default-to BASE_RISK_SCORE (map-get? location-risk-scores {lat: lat, lng: lng}))
)

(define-read-only (get-location-claim-history (lat int) (lng int))
    (default-to {total-claims: u0, total-policies: u0, last-claim-height: u0} 
                (map-get? location-claim-history {lat: lat, lng: lng}))
)

(define-read-only (calculate-risk-premium (base-premium uint) (lat int) (lng int))
    (let (
        (risk-score (get-location-risk-score lat lng))
        (adjustment (/ (* base-premium risk-score) u100))
    )
        (+ base-premium adjustment)
    )
)

(define-public (authorize-oracle (oracle principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (ok (map-set authorized-oracles oracle true))
    )
)

(define-public (revoke-oracle (oracle principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (ok (map-delete authorized-oracles oracle))
    )
)

(define-public (submit-weather-data (lat int) (lng int) (rainfall uint) (temperature uint))
    (begin
        (asserts! (is-oracle-authorized tx-sender) ERR_ORACLE_NOT_AUTHORIZED)
        (ok (map-set weather-data 
            {location-lat: lat, location-lng: lng, report-height: stacks-block-height}
            {rainfall: rainfall, temperature: temperature, oracle: tx-sender, timestamp: stacks-block-height}
        ))
    )
)

(define-public (create-policy (premium uint) (coverage uint) (duration uint) (lat int) (lng int))
    (let (
        (policy-id (+ (var-get policy-counter) u1))
        (user-policies (get-user-policy-count tx-sender))
        (start-block stacks-block-height)
        (end-block (+ stacks-block-height duration))
        (location-key {lat: lat, lng: lng})
        (current-history (get-location-claim-history lat lng))
    )
        (asserts! (and (>= premium MIN_PREMIUM) (<= premium MAX_PREMIUM)) ERR_INVALID_PARAMS)
        (asserts! (and (>= coverage MIN_COVERAGE) (<= coverage MAX_COVERAGE)) ERR_INVALID_PARAMS)
        (asserts! (and (>= duration MIN_DURATION) (<= duration MAX_DURATION)) ERR_INVALID_PARAMS)
        (asserts! (< user-policies MAX_POLICIES_PER_USER) ERR_POLICY_LIMIT_REACHED)
        
        (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
        
        (map-set policies policy-id {
            farmer: tx-sender,
            premium: premium,
            coverage: coverage,
            start-block: start-block,
            end-block: end-block,
            latitude: lat,
            longitude: lng,
            claimed: false,
            cancelled: false,
            active: true
        })
        
        (map-set location-claim-history location-key {
            total-claims: (get total-claims current-history),
            total-policies: (+ (get total-policies current-history) u1),
            last-claim-height: (get last-claim-height current-history)
        })
        
        (map-set user-policy-count tx-sender (+ user-policies u1))
        (var-set policy-counter policy-id)
        (var-set total-premiums (+ (var-get total-premiums) premium))
        (var-set total-policies (+ (var-get total-policies) u1))
        
        (ok policy-id)
    )
)

(define-public (cancel-policy (policy-id uint))
    (let (
        (policy (unwrap! (map-get? policies policy-id) ERR_POLICY_NOT_FOUND))
        (refund-amount (/ (get premium policy) u2))
    )
        (asserts! (is-eq tx-sender (get farmer policy)) ERR_UNAUTHORIZED)
        (asserts! (not (get cancelled policy)) ERR_POLICY_ALREADY_CANCELLED)
        (asserts! (not (get claimed policy)) ERR_POLICY_ALREADY_CLAIMED)
        (asserts! (< stacks-block-height (get start-block policy)) ERR_POLICY_NOT_ACTIVE)
        
        (try! (as-contract (stx-transfer? refund-amount tx-sender (get farmer policy))))
        
        (map-set policies policy-id (merge policy {cancelled: true, active: false}))
        
        (ok refund-amount)
    )
)

(define-public (claim-payout (policy-id uint))
    (let (
        (policy (unwrap! (map-get? policies policy-id) ERR_POLICY_NOT_FOUND))
        (weather (unwrap! (get-weather-data (get latitude policy) (get longitude policy) stacks-block-height) ERR_WEATHER_DATA_NOT_FOUND))
        (rainfall (get rainfall weather))
        (location-key {lat: (get latitude policy), lng: (get longitude policy)})
        (current-history (get-location-claim-history (get latitude policy) (get longitude policy)))
    )
        (asserts! (is-eq tx-sender (get farmer policy)) ERR_UNAUTHORIZED)
        (asserts! (get active policy) ERR_POLICY_NOT_ACTIVE)
        (asserts! (not (get claimed policy)) ERR_POLICY_ALREADY_CLAIMED)
        (asserts! (not (get cancelled policy)) ERR_POLICY_ALREADY_CANCELLED)
        (asserts! (>= stacks-block-height (get start-block policy)) ERR_POLICY_NOT_ACTIVE)
        (asserts! (<= stacks-block-height (get end-block policy)) ERR_POLICY_EXPIRED)
        (asserts! (or (<= rainfall DROUGHT_THRESHOLD) (>= rainfall FLOOD_THRESHOLD)) ERR_NO_CLAIM_CONDITIONS)
        
        (try! (as-contract (stx-transfer? (get coverage policy) tx-sender (get farmer policy))))
        
        (map-set policies policy-id (merge policy {claimed: true, active: false}))
        (map-set location-claim-history location-key {
            total-claims: (+ (get total-claims current-history) u1),
            total-policies: (get total-policies current-history),
            last-claim-height: stacks-block-height
        })
        (var-set total-payouts (+ (var-get total-payouts) (get coverage policy)))
        
        (ok (get coverage policy))
    )
)

(define-public (emergency-withdraw (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (try! (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER)))
        (ok amount)
    )
)

(define-public (fund-contract (amount uint))
    (begin
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (ok amount)
    )
)

(define-public (list-policy-for-sale (policy-id uint) (asking-price uint))
    (let (
        (policy (unwrap! (map-get? policies policy-id) ERR_POLICY_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get farmer policy)) ERR_UNAUTHORIZED)
        (asserts! (get active policy) ERR_POLICY_NOT_ACTIVE)
        (asserts! (not (get claimed policy)) ERR_POLICY_ALREADY_CLAIMED)
        (asserts! (not (get cancelled policy)) ERR_POLICY_ALREADY_CANCELLED)
        (asserts! (> asking-price u0) ERR_INVALID_PARAMS)
        
        (map-set policy-transfers policy-id {
            seller: tx-sender,
            asking-price: asking-price,
            active: true
        })
        
        (ok true)
    )
)

(define-public (cancel-policy-sale (policy-id uint))
    (let (
        (policy (unwrap! (map-get? policies policy-id) ERR_POLICY_NOT_FOUND))
        (transfer (unwrap! (map-get? policy-transfers policy-id) ERR_POLICY_NOT_FOR_SALE))
    )
        (asserts! (is-eq tx-sender (get seller transfer)) ERR_UNAUTHORIZED)
        (asserts! (get active transfer) ERR_POLICY_NOT_FOR_SALE)
        
        (map-set policy-transfers policy-id (merge transfer {active: false}))
        
        (ok true)
    )
)

(define-public (purchase-policy (policy-id uint))
    (let (
        (policy (unwrap! (map-get? policies policy-id) ERR_POLICY_NOT_FOUND))
        (transfer (unwrap! (map-get? policy-transfers policy-id) ERR_POLICY_NOT_FOR_SALE))
        (seller (get seller transfer))
        (asking-price (get asking-price transfer))
        (current-user-policies (get-user-policy-count tx-sender))
    )
        (asserts! (get active transfer) ERR_POLICY_NOT_FOR_SALE)
        (asserts! (not (is-eq tx-sender seller)) ERR_TRANSFER_TO_SELF)
        (asserts! (< current-user-policies MAX_POLICIES_PER_USER) ERR_POLICY_LIMIT_REACHED)
        (asserts! (get active policy) ERR_POLICY_NOT_ACTIVE)
        (asserts! (not (get claimed policy)) ERR_POLICY_ALREADY_CLAIMED)
        (asserts! (not (get cancelled policy)) ERR_POLICY_ALREADY_CANCELLED)
        
        (try! (stx-transfer? asking-price tx-sender seller))
        
        (map-set policies policy-id (merge policy {farmer: tx-sender}))
        (map-set policy-transfers policy-id (merge transfer {active: false}))
        
        (let (
            (seller-policy-count (get-user-policy-count seller))
            (buyer-policy-count (get-user-policy-count tx-sender))
        )
            (map-set user-policy-count seller (- seller-policy-count u1))
            (map-set user-policy-count tx-sender (+ buyer-policy-count u1))
        )
        
        (ok policy-id)
    )
)

(define-public (update-location-risk-score (lat int) (lng int) (risk-score uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (<= risk-score MAX_RISK_SCORE) ERR_INVALID_PARAMS)
        (ok (map-set location-risk-scores {lat: lat, lng: lng} risk-score))
    )
)

(define-public (auto-update-risk-score (lat int) (lng int))
    (let (
        (history (get-location-claim-history lat lng))
        (location-policies (get total-policies history))
        (location-claims (get total-claims history))
        (claim-rate (if (> location-policies u0) (/ (* location-claims u100) location-policies) u0))
        (new-risk-score (+ BASE_RISK_SCORE (/ (* claim-rate RISK_ADJUSTMENT_FACTOR) u10)))
        (final-risk-score (if (> new-risk-score MAX_RISK_SCORE) MAX_RISK_SCORE new-risk-score))
    )
        (asserts! (> location-policies u5) ERR_INVALID_PARAMS)
        (ok (map-set location-risk-scores {lat: lat, lng: lng} final-risk-score))
    )
)

