// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
//  Nexus26 – ErrorCodes Library
//  Centralised error identifiers for require/assert statements across the
//  Nexus26 smart‑contract suite.
//  -----------------------------------------------------------------------------

library ErrorCodes {
    // -------------------------------------------------------------------------
    //  Generic
    // -------------------------------------------------------------------------
    uint16 constant ERR_NOT_OWNER            = 100; // caller is not contract owner
    uint16 constant ERR_NOT_ADMIN            = 101; // caller lacks admin role
    uint16 constant ERR_PAUSED               = 102; // contract or market paused

    // -------------------------------------------------------------------------
    //  Prediction / Stake constraints
    // -------------------------------------------------------------------------
    uint16 constant ERR_BELOW_MIN_STAKE      = 300; // stake below minimum
    uint16 constant ERR_ABOVE_MAX_STAKE      = 301; // stake above maximum
    uint16 constant ERR_TOO_MANY_ACTIVE      = 302; // user exceeded active limits
    uint16 constant ERR_MARKET_CLOSED        = 303; // predictions closed
    uint16 constant ERR_MARKET_SETTLED       = 304; // cannot predict after settle

    // -------------------------------------------------------------------------
    //  Liquidity / Treasury / Fees
    // -------------------------------------------------------------------------
    uint16 constant ERR_FEE_TOO_HIGH         = 400; // fee exceeds MAX_FEE_BPS
    uint16 constant ERR_LIQUIDITY_LIMIT      = 401; // liquidity limit exceeded

    // -------------------------------------------------------------------------
    //  Oracle / Result submission
    // -------------------------------------------------------------------------
    uint16 constant ERR_UNAUTHORISED_ORACLE  = 500; // oracle not whitelisted
    uint16 constant ERR_ALREADY_FINALISED    = 501; // result already finalised
    uint16 constant ERR_INSUFFICIENT_VOTES   = 502; // not enough oracle votes

    // -------------------------------------------------------------------------
    //  Emergency Controls
    // -------------------------------------------------------------------------
    uint16 constant ERR_WITHDRAW_ONLY        = 600; // withdraw‑only mode active
    uint16 constant ERR_EMERGENCY_COOLDOWN   = 601; // cooldown period active
}
