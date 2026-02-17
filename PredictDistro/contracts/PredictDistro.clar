;; contract title: predictive-token-distribution
;; This contract implements a comprehensive predictive model system for token distribution.
;; It combines user participation scores, global market factors, and staking mechanisms
;; to determine dynamic reward allocations.
;;
;; Key Features:
;; 1. Predictive Scoring: Users have a score (0-100) affecting their rewards.
;; 2. Global Market Factors: Trends and volatility influence distribution rates.
;; 3. Staking System: Users can stake tokens to boost their predictive power.
;; 4. Vesting Schedules: Rewards are vested over time to ensure long-term alignment.
;; 5. Simulation Engine: robust forecasting tool for potential scenarios.

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-registered (err u101))
(define-constant err-already-registered (err u102))
(define-constant err-invalid-score (err u103))
(define-constant err-insufficient-balance (err u104))
(define-constant err-nothing-to-claim (err u105))
(define-constant err-stake-locked (err u106))
(define-constant err-invalid-amount (err u107))

(define-constant prediction-period u100) ;; blocks per prediction period
(define-constant min-stake-amount u1000)
(define-constant stake-lock-period u500) ;; blocks to lock stake
(define-constant vesting-period u1000) ;; blocks for full vesting

;; data maps and vars

;; Stores the predictive score for each user (0-100)
(define-map user-prediction-scores principal uint)

;; Stores global market factors for a given period ID
;; period-id -> { trend-score, volatility-index }
(define-map global-market-factors uint {trend: uint, volatility: uint})

;; Tracks total tokens distributed to a user (lifetime)
(define-map distribution-history principal uint)

;; Staking Data: principal -> { amount, unlock-height, multiplier }
(define-map user-stakes principal {amount: uint, unlock-height: uint, multiplier: uint})

;; Vesting Data: principal -> { total-vested, claimed-amount, last-claim-height }
(define-map vesting-schedules principal {total-vested: uint, claimed-amount: uint, last-claim-height: uint})

(define-data-var total-distributed uint u0)
(define-data-var current-period-index uint u0)
(define-data-var total-staked uint u0)

;; private functions

;; Calculates the reward ratio based on user score, market trend, and stake multiplier
;; Formula: (user-score * market-trend * stake-multiplier) / (volatility + 1)
(define-private (calculate-reward-ratio (user-score uint) (market-trend uint) (volatility uint) (stake-mult uint))
  (let
    (
      (base-numerator (* user-score market-trend))
      (boosted-numerator (* base-numerator stake-mult))
      ;; Volatility acts as a dampener; higher volatility reduces rewards
      (denominator (+ volatility u1))
    )
    (/ boosted-numerator denominator)
  )
)

;; Gets market factors for the current period, defaults to neutral if not set
(define-private (get-current-factors)
  (default-to 
    {trend: u50, volatility: u10} 
    (map-get? global-market-factors (var-get current-period-index))
  )
)

;; Calculates the stake multiplier based on amount Staked
;; simple tier system: <1000 -> 1x, 1000-5000 -> 2x, >5000 -> 3x
(define-private (calculate-stake-multiplier (amount uint))
  (if (< amount min-stake-amount)
      u1
      (if (< amount u5000)
          u2
          u3
      )
  )
)

;; public functions

;; Registers a new participant with an initial predictive score
;; @param initial-score: The starting score for the user (0-100)
(define-public (register-participant (initial-score uint))
  (begin
    (asserts! (<= initial-score u100) err-invalid-score)
    (asserts! (is-none (map-get? user-prediction-scores tx-sender)) err-already-registered)
    (map-set user-prediction-scores tx-sender initial-score)
    ;; Initialize empty stake and existing maps if needed
    (map-set user-stakes tx-sender {amount: u0, unlock-height: u0, multiplier: u1})
    (map-set vesting-schedules tx-sender {total-vested: u0, claimed-amount: u0, last-claim-height: block-height})
    (ok true)
  )
)

;; Updates the global market factors for the current period (Owner only)
;; @param new-trend: 0-100 indicating market sentiment
;; @param new-volatility: 0-100 indicating market stability
(define-public (update-market-prediction (new-trend uint) (new-volatility uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set global-market-factors (var-get current-period-index) {trend: new-trend, volatility: new-volatility})
    (var-set current-period-index (+ (var-get current-period-index) u1))
    (ok true)
  )
)

