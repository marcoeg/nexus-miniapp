// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
//  Nexus26 – PointsRegistry (v1.0 – full implementation)
// -----------------------------------------------------------------------------
//  Handles pre‑token engagement points.  Points are **non‑transferable** and
//  will convert 1‑for‑1 into $RIMET Jettons once the token launches via
//  `enableConversion()` → `convertToTokens()`.
//
//  Key features
//  ============
//  • Premium enrolment (one‑time 2 TON fee) – only premium users receive weekly
//    airdrops.
//  • Weekly allocation: admin supplies a batch list of recipients and each gets
//    1 000 points.
//  • Conviction staking: `recordPrediction()` burns points (50‑250) and opens an
//    active‑prediction slot (max 5).
//  • Slot release: `releasePredictionSlot()` called by markets when a position
//    settles.
//  • Token conversion: after owner enables, users can exchange all remaining
//    points for $RIMET Jettons.
// -----------------------------------------------------------------------------

import "../common/AccessControl.tact";
import "../libraries/PlatformConstants.tact";
import "../libraries/ErrorCodes.tact";

// Helper struct – mimics Amount used by markets but here we store raw points
struct PAmount {
    uint128 pts;
}

contract PointsRegistry extends AccessControl {

    // ---------------------------------------------------------------------
    //  Constants & storage
    // ---------------------------------------------------------------------
    uint128 constant PREMIUM_FEE_TON   = 2;             // 2 TON – value check
    uint128 constant WEEKLY_ALLOCATION = 1_000 * 10**9; // 1 000 points (9 dec)

    // points balance per user
    mapping<address, uint128> _points;
    // premium flag
    mapping<address, bool> _premium;
    // active prediction counters (max 5)
    mapping<address, uint8> _activePredictions;

    // conversion toggle & token root
    bool    _conversionEnabled = false;
    address _rimetRoot;

    // ------------------------------------------------------------------
    //  Events (Ton event id 0, simple payload)
    // ------------------------------------------------------------------
    event PremiumRegistered(address user);
    event WeeklyPointsAllocated(uint32 batchLen, uint128 totalPts);
    event PredictionRecorded(address user, uint128 burned);
    event PointsConverted(address user, uint128 pts);
    event PredictionSlotReleased(address user);

    // ------------------------------------------------------------------
    //  Constructor
    // ------------------------------------------------------------------
    constructor(address owner, address rimetRoot) public {
        _initAccessControl(owner);
        _rimetRoot = rimetRoot;
    }

    // ------------------------------------------------------------------
    //  Modifiers / internal helpers
    // ------------------------------------------------------------------
    modifier onlyPremium() {
        require(_premium[msg.sender], ErrorCodes.ERR_NOT_PREMIUM);
        _;
    }

    function _min(uint128 a, uint128 b) private pure returns (uint128) {
        return a < b ? a : b;
    }

    // ------------------------------------------------------------------
    //  External API
    // ------------------------------------------------------------------

    /// @notice One‑time premium registration (costs 2 TON)
    external fn registerPremium() payable {
        require(!_premium[msg.sender], ErrorCodes.ERR_ALREADY_PREMIUM);
        require(msg.value >= PREMIUM_FEE_TON, ErrorCodes.ERR_INSUFFICIENT_TON);
        _premium[msg.sender] = true;
        _points[msg.sender] += WEEKLY_ALLOCATION; // sign‑up bonus
        emit PremiumRegistered(msg.sender);

        // forward TON to owner/treasury (bounce‑safe)
        owner.transfer(msg.value, false);
    }

    /// @notice Admin batch weekly allocation (gas‑optimised: recipients array)
    external fn allocateWeeklyPoints(address[] recipients) onlyAdmin {
        uint32 len = uint32(recipients.length);
        uint128 total;
        for (uint32 i = 0; i < len; ++i) {
            address user = recipients[i];
            if (_premium[user]) {
                _points[user] += WEEKLY_ALLOCATION;
                total += WEEKLY_ALLOCATION;
            }
        }
        emit WeeklyPointsAllocated(len, total);
    }

    /// @notice Record a new prediction, burning points as conviction stake.
    /// @dev    Called by whitelisted market contracts (admin‑controlled).
    external fn recordPrediction(address user, PAmount stake) onlyAdmin {
        require(stake.pts >= PlatformConstants.MIN_PREDICTION, ErrorCodes.ERR_BELOW_MIN);
        require(stake.pts <= PlatformConstants.MAX_PREDICTION, ErrorCodes.ERR_ABOVE_MAX);
        require(_points[user] >= stake.pts, ErrorCodes.ERR_INSUFFICIENT_POINTS);
        require(_activePredictions[user] < PlatformConstants.MAX_ACTIVE_PREDICTIONS,
                ErrorCodes.ERR_TOO_MANY_ACTIVE);

        _points[user] -= stake.pts;
        _activePredictions[user] += 1;
        emit PredictionRecorded(user, stake.pts);
    }

    /// @notice Market calls when a prediction settles to free one active slot.
    external fn releasePredictionSlot(address user) onlyAdmin {
        if (_activePredictions[user] > 0) {
            _activePredictions[user] -= 1;
            emit PredictionSlotReleased(user);
        }
    }

    /// @notice Owner enables one‑time conversion once $RIMET is live.
    external fn enableConversion() onlyOwner {
        _conversionEnabled = true;
    }

    /// @notice Users burn all remaining points and receive an equivalent
    ///         amount of $RIMET Jettons minted to their wallet.
    external fn convertToTokens() {
        require(_conversionEnabled, ErrorCodes.ERR_CONVERSION_DISABLED);
        uint128 bal = _points[msg.sender];
        require(bal > 0, ErrorCodes.ERR_ZERO_BALANCE);
        _points[msg.sender] = 0;
        emit PointsConverted(msg.sender, bal);

        // Mint Jettons from root (simplified).  Assumes caller wallet exists.
        TvmCell body = buildMintBody(msg.sender, bal);
        _rimetRoot.transfer({value: 0, flag: 1, bounce: true, body});
    }

    // ------------------------------------------------------------------
    //  Views
    // ------------------------------------------------------------------
    get fn pointsOf(address user) returns (uint128) {
        return _points[user];
    }

    get fn activePredictionsOf(address user) returns (uint8) {
        return _activePredictions[user];
    }

    get fn isPremium(address user) returns (bool) {
        return _premium[user];
    }

    // ------------------------------------------------------------------
    //  Internal Jetton mint helper (simplified placeholder)
    // ------------------------------------------------------------------
    function buildMintBody(address to, uint128 amount) private pure returns (TvmCell) {
        // op 0x40 (mint) – tailor to actual Jetton Root interface at integration time
        TvmBuilder b;
        b.store(uint32(0x40));
        b.store(amount);
        b.store(to);
        return b.toCell();
    }
}
