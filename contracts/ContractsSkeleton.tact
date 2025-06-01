// -----------------------------------------------------------------------------
//  Nexus26 – 2026 FIFA World Cup Prediction Platform (TON)
//  Tact Contract Skeletons – v0.7 (interfaces only – NO business logic)
//  -----------------------------------------------------------------------------
//  Changelog (2025‑05‑31 – v0.7)
//     • Integrated ALL requested critical fixes & enhancements:
//           ‑ PointsRegistry stake validation + releasePredictionSlot + events
//           ‑ StakeVault emergencyUnlock / position counters + event
//           ‑ MarketFactory multi‑type deployment
//           ‑ PredictionMarket extra state refs + initialize()
//           ‑ OracleCoordinator _finalResults map + internal _finalize()
//           ‑ LiquidityManager per‑user‑per‑market map with view
//           ‑ AchievementNFT default criteria seeded in constructor
//           ‑ BatchOperations MAX_BATCH_SIZE + safety checks
//           ‑ Added ErrorCodes lib for unified error numbers
//     • No placeholders remain – every contract stub is self‑contained.
// -----------------------------------------------------------------------------

// ============================= 0. Shared Types & Constants ====================

struct MatchKey      { uint32 id; }
struct Outcome       { uint8 code; }  // 0 = Home, 1 = Draw, 2 = Away
struct Result        { Outcome winner; }
struct Amount        { uint128 rimet; }
struct Reputation    { uint8 score; }

library ErrorCodes {
    const uint16 NOT_OWNER        = 100;
    const uint16 NOT_ADMIN        = 101;
    const uint16 PAUSED           = 200;
    const uint16 BELOW_MIN        = 300;
    const uint16 ABOVE_MAX        = 301;
    const uint16 TOO_MANY_ACTIVE  = 302;
    const uint16 BATCH_TOO_LARGE  = 400;
}

library PlatformConstants {
    // Fees
    const uint16 PLATFORM_FEE_BPS = 300;  // default 3 %
    const uint16 MAX_FEE_BPS      = 500;  // 5 % cap
    const uint16 BURN_BPS         = 1000; // 10 %
    const uint16 TREASURY_BPS     = 500;  // 5 %

    // Conviction staking
    const uint128 MIN_PREDICTION  =  50  * 10^9;
    const uint128 MAX_PREDICTION  = 250  * 10^9;
    const uint16  CONV_LOW_MULT   = 120;
    const uint16  CONV_MED_MULT   = 150;
    const uint16  CONV_HIGH_MULT  = 200;

    // Bonus multipliers & cap
    const uint16 BONUS_PERFECT_GROUP  = 110;
    const uint16 BONUS_STREAK_MAX     = 125;
    const uint16 BONUS_BRACKET_MASTER = 150;
    const uint16 BONUS_MULT_CAP       = 300;

    // Circuit‑breakers
    const uint128 DEFAULT_USER_LIMIT   =  10_000   * 10^9;
    const uint128 DEFAULT_MARKET_LIMIT = 1_000_000 * 10^9;
    const uint128 WHALE_USER_LIMIT     =  50_000   * 10^9;

    // Timing (seconds before kickoff to auto‑close)
    const uint32 CLOSE_GROUP_SEC  =  15 * 60;
    const uint32 CLOSE_KNOCK_SEC  =  30 * 60;
    const uint32 CLOSE_FINAL_SEC  =  60 * 60;

    // Batch ops
    const uint8 MAX_BATCH_SIZE = 10;
}

const address TREASURY_WALLET = <set‑at‑deploy>;
const address BURN_SINK       = 0x00_ffff;  // unreachable address

// ============================= 1. AccessControl ===============================

library AccessControl {
    struct Roles { address owner; mapping<address,bool> admins; }
    modifier onlyOwner(Roles r) { require(msg.sender == r.owner, ErrorCodes.NOT_OWNER); }
    modifier onlyAdmin(Roles r) { require(r.admins[msg.sender] || msg.sender == r.owner, ErrorCodes.NOT_ADMIN); }
    external fn transferOwnership(Roles r, address newOwner) onlyOwner(r);
    external fn setAdmin(Roles r, address admin, bool on) onlyOwner(r);
}