;; Allows a user to stake tokens to increase their reward multiplier
;; @param amount: Amount of tokens to stake
(define-public (stake-tokens (amount uint))
  (let
    (
      (current-stake-data (default-to {amount: u0, unlock-height: u0, multiplier: u1} (map-get? user-stakes tx-sender)))
      (new-amount (+ (get amount current-stake-data) amount))
      (new-unlock (+ block-height stake-lock-period))
      (new-multiplier (calculate-stake-multiplier new-amount))
    )
    (asserts! (> amount u0) err-invalid-amount)
    ;; In a real contract: transfer tokens from user to contract here
    
    (map-set user-stakes tx-sender {amount: new-amount, unlock-height: new-unlock, multiplier: new-multiplier})
    (var-set total-staked (+ (var-get total-staked) amount))
    (ok new-amount)
  )
)

;; Allows a user to unstake tokens after the lock period has expired
;; @param amount: Amount to unstake
(define-public (unstake-tokens (amount uint))
  (let
    (
      (stake-data (unwrap! (map-get? user-stakes tx-sender) err-not-registered))
    )
    (asserts! (>= block-height (get unlock-height stake-data)) err-stake-locked)
    (asserts! (>= (get amount stake-data) amount) err-insufficient-balance)
    
    (let
      (
        (remaining-amount (- (get amount stake-data) amount))
        (new-multiplier (calculate-stake-multiplier remaining-amount))
      )
      ;; In a real contract: transfer tokens from contract to user here
      
      (map-set user-stakes tx-sender 
        (merge stake-data {amount: remaining-amount, multiplier: new-multiplier})
      )
      (var-set total-staked (- (var-get total-staked) amount))
      (ok remaining-amount)
    )
  )
)

;; Claims new rewards based on the predictive model and adds them to the vesting schedule
;; This doesn't payout immediately; it adds to the 'total-vested' balance
(define-public (claim-to-vesting)
  (let
    (
      (user-score (unwrap! (map-get? user-prediction-scores tx-sender) err-not-registered))
      (factors (get-current-factors))
      (stake-data (default-to {amount: u0, unlock-height: u0, multiplier: u1} (map-get? user-stakes tx-sender)))
      
      ;; Calculate instantaneous reward
      (reward-amount (calculate-reward-ratio user-score (get trend factors) (get volatility factors) (get multiplier stake-data)))
      
      (vesting-data (default-to {total-vested: u0, claimed-amount: u0, last-claim-height: block-height} (map-get? vesting-schedules tx-sender)))
    )
    (asserts! (> reward-amount u0) err-nothing-to-claim)
    
    ;; Update vesting schedule
    (map-set vesting-schedules tx-sender 
      (merge vesting-data {total-vested: (+ (get total-vested vesting-data) reward-amount)})
    )
    
    ;; Update global stats
    (map-set distribution-history tx-sender (+ (default-to u0 (map-get? distribution-history tx-sender)) reward-amount))
    (var-set total-distributed (+ (var-get total-distributed) reward-amount))
    
    (ok reward-amount)
  )
)

;; Releases vested tokens to the user wallet
;; Simple linear vesting logic for demonstration
(define-public (release-vested-tokens)
  (let
    (
      (vesting-data (unwrap! (map-get? vesting-schedules tx-sender) err-nothing-to-claim))
      (total (get total-vested vesting-data))
      (claimed (get claimed-amount vesting-data))
      (available (- total claimed))
    )
    (asserts! (> available u0) err-nothing-to-claim)
    ;; In a real implementation, we would calculate unlocked portion based on time
    ;; For this predictive model, we assume a simplified "all available are valid" for the sake of the example
    
    (map-set vesting-schedules tx-sender 
      (merge vesting-data {claimed-amount: total, last-claim-height: block-height})
    )
    ;; Transfer would happen here
    (ok available)
  )
)

;; Read-only function to get a full profile of a user
(define-read-only (get-user-full-profile (user principal))
  (let
    (
      (score (default-to u0 (map-get? user-prediction-scores user)))
      (stake (default-to {amount: u0, unlock-height: u0, multiplier: u1} (map-get? user-stakes user)))
      (vesting (default-to {total-vested: u0, claimed-amount: u0, last-claim-height: u0} (map-get? vesting-schedules user)))
      (history (default-to u0 (map-get? distribution-history user)))
    )
    {
      user: user,
      score: score,
      staked-amount: (get amount stake),
      stake-multiplier: (get multiplier stake),
      total-earned: history,
      vesting-balance: (- (get total-vested vesting) (get claimed-amount vesting))
    }
  )
)

