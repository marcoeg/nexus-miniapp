// SPDX‑License‑Identifier: MIT
// ──────────────────────────────────────────────────────────────────────────────
//  Nexus26 – LiquidityManager
//  Lets users provide / remove $RIMET liquidity per‑market and records
//  platform‑fee accruals so APY can be estimated on‑chain.
// ──────────────────────────────────────────────────────────────────────────────
import "../common/AccessControl.tact";
import "../libraries/PlatformConstants.tact";
import "../libraries/ErrorCodes.tact";

struct MarketInfo {
    uint128 totalLiquidity;          // Σ user liquidity
    uint128 feesAccrued;             // Σ fees sent in via recordFees
    uint64  lastFeeTs;               // timestamp of last fee record
}

contract LiquidityManager is AccessControl {

    // ───────────
    //  STORAGE
    // ───────────
    mapping<address, mapping<address, uint128>> _provided;   // user → market → amt
    mapping<address, MarketInfo>                _markets;    // market → info
    address                                     _jettonRoot; // $RIMET root

    // ───────────
    //  EVENTS
    // ───────────
    event LiquidityAdded(address lp, address market, uint128 amount);
    event LiquidityRemoved(address lp, address market, uint128 amount);
    event FeesRecorded(address market, uint128 amount);

    // ───────────
    //  CONSTRUCTOR
    // ───────────
    constructor(address owner, address jettonRoot) {
        _initAccessControl(owner);   // from AccessControl
        _jettonRoot = jettonRoot;
    }

    // ───────────
    //  USER ACTIONS
    // ───────────
    external fn provideLiquidity(address market, uint128 amount)
        whenNotPaused
    {
        require(amount > 0, ErrorCodes.ERR_ZERO_AMOUNT);

        _safeJettonTransfer(msg.sender, address(this), amount);

        _provided[msg.sender][market] += amount;
        _markets[market].totalLiquidity += amount;

        emit LiquidityAdded(msg.sender, market, amount);
    }

    external fn removeLiquidity(address market, uint128 amount)
        whenNotPaused
    {
        uint128 provided = _provided[msg.sender][market];
        require(amount > 0 && amount <= provided, ErrorCodes.ERR_INSUFF_LIQ);

        _provided[msg.sender][market] = provided - amount;
        _markets[market].totalLiquidity -= amount;

        _safeJettonTransfer(address(this), msg.sender, amount);
        emit LiquidityRemoved(msg.sender, market, amount);
    }

    // ───────────
    //  MARKET HOOK
    // ───────────
    external fn recordFees(uint128 amount) onlyAdmin {
        address market = msg.sender;
        require(amount > 0, ErrorCodes.ERR_ZERO_AMOUNT);

        _markets[market].feesAccrued += amount;
        _markets[market].lastFeeTs = now();

        // Jettons already transferred by market.
        emit FeesRecorded(market, amount);
    }

    // ───────────
    //  VIEWS
    // ───────────
    get fn userLiquidityIn(address user, address market)
        returns (uint128) {
        return _provided[user][market];
    }

    get fn marketLiquidity(address market) returns (uint128) {
        return _markets[market].totalLiquidity;
    }

    /// Annualised APY in basis‑points (1 BPS = 0.01 %)
    get fn calculateAPY(address market) returns (uint32) {
        let info = _markets[market];
        if (info.totalLiquidity == 0) {
            return 0;
        }
        // Fees over last 30 days → annualise
        uint32 secsPerYear = 31_536_000;
        uint32 window      = 2_592_000;      // 30 days
        uint128 annualFees = info.feesAccrued * secsPerYear / window;
        return uint32(annualFees * 10_000 / info.totalLiquidity); // BPS
    }

    // ───────────
    //  INTERNAL
    // ───────────
    internal fn _safeJettonTransfer(
        address from,
        address to,
        uint128 amount
    ) {
        // Build standard Jetton Wallet transfer ‑‑ op 0xf8a7ea5
        var body = beginCell()
            .storeUint(0xf8a7ea5, 32)             // op
            .storeUint(0, 64)                     // query id
            .storeCoins(amount)                   // amount
            .storeAddress(to)                     // recipient
            .storeAddress(0)                      // response dest
            .storeBit(false)                      // custom payload?
            .endCell();

        sendInternalMessage(
            from,
            _jettonRoot,
            0.1 ton,
            false,
            body
        );
    }
}
