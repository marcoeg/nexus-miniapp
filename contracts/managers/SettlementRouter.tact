// SPDX‑License‑Identifier: MIT
// ──────────────────────────────────────────────────────────────────────────────
//  Nexus26 – SettlementRouter
//  Sponsors gas and batch‑settles markets once results are final.
// ──────────────────────────────────────────────────────────────────────────────
import "../common/AccessControl.tact";
import "../libraries/ErrorCodes.tact";

struct Job {
    address market;
    uint128 value;      // total staked value – used for priority
    uint32  priority;   // pre‑computed weight
}

contract SettlementRouter is AccessControl {

    // ───────────
    //  STORAGE
    // ───────────
    mapping<uint32, Job> _jobs;     // circular buffer
    uint32 _head = 0;
    uint32 _tail = 0;
    uint32 _size = 0;
    uint32 constant QUEUE_CAP = 512;

    bool   _lock = false;           // re‑entrancy guard

    // ───────────
    //  EVENTS
    // ───────────
    event JobEnqueued(address market, uint32 prio);
    event JobSettled(address market, uint128 gasUsed);
    event BatchSettled(uint16 count);
    event TopUp(uint128 amount);
    event Withdraw(address to, uint128 amount);

    // ───────────
    //  CONSTRUCTOR
    // ───────────
    constructor(address owner) {
        _initAccessControl(owner);
    }

    // ───────────
    //  ADMIN: QUEUE MGMT
    // ───────────
    external fn enqueueSettlement(address market, uint128 value)
        onlyAdmin
    {
        require(_size < QUEUE_CAP, ErrorCodes.ERR_QUEUE_FULL);

        uint32 prio = _calcPriority(value);
        _jobs[_tail] = Job(market, value, prio);
        _tail = (_tail + 1) % QUEUE_CAP;
        _size += 1;

        emit JobEnqueued(market, prio);
    }

    // ───────────
    //  PUBLIC: PROCESS
    // ───────────
    external fn settleBatch(uint16 maxJobs) whenNotPaused {
        require(!_lock, ErrorCodes.ERR_REENTRANT);
        _lock = true;

        uint16 processed = 0;
        while (_size > 0 && processed < maxJobs) {
            Job j = _jobs[_head];
            _head = (_head + 1) % QUEUE_CAP;
            _size -= 1;

            // call market.settle() with 0.3 TON gas‑limit
            var body = beginCell().storeUint(0, 32).endCell();
            sendInternalMessage(
                address(this),
                j.market,
                0.3 ton,
                false,
                body
            );

            emit JobSettled(j.market, 0.3 ton);
            processed += 1;
        }

        emit BatchSettled(processed);
        _lock = false;
    }

    // ───────────
    //  BANKROLL
    // ───────────
    receive fn() external {
        emit TopUp(msg.value);
    }

    external fn withdrawExcess(address to, uint128 amount) onlyOwner {
        require(amount <= self.balance, ErrorCodes.ERR_INSUFF_BAL);
        sendInternalMessage(address(this), to, amount, false, beginCell().endCell());
        emit Withdraw(to, amount);
    }

    // ───────────
    //  INTERNAL
    // ───────────
    internal fn _calcPriority(uint128 value) returns (uint32) {
        // simple: 1 priority point per 1 000 $RIMET
        return uint32(value / (1_000 * 10^9));
    }
}