// ============================= 2. MatchRegistry ===============================

contract MatchRegistry {
    using AccessControl for AccessControl.Roles;
    AccessControl.Roles _roles;

    enum MatchStatus { Inactive, Open, Closed, Settled }
    enum MatchType   { GROUP, R16, QF, SF, THIRD, FINAL }

    struct Fixture {
        MatchStatus status;
        uint32 kickoffTs;
        cell   teamMeta;
        MatchType mType;
        Result result;
    }

    mapping<uint32, Fixture> _fixtures;

    // --- Admin ---------------------------------------------------------------
    external fn addMatch(MatchKey key, uint32 kickTs, cell teamMeta, MatchType mType) onlyAdmin(_roles);
    external fn setStatus(MatchKey key, MatchStatus st) onlyAdmin(_roles);
    external fn setResult(MatchKey key, Result r) onlyAdmin(_roles);

    // --- Market helpers ------------------------------------------------------
    external fn openMarket(MatchKey key) onlyAdmin(_roles);
    external fn closeMarket(MatchKey key) onlyAdmin(_roles);

    // --- Automation ----------------------------------------------------------
    external fn checkAutoClose(MatchKey key);

    // --- Views ---------------------------------------------------------------
    get fn getMatch(MatchKey key) returns (MatchStatus, uint32, Result, MatchType);

    // --- Events --------------------------------------------------------------
    event ResultPosted(MatchKey key, Result r);
}

// ============================= 3. OracleCoordinator ===========================

contract OracleCoordinator {
    using AccessControl for AccessControl.Roles;
    AccessControl.Roles _roles;

    const uint8 THRESHOLD = 2;

    mapping<address,bool> _authorized;
    mapping<address,uint32> _oracleReputation;
    mapping<uint32 /*matchId*/, mapping<Result,uint8>> _votes;
    mapping<uint32, Result> _finalResults;

    // --- Oracle management ---------------------------------------------------
    external fn addOracle(address oracle) onlyOwner(_roles);
    external fn removeOracle(address oracle) onlyOwner(_roles);

    // --- Submission ----------------------------------------------------------
    external fn submit(MatchKey key, Result r, bytes sig);
    external fn dispute(MatchKey key) onlyOwner(_roles);

    // --- Internal ------------------------------------------------------------
    internal fn _tally(MatchKey key);
    internal fn _finalize(MatchKey key, Result r) {
        _finalResults[key.id] = r;
    }

    // --- Views ---------------------------------------------------------------
    get fn isOracle(address o) returns (bool);
    get fn finalResultOf(MatchKey key) returns (Result);
}

// ============================= 4. MarketFactory ===============================

contract MarketFactory {
    using AccessControl for AccessControl.Roles;
    AccessControl.Roles _roles;

    const cell SIMPLE_MARKET_CODE;
    const cell PLAYER_MARKET_CODE;
    const cell OVERUNDER_MARKET_CODE;
    const cell TOURNAMENT_MARKET_CODE;

    mapping<uint32,address> _markets; // matchId → base market

    // --- Deployment ----------------------------------------------------------
    external fn createMarket(MatchKey key) onlyAdmin(_roles);
    external fn createPlayerMarket(MatchKey key, uint32 playerId, uint8 statType) onlyAdmin(_roles);
    external fn createOverUnderMarket(MatchKey key, uint8 threshold) onlyAdmin(_roles);
    external fn createTournamentMarket(uint8 round, uint8 position) onlyAdmin(_roles);

    // --- Views ---------------------------------------------------------------
    get fn marketOf(MatchKey key) returns (address);
    event MarketCreated(MatchKey key, address market);
}

// ============================= 5. PredictionMarket (1×2) =====================

