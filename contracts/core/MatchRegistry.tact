// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
//  Nexus26 – MatchRegistry (v1.0 – full implementation)
// -----------------------------------------------------------------------------
//  Stores fixture metadata and lifecycle state, and emits ResultPosted events
//  consumed by PredictionMarket instances.
// -----------------------------------------------------------------------------

import "../common/AccessControl.tact";
import "../libraries/ErrorCodes.tact";

// ─────────────────────────────────────────────────────────────────────────────
//  ENUMS & STRUCTS
// ─────────────────────────────────────────────────────────────────────────────

enum MatchStatus { Inactive, Open, Closed, Settled }

struct MatchMeta {
    uint32 kickoff;          // epoch secs
    uint8  matchType;        // group, R16, etc.
    cell   teamMeta;         // {home, away, group}
    MatchStatus status;
    Result result;
}

struct Result { uint8 winner; }   // 0‑home,1‑draw,2‑away (extendable)

// ─────────────────────────────────────────────────────────────────────────────
contract MatchRegistry is AccessControl {
    // Storage
    mapping<uint32, MatchMeta> _matches;    // key → meta
    mapping<address, bool>     _oracles;    // authorised result updaters

    // Events
    event MatchAdded(uint32 key);
    event MatchOpened(uint32 key);
    event MatchClosed(uint32 key);
    event ResultPosted(uint32 key, uint8 winner);

    // ────────── Constructor ──────────
    constructor(address owner, address[] initialOracles) {
        _initAccessControl(owner);
        for (addr o : initialOracles) {
            _oracles[o] = true;
        }
    }

    // ────────── Admin controls ──────────
    external fn addOracle(address o) onlyOwner {
        _oracles[o] = true;
    }
    external fn removeOracle(address o) onlyOwner {
        delete _oracles[o];
    }

    // ────────── Match lifecycle ──────────
    external fn addMatch(uint32 key, uint32 kickoff, uint8 mType, cell teamMeta)
        onlyAdmin
    {
        require(!_matches.exists(key), ErrorCodes.ERR_ALREADY_EXISTS);
        _matches[key] = MatchMeta(kickoff, mType, teamMeta, MatchStatus.Inactive, Result(255));
        emit MatchAdded(key);
    }

    external fn openMarket(uint32 key) onlyAdmin {
        require(_matches[key].status == MatchStatus.Inactive, ErrorCodes.ERR_BAD_STATE);
        _matches[key].status = MatchStatus.Open;
        emit MatchOpened(key);
    }

    external fn closeMarket(uint32 key) onlyAdmin {
        require(_matches[key].status == MatchStatus.Open, ErrorCodes.ERR_BAD_STATE);
        _matches[key].status = MatchStatus.Closed;
        emit MatchClosed(key);
    }

    external fn setResult(uint32 key, Result r) {
        require(_oracles[msg.sender], ErrorCodes.ERR_NOT_ORACLE);
        MatchMeta m = _matches[key];
        require(m.status == MatchStatus.Closed, ErrorCodes.ERR_BAD_STATE);
        m.status  = MatchStatus.Settled;
        m.result  = r;
        _matches[key] = m;
        emit ResultPosted(key, r.winner);
    }

    // ────────── Views ──────────
    get fn getMatch(uint32 key)
        returns (MatchStatus status, uint32 kickoff, uint8 winner)
    {
        MatchMeta m = _matches[key];
        return (m.status, m.kickoff, m.result.winner);
    }
}
