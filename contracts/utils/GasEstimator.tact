// SPDX‑License‑Identifier: MIT
// ──────────────────────────────────────────────────────────────────────────────
//  Nexus26 – GasEstimator
//  Pure “view” helper providing rough TON‑gas estimates for UI/front‑end.
// ──────────────────────────────────────────────────────────────────────────────
library GasEstimator {

    /// Gas to call PredictionMarket.predict(outcome,amount)
    get fn estimatePredictionGas(uint8 numOutcomes) returns (uint128) {
        // Base 0.08 + 0.02 per additional outcome (ton)
        return 0.08 ton + (numOutcomes - 2) * 0.02 ton;
    }

    /// Gas to settle n winner addresses (linear)
    get fn estimateSettlementGas(uint32 numWinners) returns (uint128) {
        return 0.15 ton + numWinners * 0.03 ton;
    }
}