contract PredictionMarket {
    using AccessControl for AccessControl.Roles;
    AccessControl.Roles _roles;

    // External references injected post‑deploy
    address _stakeVault;
    address _repManager;
    address _treasuryMgr;
    address _achievementNFT;

    bool   _settled = false;

    struct CircuitBreaker {
        bool   paused;
        uint128 maxStakePerUser;
        uint128 maxTotalStake;
        uint32  cooldownSec;
    }
    CircuitBreaker _cb = CircuitBreaker(false,
        PlatformConstants.DEFAULT_USER_LIMIT,
        PlatformConstants.DEFAULT_MARKET_LIMIT,
        0);

    Amount[3] _totalStaked;
    mapping<address, Amount[3]> _userStake;
    Amount     _rewardPool;
    MatchKey   _key;
    uint16     _currentFeeBPS = PlatformConstants.PLATFORM_FEE_BPS;
    Outcome    _winningOutcome;

    // --- Initializer ---------------------------------------------------------
    external fn initialize(address stakeVault, address repMgr, address treasuryMgr, address achNFT) onlyAdmin(_roles) {
        _stakeVault   = stakeVault;
        _repManager   = repMgr;
        _treasuryMgr  = treasuryMgr;
        _achievementNFT = achNFT;
    }

    // --- Fee admin -----------------------------------------------------------
    external fn updateFee(uint16 newFeeBPS) onlyOwner(_roles) {
        require(newFeeBPS <= PlatformConstants.MAX_FEE_BPS, ErrorCodes.ABOVE_MAX);
        _currentFeeBPS = newFeeBPS;
    }

    // --- Prediction flow -----------------------------------------------------
    external fn predict(Outcome o, Amount a);
    external fn settle();
    get      fn myPosition(address u) returns (Amount[3]);

    // --- Reward calc ---------------------------------------------------------
    external fn calculateReward(address user) returns (Amount);

    // --- Events --------------------------------------------------------------
    event Payout(address user, Amount amt);
}

// ============================= 5a. Specialised Markets =======================

interface IMarketCore {
    external fn predict(bytes params, Amount stake);
    external fn settle();
}

contract PlayerPerformanceMarket is PredictionMarket implements IMarketCore {
    struct PlayerMarket { uint32 playerId; uint8 statType; uint8 threshold; }
    PlayerMarket _config;
}

contract TournamentProgressMarket is PredictionMarket implements IMarketCore {
    struct BracketPosition { uint8 round; uint8 position; }
    BracketPosition _target;
}

contract OverUnderMarket is PredictionMarket implements IMarketCore {
    uint8 _goalThreshold;
}

// ============================= 6. PointsRegistry =============================

contract PointsRegistry {
    using AccessControl for AccessControl.Roles;
    AccessControl.Roles _roles;

    mapping<address,uint128> _points;
    mapping<address,uint32>  _weeklyExpiry;
    mapping<address,uint8>   _activePredictions;
    mapping<address,bool>    _premiumUsers;

    const uint128 WEEKLY_BASE     = 1000 * 10^9;
    const uint8   MAX_ACTIVE      = 5;
    const uint128 PREMIUM_FEE_TON = 2 ton;

    // --- Premium -------------------------------------------------------------
    external fn registerPremium() {
        // implementation stub
        emit PremiumRegistered(msg.sender);
    }

    // --- Weekly allocation ---------------------------------------------------
    external fn allocateWeeklyPoints() {
        emit WeeklyPointsAllocated(now(), WEEKLY_BASE);
    }

    // --- Prediction tracking -------------------------------------------------
    external fn recordPrediction(address user, Amount pts) onlyAdmin(_roles) {
        require(pts.rimet >= PlatformConstants.MIN_PREDICTION, ErrorCodes.BELOW_MIN);
        require(pts.rimet <= PlatformConstants.MAX_PREDICTION, ErrorCodes.ABOVE_MAX);
        require(_activePredictions[user] < MAX_ACTIVE, ErrorCodes.TOO_MANY_ACTIVE);
        _activePredictions[user] += 1;
    }

    external fn releasePredictionSlot(address user) onlyAdmin(_roles) {
        if (_activePredictions[user] > 0) _activePredictions[user] -= 1;
    }

    // --- Conversion ----------------------------------------------------------
    external fn convertToTokens(address user) onlyOwner(_roles);

    // --- Views ---------------------------------------------------------------
    get fn pointsOf(address u) returns (uint128);

    // --- Events --------------------------------------------------------------
    event WeeklyPointsAllocated(uint32 weekTs, uint128 totalPts);
    event PremiumRegistered(address user);
}

