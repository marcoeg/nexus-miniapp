// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
//  Nexus26 – ReputationManager (v1.0 – full implementation)
// -----------------------------------------------------------------------------
//  Tracks each predictor’s reputation score (0‑100) and provides a multiplier
//  used by markets to boost rewards.  Reputation is updated after every market
//  settlement via `addResult()` which must be called by authorised market
//  contracts (admin‑whitelisted).
//
//  Simple scoring logic (can be upgraded by replacing the contract through a
//  proxy later):
//      • Correct prediction  →  +5 points  + (oddsBucket)              (capped)
//      • Incorrect prediction → –3 points
//      • Score is bounded [0, 100]
// -----------------------------------------------------------------------------

import "../common/AccessControl.tact";
import "../libraries/ErrorCodes.tact";

// -----------------------------------------------------------------------------
//  Data structures
// -----------------------------------------------------------------------------
struct Reputation {
    uint8 score; // 0‑100
}

struct ReputationTier {
    uint8    minScore;
    uint8    maxScore;
    uint16   multiplier;     // 100 = 1.00x, 150 = 1.50x
    uint32   achievementId;  // 0 if none
}

struct Update {
    address user;
    bool    correct;
    uint128 stake;       // raw RIMET (9 dec)
    uint8   oddsBucket;  // 0‑255 discrete odds difficulty bucket
}

contract ReputationManager extends AccessControl {

    // ---------------------------------------------------------------------
    //  Storage
    // ---------------------------------------------------------------------
    mapping<address, uint8> _scores;           // user → score
    ReputationTier[]        _tiers;            // ordered ascending by minScore

    // Whitelisted market contracts → bool
    mapping<address, bool>  _markets;

    // ---------------------------------------------------------------------
    //  Events
    // ---------------------------------------------------------------------
    event ScoreChanged(address user, uint8 newScore);
    event TierAdded(uint8 min, uint8 max, uint16 mult, uint32 achId);
    event MarketWhitelisted(address market, bool status);

    // ---------------------------------------------------------------------
    //  Constructor – seeds default tiers
    // ---------------------------------------------------------------------
    constructor(address owner) public {
        _initAccessControl(owner);

        _tiers.push(ReputationTier(0,   30,  80,   0)); // 0‑30  → 0.8x
        _tiers.push(ReputationTier(31,  60, 100,   0)); // 31‑60 → 1.0x
        _tiers.push(ReputationTier(61,  85, 120,   2)); // 61‑85 → 1.2x (FOUNDING)
        _tiers.push(ReputationTier(86, 100, 150,   4)); // 86‑100→ 1.5x (LEGEND)
    }

    // ---------------------------------------------------------------------
    //  Admin functions
    // ---------------------------------------------------------------------
    external fn whitelistMarket(address market, bool status) onlyAdmin {
        _markets[market] = status;
        emit MarketWhitelisted(market, status);
    }

    /// @notice Add or overwrite a tier (ensure proper ordering off‑chain)
    external fn addTier(ReputationTier tier) onlyOwner {
        _tiers.push(tier);
        emit TierAdded(tier.minScore, tier.maxScore, tier.multiplier, tier.achievementId);
    }

    // ---------------------------------------------------------------------
    //  Market‑facing API
    // ---------------------------------------------------------------------
    external fn addResult(Update u) {
        require(_markets[msg.sender], ErrorCodes.ERR_UNAUTHORISED_CALLER);
        _updateScore(u);
    }

    // ---------------------------------------------------------------------
    //  Views
    // ---------------------------------------------------------------------
    get fn score(address user) returns (uint8) {
        return _scores[user];
    }

    get fn getMultiplier(address user) returns (uint16) {
        uint8 s = _scores[user];
        uint8 len = uint8(_tiers.length);
        for (uint8 i = 0; i < len; ++i) {
            ReputationTier t = _tiers[i];
            if (s >= t.minScore && s <= t.maxScore) {
                return t.multiplier;
            }
        }
        return 100; // fallback 1x
    }

    // ---------------------------------------------------------------------
    //  Internal scoring logic
    // ---------------------------------------------------------------------
    function _updateScore(Update u) private {
        uint8 current = _scores[u.user];
        uint8 newScore;
        if (u.correct) {
            uint8 add = uint8(5 + u.oddsBucket); // oddsBucket incentive
            newScore = current + add;
            if (newScore > 100) newScore = 100;
        } else {
            if (current > 3) {
                newScore = current - 3;
            } else {
                newScore = 0;
            }
        }
        if (newScore != current) {
            _scores[u.user] = newScore;
            emit ScoreChanged(u.user, newScore);
        }
    }
}
