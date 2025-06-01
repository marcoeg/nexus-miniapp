// SPDX‑License‑Identifier: MIT
// ──────────────────────────────────────────────────────────────────────────────
//  Nexus26 – AchievementNFT (Soul‑Bound ERC‑721‑like for TON)
// ──────────────────────────────────────────────────────────────────────────────
import "../common/AccessControl.tact";
import "../libraries/ErrorCodes.tact";

struct Achievement {
    string  name;
    string  meta;
    uint8   tier;
    uint16  bonus;       // % multiplier
    bool    transferable;
}

contract AchievementNFT is AccessControl {

    // ────────── Storage ──────────
    mapping<uint32, Achievement> _catalogue;          // id → meta
    mapping<uint32, address>     _ownerOf;            // tokenId → owner
    mapping<address, uint32[]>   _held;               // owner → token list
    uint32                       _nextId = 1;

    // ────────── Events ──────────
    event Defined(uint32 id, string name);
    event Minted(uint32 id, address to);

    constructor(address owner) {
        _initAccessControl(owner);

        // Immutable core achievements predefined
        _define(1, "Founding Predictor", "Early supporter", 1, 10, false);
        _define(2, "Perfect Group",      "Predicted all group matches", 2, 10, false);
        _define(3, "Bracket Master",     "Perfect KO bracket", 3, 25, false);
        _define(4, "Reputation Legend",  "Reach rep ≥ 90", 3, 25, false);
        _define(5, "Streak Champion",    "5‑win streak", 2, 10, false);
    }

    // ────────── Admin API ──────────
    external fn defineAchievement(
        uint32 id,
        Achievement a
    ) onlyOwner {
        require(!_catalogue.exists(id), ErrorCodes.ERR_ALREADY_EXISTS);
        _define(id, a.name, a.meta, a.tier, a.bonus, a.transferable);
    }

    internal fn _define(
        uint32 id,
        string name,
        string meta,
        uint8  tier,
        uint16 bonus,
        bool   transferable
    ) {
        _catalogue[id] = Achievement(name, meta, tier, bonus, transferable);
        emit Defined(id, name);
        if (id >= _nextId) _nextId = id + 1;
    }

    // ────────── Mint (only authorised contracts) ──────────
    external fn mint(address to, uint32 id) onlyAdmin {
        require(!_ownerOf.exists(id), ErrorCodes.ERR_ALREADY_MINTED);
        _ownerOf[id] = to;
        _held[to].push(id);
        emit Minted(id, to);
    }

    // Soul‑bound – disable transfers unless transferable flag true
    external fn transfer(address to, uint32 id) {
        Achievement a = _catalogue[id];
        require(a.transferable, ErrorCodes.ERR_SBT_NON_TRANSFERABLE);
        require(_ownerOf[id] == msg.sender, ErrorCodes.ERR_NOT_OWNER);
        _ownerOf[id] = to;
    }

    // ────────── Views ──────────
    get fn ownerOf(uint32 id) returns (address) { return _ownerOf[id]; }
    get fn bonusOf(address u) returns (uint16) {
        uint16 total = 0;
        for (uint32 id : _held[u]) {
            total += _catalogue[id].bonus;
        }
        return total;
    }
}