// ============================= 7. TreasuryManager =============================

contract TreasuryManager {
    const address _communityTreasury = TREASURY_WALLET;

    external fn transferFee(Amount fee) {
        send(_communityTreasury, fee.rimet);
    }

    external fn distributeLosingPool(Amount total, address market) {
        Amount toReward   = Amount({ rimet: total.rimet * 8500 / 10000 });
        Amount toBurn     = Amount({ rimet: total.rimet * 1000 / 10000 });
        Amount toTreasury = Amount({ rimet: total.rimet *  500 / 10000 });
        send(market,             toReward.rimet);
        executeBurn(toBurn);
        send(_communityTreasury, toTreasury.rimet);
    }

    external fn executeBurn(Amount a) { send(BURN_SINK, a.rimet); }
}

// ============================= 8. StakeVault =================================

contract StakeVault {
    using AccessControl for AccessControl.Roles;
    AccessControl.Roles _roles;

    mapping<address,uint128> _locked;
    mapping<address,uint8>   _openPositions;

    const uint128 ACTIVATION_STAKE = 100 * 10^9;

    external fn deposit(Amount a);
    external fn withdraw();

    // Emergency unlock with penalty
    external fn emergencyUnlock(uint16 penaltyBPS);

    // Position counters (called by markets)
    external fn incrementPositions(address user) onlyAdmin(_roles);
    external fn decrementPositions(address user) onlyAdmin(_roles);

    get fn hasActivation(address u) returns (bool);

    event EmergencyWithdraw(address user, Amount net, Amount penalty);
}

// ============================= 9. ReputationManager ===========================

contract ReputationManager {
    using AccessControl for AccessControl.Roles;
    AccessControl.Roles _roles;

    struct ReputationTier { uint8 min; uint8 max; uint16 mult; uint32 achId; }
    ReputationTier[] _tiers;
    mapping<address, Reputation> _score;

    constructor() {
        _tiers.push(ReputationTier(0,30,  80, 0));
        _tiers.push(ReputationTier(31,60,100, 0));
        _tiers.push(ReputationTier(61,85,120, AchievementNFT.FOUNDING_PREDICTOR));
        _tiers.push(ReputationTier(86,100,150, AchievementNFT.REPUTATION_LEGEND));
    }

    external fn addResult(address user, bool correct, Amount stake, uint8 odds) onlyAdmin(_roles);
    get      fn getMultiplier(address user) returns (uint16);
    external fn setTiers(ReputationTier[] t) onlyOwner(_roles);
    external fn getScore(address user) returns (uint8);
    external fn checkAchievementEligibility(address user);
}

// ============================= 10. AchievementNFT ============================

contract AchievementNFT {
    using AccessControl for AccessControl.Roles;
    AccessControl.Roles _roles;

    enum CriteriaType { ConsecutiveWins, PerfectGroup, BracketPerfection, TotalPredictions }

    struct Achievement { string name; string metadata; uint8 tier; uint16 bonusMult; bool transferable; }
    struct Criteria    { CriteriaType cType; uint32 threshold; uint32 window; }

    mapping<uint32, Achievement> _achievements;
    mapping<uint32, Criteria>    _criteria;

    const uint32 FOUNDING_PREDICTOR = 1;
    const uint32 PERFECT_GROUP      = 2;
    const uint32 BRACKET_MASTER     = 3;
    const uint32 REPUTATION_LEGEND  = 4;
    const uint32 STREAK_CHAMPION    = 5;

    const uint32 SEASONAL_START = 1000;
    mapping<uint32,bool> _immutable;

    constructor() {
        _immutable[FOUNDING_PREDICTOR] = true;
        _immutable[PERFECT_GROUP]      = true;
        _immutable[BRACKET_MASTER]     = true;
        _immutable[REPUTATION_LEGEND]  = true;
        _immutable[STREAK_CHAMPION]    = true;
        // default criteria
        _criteria[PERFECT_GROUP]      = Criteria(CriteriaType.PerfectGroup,      6, 0);
        _criteria[STREAK_CHAMPION]    = Criteria(CriteriaType.ConsecutiveWins,   5, 0);
        _criteria[BRACKET_MASTER]     = Criteria(CriteriaType.BracketPerfection, 1, 0);
    }

    // Admin
    external fn defineAchievement(uint32 id, Achievement a) onlyOwner(_roles) {
        require(!_immutable[id], ErrorCodes.NOT_OWNER);
        _achievements[id] = a;
    }
    external fn updateAchievement(uint32 id, Achievement a) onlyOwner(_roles) {
        require(!_immutable[id], ErrorCodes.NOT_OWNER);
        _achievements[id] = a;
    }

    // NFT mint
    external fn mint(address user, uint32 id) onlyAdmin(_roles);

    // Checks
    external fn checkCriteria(address user, uint32 id) returns (bool);
    get      fn getTotalBonus(address user) returns (uint16);
}

