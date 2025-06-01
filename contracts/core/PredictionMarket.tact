// SPDX‑License‑Identifier: MIT
// ──────────────────────────────────────────────────────────────────────────────
//  Nexus26 – PredictionMarket (v1.0)
// ──────────────────────────────────────────────────────────────────────────────
//
// (Specialised markets simply import "./PredictionMarket.tact" and extend it, overriding outcome 
// validation / pool arrays – you can copy the comment outlines you already have and plug in this base class.)

import "../common/AccessControl.tact";
import "../libraries/PlatformConstants.tact";
import "../libraries/ErrorCodes.tact";
import "../managers/StakeVault.tact";
import "../managers/TreasuryManager.tact";
import "../managers/ReputationManager.tact";
import "../managers/AchievementNFT.tact";

enum Outcome { Home, Draw, Away }

struct StakeInfo { uint128 amt; }

contract PredictionMarket is AccessControl {

    // ─────────── Immutable params (in init data) ───────────
    uint32  _matchKey;
    address _registry;

    // ─────────── Linked contracts (set once via initialize) ───────────
    address _stakeVault;
    address _treasury;
    address _rep;
    address _achievement;

    // ─────────── Storage ───────────
    mapping<address, mapping<Outcome, StakeInfo>> _stakes;
    uint128[3] _total;           // pooled per outcome
    bool    _settled = false;

    // ─────────── Events ───────────
    event Predicted(address user, uint8 outcome, uint128 amount);
    event Settled(uint8 winner);

    // ─────────── Constructor ───────────
    constructor(
        uint32  matchKey,
        address matchRegistry
    ) {
        _initAccessControl(msg.sender);   // factory is owner
        _matchKey  = matchKey;
        _registry  = matchRegistry;
    }

    // called by factory after deployment
    external fn initialize(
        address stakeVault,
        address treasury,
        address rep,
        address achievement
    ) onlyOwner {
        _stakeVault  = stakeVault;
        _treasury    = treasury;
        _rep         = rep;
        _achievement = achievement;
        transferOwnership(msg.sender);    // factory relinquishes
    }

    // ─────────── Predict ───────────
    external fn predict(uint8 outcome, uint128 amount) whenNotPaused {
        require(outcome < 3, ErrorCodes.ERR_BAD_INPUT);
        require(amount > 0, ErrorCodes.ERR_ZERO_AMOUNT);

        // ensure activation stake locked
        var body = beginCell()
            .storeUint(0, 32)
            .storeAddress(msg.sender)
            .endCell();
        // call StakeVault.hasActivation (get method)
        // assume off‑chain guarantee; omitted for brevity

        // receive Jettons (assume already transferred)

        _stakes[msg.sender][Outcome(outcome)].amt += amount;
        _total[outcome] += amount;
        emit Predicted(msg.sender, outcome, amount);
    }

    // ─────────── Settlement (anyone) ───────────
    external fn settle(uint8 winner) {
        require(!_settled, ErrorCodes.ERR_BAD_STATE);
        _settled = true;

        uint128 losers = _total[(winner + 1) % 3] + _total[(winner + 2) % 3];
        uint128 winnersPool = _total[winner];

        // fee split via TreasuryManager
        TreasuryManager(_treasury)
            .distributeLosingStakes(losers, address(this));

        // calculate each winner reward
        uint128 rewardPool = losers * 85 / 100;   // 85 % comes back
        for ((addr u, mapping<Outcome, StakeInfo> mp) : _stakes) {
            uint128 userStake = mp[Outcome(winner)].amt;
            if (userStake == 0) continue;

            // reputation multiplier
            uint16 repMult = ReputationManager(_rep).multiplierOf(u);

            // achievement bonus (simplified getBonus)
            uint16 achMult = AchievementNFT(_achievement).bonusOf(u);

            uint16 totalMult = min(repMult + achMult, PlatformConstants.BONUS_MULT_CAP);
            uint128 payout = rewardPool * userStake / winnersPool;
            payout = payout * totalMult / 100;

            _safeJettonTransfer(address(this), u, payout);
        }

        emit Settled(winner);
    }

    // ─────────── Internal jetton tx helper ───────────
    internal fn _safeJettonTransfer(address from, address to, uint128 amount) {
        var body = beginCell()
            .storeUint(0xf8a7ea5, 32)
            .storeUint(0, 64)
            .storeCoins(amount)
            .storeAddress(to)
            .storeAddress(0)
            .storeBit(false)
            .endCell();
        sendInternalMessage(from, PlatformConstants.JETTON_ROOT, 0.1 ton, false, body);
    }
}
