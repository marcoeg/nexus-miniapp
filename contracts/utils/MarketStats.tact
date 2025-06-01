// SPDX‑License‑Identifier: MIT
import "../libraries/ErrorCodes.tact";

struct Stat {
    uint128 volume;
    uint32  predictions;
    uint32  users;
}

contract MarketStats {

    mapping<address, Stat> _stats;
    mapping<address, mapping<address, bool>> _userSeen;

    /// Market must call after every predict()
    external fn recordPrediction(address user, uint128 amount) {
        Stat s = _stats[msg.sender];
        s.volume += amount;
        s.predictions += 1;
        if (!_userSeen[msg.sender][user]) {
            _userSeen[msg.sender][user] = true;
            s.users += 1;
        }
        _stats[msg.sender] = s;
    }

    get fn statsOf(address market) returns (Stat) {
        return _stats[market];
    }
}