;; Simulates a complex distribution scenario to forecast potential rewards
;; This function takes a hypothetical user, their potential score improvement,
;; a projected market trend, and a duration to simulate over.
;; It returns a forecast of total rewards under different volatility assumptions.
;;
;; This simulation is critical for the "Predictive" nature of the contract.
;; It helps users decide whether to stake more or improve their score.
(define-read-only (simulate-distribution-scenario 
    (user principal) 
    (projected-score-increase uint) 
    (market-trend-forecast uint)
    (simulation-duration uint)
    (include-staking-boost bool)
  )
  (let
    (
      ;; Fetch current user score or default to 0 if not registered
      (current-score (default-to u0 (map-get? user-prediction-scores user)))
      ;; Project the new score, capping at 100
      (projected-score (if (> (+ current-score projected-score-increase) u100)
                           u100
                           (+ current-score projected-score-increase)))
      
      ;; Determine the multiplier to use for simulation
      (current-stake-data (default-to {amount: u0, unlock-height: u0, multiplier: u1} (map-get? user-stakes user)))
      (base-multiplier (get multiplier current-stake-data))
      (simulated-multiplier (if include-staking-boost 
                                (if (< base-multiplier u3) (+ base-multiplier u1) u3) 
                                base-multiplier))

      ;; Define three volatility scenarios for the simulation:
      ;; 1. Optimistic: Low volatility (stable market) -> Higher rewards
      (optimistic-volatility u5)
      ;; 2. Neutral: Average volatility -> Moderate rewards
      (neutral-volatility u20)
      ;; 3. Pessimistic: High volatility (unstable market) -> Lower rewards
      (pessimistic-volatility u50)

      ;; Calculate the base reward for one period under each scenario
      (optimistic-reward (calculate-reward-ratio projected-score market-trend-forecast optimistic-volatility simulated-multiplier))
      (neutral-reward (calculate-reward-ratio projected-score market-trend-forecast neutral-volatility simulated-multiplier))
      (pessimistic-reward (calculate-reward-ratio projected-score market-trend-forecast pessimistic-volatility simulated-multiplier))

      ;; Extrapolate over the simulation duration (e.g., number of periods)
      (total-optimistic (* optimistic-reward simulation-duration))
      (total-neutral (* neutral-reward simulation-duration))
      (total-pessimistic (* pessimistic-reward simulation-duration))

      ;; Calculate a "confidence score" for the prediction based on the spread
      ;; A smaller spread between optimistic and pessimistic means higher confidence
      (spread (- total-optimistic total-pessimistic))
      (confidence-level (if (< spread u100) 
                            "High Accuracy" 
                            (if (< spread u500) "Medium Accuracy" "Low Accuracy")))
      
      ;; Advanced Analysis: ROI calculation
      ;; Estimate if the effort to increase score is worth it
      (efficiency-ratio (if (> projected-score-increase u0) 
                            (/ total-neutral projected-score-increase) 
                            u0))
    )
    ;; Return a detailed tuple with all forecast data
    (ok {
      user: user,
      input-params: {
        base-score: current-score,
        target-score: projected-score,
        boost-active: include-staking-boost,
        simulated-multiplier: simulated-multiplier
      },
      forecasts: {
        optimistic: total-optimistic,
        neutral: total-neutral,
        pessimistic: total-pessimistic
      },
      analysis: {
        spread: spread,
        confidence: confidence-level,
        market-assumption: market-trend-forecast,
        efficiency-score: efficiency-ratio
      },
      recommendation: (if (> total-neutral u1000) 
                          "Strong Buy/Engage" 
                          "Hold/Observe")
    })
  )
)

;; Helper to check system health (Read-Only)
(define-read-only (get-system-health)
    (let 
        (
            (total-dist (var-get total-distributed))
            (total-stk (var-get total-staked))
        )
        {
            distributed: total-dist,
            staked: total-stk,
            ratio: (if (> total-stk u0) (/ total-dist total-stk) u0)
        }
    )
)


