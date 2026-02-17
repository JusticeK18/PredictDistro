# PredictDistro

## Overview

I present **PredictDistro**, a sophisticated Clarity smart contract designed for the Stacks blockchain. This system implements a multi-faceted approach to decentralized tokenomics, blending user-specific behavioral metrics with macroeconomic market indicators. By utilizing a dynamic predictive scoring model, I have engineered a solution that moves beyond static distribution, rewarding users based on their engagement, stake, and the prevailing market environment.

The core philosophy of **PredictDistro** is "Adaptive Incentive Alignment." Through the use of a built-in simulation engine, users can forecast their potential earnings under varying degrees of market volatility, allowing for informed decision-making regarding staking and participation.

---

## Key System Architecture

### 1. Predictive Scoring Engine

I have implemented a scoring system where participants are assigned a value between  and . This score acts as the primary weight in the reward calculation, incentivizing users to maintain high-quality interactions within the ecosystem.

### 2. Global Market Integration

The contract owner can inject real-world or protocol-specific market factors, including:

* **Trend Score:** Reflects the general direction of the market (Bullish vs. Bearish).
* **Volatility Index:** Acts as a dampener. In my model, higher volatility increases the denominator, thereby reducing the distribution rate to protect the economy during unstable periods.

### 3. Tiered Staking Mechanism

To drive long-term value, I included a staking system with programmed lock-up periods. The reward multiplier is derived from the amount staked:

| Stake Amount () | Multiplier () |
| --- | --- |
|  |  |
|  |  |
|  |  |

### 4. Mathematical Foundation

The reward ratio () for any given period is determined by the following formula:

Where:

*  = User Prediction Score
*  = Market Trend Score
*  = Stake Multiplier
*  = Volatility Index

---

## Comprehensive Function Reference

### Private Functions

These internal methods handle the core logic and mathematical heavy lifting, ensuring that calculations remain consistent and protected from direct external manipulation.

* **`calculate-reward-ratio`**: This is the heart of the predictive model. It takes the user's score, current market trend, volatility, and stake multiplier to output a precise distribution unit. It uses a dampening algorithm where volatility () is incremented by  to prevent division-by-zero errors.
* **`get-current-factors`**: A safety-first retrieval function. It attempts to fetch the latest market data from the `global-market-factors` map. If the owner hasn't updated the data for the current period, I've designed it to default to a "neutral" state (Trend: , Volatility: ).
* **`calculate-stake-multiplier`**: Implements the tiered logic for capital commitment. It evaluates the raw `uint` amount of tokens staked and returns a multiplier of , , or .

### Public Functions

These functions represent the primary interface for users and the contract administrator. They alter the state of the blockchain and require transaction signing.

* **`register-participant`**: Entry point for new users. I have included checks to ensure a user cannot register twice (`err-already-registered`) and that their initial score is within the logical bounds of .
* **`update-market-prediction`**: An administrative-only function. It allows the `contract-owner` to push new market data and increment the `current-period-index`, effectively "moving time forward" for the distribution logic.
* **`stake-tokens`**: Allows users to commit capital. This function automatically recalculates the user's multiplier and resets the `unlock-height` to the current `block-height` plus the `stake-lock-period` ( blocks).
* **`unstake-tokens`**: A time-locked withdrawal function. It validates that the current block height has surpassed the user's specific `unlock-height` before allowing the removal of funds.
* **`claim-to-vesting`**: This does not payout immediately. Instead, it "snapshots" the user's earned rewards based on the current period's predictive metrics and adds them to a `total-vested` pool.
* **`release-vested-tokens`**: The final step in the reward lifecycle. It calculates the difference between `total-vested` and `claimed-amount` to transfer tokens directly to the user's wallet.

### Read-Only Functions

These functions are gas-less and provide essential data for front-end integrations and user strategy.

* **`get-user-full-profile`**: Returns a comprehensive tuple containing the user's score, staked amount, multiplier, total earned rewards, and their current claimable vesting balance.
* **`simulate-distribution-scenario`**: A sophisticated forecasting tool. It allows users to input "What If" parameters—such as "What if I increase my score by  points?" or "What if the market trend hits ?"—and returns an analysis of potential rewards across three volatility tiers.
* **`get-system-health`**: Provides a macro view of the contract, including total tokens distributed versus total tokens staked, yielding a "Distribution-to-Stake" ratio.

---

## Simulation & Forecasting

I believe transparency is paramount. The `simulate-distribution-scenario` function provides users with three distinct projections:

1. **Optimistic**: Based on low volatility ().
2. **Neutral**: Based on average volatility ().
3. **Pessimistic**: Based on high volatility ().

This allows for an **Efficiency Score** calculation, helping users determine if the "cost" of improving their score or increasing their stake provides a sufficient Return on Effort (ROE).

---

## Technical Specification & Constants

| Constant | Value | Description |
| --- | --- | --- |
| `prediction-period` | `u100` | Minimum blocks between periods |
| `min-stake-amount` | `u1000` | Floor for staking rewards |
| `stake-lock-period` | `u500` | Duration funds are illiquid |
| `vesting-period` | `u1000` | Full maturity window |

---

## Installation & Deployment

To deploy this contract to the Stacks testnet or mainnet, I recommend using the **Clarinet** framework.

```bash
# Clone the repository
git clone https://github.com/example/PredictDistro.git

# Navigate to the project
cd PredictDistro

# Check the contract for Clarity errors
clarinet check

# Run the test suite
clarinet test

```

---

## Contributing

I welcome contributions from the community. If you wish to enhance the predictive algorithms or the simulation engine:

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/AmazingFeature`).
3. Commit your changes.
4. Push to the branch.
5. Open a Pull Request.

Please ensure all new logic includes corresponding unit tests in the `tests/` directory.

---

## License

```text
MIT License

Copyright (c) 2026 PredictDistro Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

```

---