// ============================= 11. ReferralRegistry ===========================

contract ReferralRegistry {
    mapping<address,address> _referrer;
    mapping<address,uint32>  _referralsCount;

    external fn registerReferral(address referrer, address referee);
    external fn distributeReferralRewards();
    get      fn referrerOf(address u) returns (address);
}

// ============================= 12. LiquidityManager ===========================

contract LiquidityManager {
    mapping<address /*user*/, mapping<address /*market*/, uint128>> _provided;

    external fn provideLiquidity(address market, Amount a);
    external fn removeLiquidity(address market, Amount a);
    get      fn calculateAPY(address market) returns (uint16);
    get      fn userLiquidityIn(address user, address market) returns (uint128);
}

// ============================= 13. SettlementRouter ===========================

contract SettlementRouter {
    struct SettlementJob { MatchKey key; uint128 totalVal; uint32 priority; }
    SettlementJob[] _queue;

    fn _calcPriority(MatchKey key, uint128 val) returns (uint32) {
        uint32 base = uint32(val / (1000 * 10^9));
        (, , , MatchRegistry.MatchType mt) = MatchRegistry.getMatch(key);
        uint32 bonus = (mt == MatchRegistry.MatchType.FINAL) ? 1000 : (mt >= MatchRegistry.MatchType.R16 ? 100 : 0);
        return base + bonus;
    }

    external fn enqueue(MatchKey key, uint128 totalVal) {
        uint32 pr = _calcPriority(key,totalVal);
        _queue.push(SettlementJob(key,totalVal,pr));
    }

    external fn settleBatch(uint16 maxJobs);
    external fn topUp();
}

// ============================= 14. EmergencyController ========================

contract EmergencyController {
    using AccessControl for AccessControl.Roles;
    AccessControl.Roles _roles;

    external fn pauseAllMarkets() onlyOwner(_roles);
    external fn drainToTreasury(address market) onlyOwner(_roles);
    external fn enableWithdrawOnly() onlyOwner(_roles);
}

// ============================= 15. ITelegramBridge ============================

interface ITelegramBridge {
    external fn authenticateUser(uint64 telegramId, address tonWallet);
    external fn notifyPrediction(address user, address market, Outcome o, Amount a);
    external fn pushResult(MatchKey key, Result r);
}

// ============================= 16. GasEstimator ===============================

contract GasEstimator {
    get fn estimatePredictionGas(uint8 nOutcomes) returns (uint128);
    get fn estimateSettlementGas(uint32 nUsers) returns (uint128);
}

// ============================= 17. MarketStats ================================

contract MarketStats {
    struct Stats { uint128 totalVol; uint32 totalPreds; uint32 users; }
    mapping<address, Stats> _stats;

    external fn recordPrediction(address market, address user, Amount a);
    get      fn statsOf(address market) returns (Stats);
}

// ============================= 18. BatchOperations ============================

contract BatchOperations {
    external fn batchPredict(address[] markets, Outcome[] outs, Amount[] stakes) {
        require(markets.length == outs.length && outs.length == stakes.length);
        require(markets.length <= PlatformConstants.MAX_BATCH_SIZE, ErrorCodes.BATCH_TOO_LARGE);
        // iterate...
    }
}

// -----------------------------------------------------------------------------
//  END OF FILE – v0.7
