// SPDX‑License‑Identifier: MIT
// ──────────────────────────────────────────────────────────────────────────────
//  Nexus26 – OverUnderMarket
//  Total‑goals market with two outcomes:
//        0 = UNDER  (total goals < threshold)
//        1 = OVER   (total goals ≥ threshold)
// ──────────────────────────────────────────────────────────────────────────────
import "./PredictionMarket.tact";

contract OverUnderMarket is PredictionMarket {

    // Immutable game‑specific parameter
    uint8 _threshold;

    constructor(
        uint32  matchKey,
        address matchRegistry,
        uint8   threshold
    ) : PredictionMarket(matchKey, matchRegistry) {
        _threshold = threshold;
    }

    // Override for two‑outcome array
    uint128[2] _ouTotals;

    // ------------- Prediction override -------------
    external override fn predict(uint8 outcome, uint128 amount) whenNotPaused {
        require(outcome < 2, ErrorCodes.ERR_BAD_INPUT);
        require(amount > 0, ErrorCodes.ERR_ZERO_AMOUNT);

        _stakes[msg.sender][Outcome(outcome)].amt += amount;
        _ouTotals[outcome] += amount;
        emit Predicted(msg.sender, outcome, amount);
    }

    // ------------- Settlement override -------------
    external override fn settle(uint8 winner) {
        require(!_settled, ErrorCodes.ERR_BAD_STATE);
        require(winner < 2, ErrorCodes.ERR_BAD_INPUT);
        _settled = true;

        uint128 losersPool = _ouTotals[1 - winner];
        uint128 winnersTot = _ouTotals[winner];

        TreasuryManager(_treasury)
            .distributeLosingStakes(losersPool, address(this));

        uint128 rewardPool = losersPool * 85 / 100;   // 85 %
        for ((addr u, mapping<Outcome, StakeInfo> mp) : _stakes) {
            uint128 stakeAmt = mp[Outcome(winner)].amt;
            if (stakeAmt == 0) continue;

            uint16 mult = ReputationManager(_rep).multiplierOf(u)
                          + AchievementNFT(_achievement).bonusOf(u);
            if (mult > PlatformConstants.BONUS_MULT_CAP)
                mult = PlatformConstants.BONUS_MULT_CAP;

            uint128 payout = rewardPool * stakeAmt / winnersTot;
            payout = payout * mult / 100;
            _safeJettonTransfer(address(this), u, payout);
        }
        emit Settled(winner);
    }

    // view helper
    get fn threshold() returns (uint8) { return _threshold; }
}
