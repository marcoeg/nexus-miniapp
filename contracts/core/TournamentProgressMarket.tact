// SPDX‑License‑Identifier: MIT
// ──────────────────────────────────────────────────────────────────────────────
//  Nexus26 – TournamentProgressMarket
//  Two‑outcome market predicting whether a team finishes a specific bracket
//  position (e.g., reach Semi‑Final).
//        0 = NO  (team eliminated earlier)
//        1 = YES (team reaches / surpasses target round)
// ──────────────────────────────────────────────────────────────────────────────
import "./PredictionMarket.tact";

contract TournamentProgressMarket is PredictionMarket {

    uint8 _round;       // 1=R16,2=QF,3=SF,4=F
    uint8 _position;    // e.g., 1=Winner,2=Runner‑up

    constructor(
        uint32  matchKey,
        address matchRegistry,
        uint8   round,
        uint8   position
    ) : PredictionMarket(matchKey, matchRegistry) {
        _round    = round;
        _position = position;
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

        uint128 losersPool = _totals[1 - winner];
        uint128 winnersTot = _totals[winner];

        TreasuryManager(_treasury)
            .distributeLosingStakes(losersPool, address(this));

        uint128 rewardPool = losersPool * 85 / 100;
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

    get fn round() returns (uint8)    { return _round;    }
    get fn position() returns (uint8) { return _position; }
}
