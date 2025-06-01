// SPDX‑License‑Identifier: MIT
// ──────────────────────────────────────────────────────────────────────────────
//  Nexus26 – OracleCoordinator (v1.0)
//  Aggregates signed results from multiple oracle keys and pushes final result
//  to MatchRegistry once 2‑of‑N identical payloads have been received.
// ──────────────────────────────────────────────────────────────────────────────
import "../common/AccessControl.tact";
import "../libraries/ErrorCodes.tact";
import "./MatchRegistry.tact";

struct Payload {
    uint32 matchKey;
    uint8  winner;      // 0‑home,1‑draw,2‑away
}

contract OracleCoordinator is AccessControl {

    // ─────────── Storage ───────────
    mapping<address, bool> _oracles;
    mapping<uint32, mapping<uint8, uint8>> _votes;  // match → winner → count
    address _registry;
    uint8   constant THRESHOLD = 2;

    // ─────────── Events ───────────
    event VoteReceived(uint32 key, uint8 winner, address oracle);
    event ConsensusReached(uint32 key, uint8 winner);

    // ─────────── Constructor ───────────
    constructor(address owner, address registry, address[] initialOracles) {
        _initAccessControl(owner);
        _registry = registry;
        for (addr o : initialOracles) _oracles[o] = true;
    }

    // ─────────── Oracle mgmt ───────────
    external fn addOracle(address o) onlyOwner { _oracles[o] = true; }
    external fn removeOracle(address o) onlyOwner { delete _oracles[o]; }

    // ─────────── Submit result ───────────
    external fn submit(Payload p) {
        require(_oracles[msg.sender], ErrorCodes.ERR_NOT_ORACLE);

        _votes[p.matchKey][p.winner] += 1;
        emit VoteReceived(p.matchKey, p.winner, msg.sender);

        if (_votes[p.matchKey][p.winner] == THRESHOLD) {
            // Push to MatchRegistry
            var body = beginCell()
                .storeUint(0, 32)          // function selector not used
                .storeUint(p.matchKey, 32)
                .storeUint(p.winner, 8)
                .endCell();

            sendInternalMessage(
                address(this),
                _registry,
                0.2 ton,
                false,
                body
            );
            emit ConsensusReached(p.matchKey, p.winner);
        }
    }
}
