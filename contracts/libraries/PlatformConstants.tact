// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
//  Nexus26 – PlatformConstants Library
//  Holds compile‑time constants used by multiple contracts.
// -----------------------------------------------------------------------------

library PlatformConstants {
    // -------------------------------------------------------------------------
    //  Fee configuration (basis points – 1 BPS = 0.01 %)
    // -------------------------------------------------------------------------
    const uint16 PLATFORM_FEE_BPS       = 300;   // 3 % default fee
    const uint16 MAX_FEE_BPS           = 500;   // hard cap: 5 %
    const uint16 BONUS_MULT_CAP        = 300;   // 3× max combined multiplier

    // -------------------------------------------------------------------------
    //  Conviction staking bounds (expressed in nano‑RIMET = 1e‑9)
    // -------------------------------------------------------------------------
    const uint128 MIN_PREDICTION_RIMET = 50  * 1_000_000_000;   //  50 $RIMET
    const uint128 MAX_PREDICTION_RIMET = 250 * 1_000_000_000;   // 250 $RIMET

    // -------------------------------------------------------------------------
    //  Circuit‑breaker default thresholds
    // -------------------------------------------------------------------------
    const uint128 DEFAULT_USER_LIMIT_RIMET   = 10_000  * 1_000_000_000; // 10 K $RIMET
    const uint128 DEFAULT_MARKET_LIMIT_RIMET = 1_000_000 * 1_000_000_000; // 1 M $RIMET

    // -------------------------------------------------------------------------
    //  Match auto‑close timing
    // -------------------------------------------------------------------------
    const uint32 DEFAULT_CLOSE_BEFORE_SEC = 15 * 60; // 15 minutes in seconds
}
