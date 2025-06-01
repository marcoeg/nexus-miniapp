// SPDX‑License‑Identifier: MIT
// ──────────────────────────────────────────────────────────────────────────────
//  Nexus26 – PlayerPerformanceMarket
//  Two‑outcome market forecasting whether a player will hit / exceed a stat
//  threshold (goals, assists, cards).
//        0 = FAIL (below threshold)
//        1 = ACHIEVE (≥ threshold)
// ──────────────────────────────────────────────────────────────────────────────
import "./PredictionMarket.tact";

contract PlayerPerformanceMarket is PredictionMarket {

    uint32 _playerId;
    uint8  _statType;     // 0=goals,1=assists,2=cards
    uint8  _threshold;

    constructor(
        uint32  matchKey,
        address matchRegistry,
        uint32  playerId,
        uint8   statType,
        uint8   threshold
    ) : PredictionMarket(matchKey, matchRegistry) {
        _playerId  = playerId;
        _statType  = statType;
        _threshold = threshold;
    }

    uint128[2] _totals;

    external override fn predict(uint8 outcome, uint128 amount) whenNotPaused {
        require(outcome < 2, ErrorCodes.ERR_BAD_INPUT);
        require(amount > 0, ErrorCodes.ERR_ZERO_AMOUNT);

        _stakes[msg.sender][Outcome(outcome)].amt += amount;
        _totals[outcome] += amount;
        emit Predicted(msg.sender, outcome, amount);
    }

    external override fn settle(uint8 winner) {
        require(!_settled, ErrorCodes.ERR_BAD_STATE);
        require(winner < 2, ErrorCodes.ERR_BAD_INPUT);
        _settled = true;

        uint128 losers = _totals[1 - winner];
        uint128 winnersTotal = _totals[winner];

        TreasuryManager(_treasury)
            .distributeLosingStakes(losers, address(this));

        uint128 rewardPool = losers * 85 / 100;
        for ((addr u, mapping<Outcome, StakeInfo> mp) : _stakes) {
            uint128 userStake = mp[Outcome(winner)].amt;
            if (userStake == 0) continue;

            uint16 mult = ReputationManager(_rep).multiplierOf(u)
                          + AchievementNFT(_achievement).bonusOf(u);
            if (mult > PlatformConstants.BONUS_MULT_CAP)
                mult = PlatformConstants.BONUS_MULT_CAP;

            uint128 payout = rewardPool * userStake / winnersTotal;
            payout = payout * mult / 100;
            _safeJettonTransfer(address(this), u, payout);
        }
        emit Settled(winner);
    }

    // views
    get fn playerId() returns (uint32) { return _playerId; }
    get fn statType() returns (uint8)  { return _statType;  }
    get fn threshold() returns (uint8) { return _threshold; }
}
