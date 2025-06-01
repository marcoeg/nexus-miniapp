// SPDX‑License‑Identifier: MIT
// ──────────────────────────────────────────────────────────────────────────────
//  Nexus26 – MarketFactory (v1.0)
//  Deploys prediction markets for each match and specialised market flavours.
// ──────────────────────────────────────────────────────────────────────────────
import "../common/AccessControl.tact";
import "../libraries/ErrorCodes.tact";
import "./PredictionMarket.tact";
import "./PlayerPerformanceMarket.tact";
import "./OverUnderMarket.tact";
import "./TournamentProgressMarket.tact";

contract MarketFactory is AccessControl {

    mapping<uint32, address> _simpleMarkets;      // matchKey → market
    address _matchRegistry;
    cell    _simpleCode;
    cell    _playerCode;
    cell    _ouCode;
    cell    _tpCode;

    event MarketCreated(uint32 key, address market);

    constructor(
        address owner,
        address matchRegistry,
        cell simpleCode,
        cell playerCode,
        cell ouCode,
        cell tpCode
    ) {
        _initAccessControl(owner);
        _matchRegistry = matchRegistry;
        _simpleCode = simpleCode;
        _playerCode = playerCode;
        _ouCode     = ouCode;
        _tpCode     = tpCode;
    }

    // ─────────── Simple 1×2 market ───────────
    external fn createSimpleMarket(uint32 key)
        onlyAdmin
    {
        require(!_simpleMarkets.exists(key), ErrorCodes.ERR_ALREADY_EXISTS);

        address market = new PredictionMarket(
            code: _simpleCode,
            init: {matchKey: key, matchRegistry: _matchRegistry}
        );
        _simpleMarkets[key] = market;
        emit MarketCreated(key, market);
    }

    // ─────────── PlayerPerformance ───────────
    external fn createPlayerMarket(
        uint32 key,
        uint32 playerId,
        uint8 statType,
        cell  playerCodePayload
    ) onlyAdmin {
        address market = new PlayerPerformanceMarket(
            code: _playerCode,
            init: {
                matchKey: key,
                playerId: playerId,
                statType: statType,
                matchRegistry: _matchRegistry,
                extra: playerCodePayload
            }
        );
        emit MarketCreated(key, market);
    }

    // Over/Under
    external fn createOverUnderMarket(
        uint32 key,
        uint8 threshold
    ) onlyAdmin {
        address market = new OverUnderMarket(
            code: _ouCode,
            init: {
                matchKey: key,
                threshold: threshold,
                matchRegistry: _matchRegistry
            }
        );
        emit MarketCreated(key, market);
    }

    // Tournament progress
    external fn createTournamentMarket(
        uint32 key,
        uint8 round,
        uint8 pos
    ) onlyAdmin {
        address market = new TournamentProgressMarket(
            code: _tpCode,
            init: {
                matchKey: key,
                round: round,
                position: pos,
                matchRegistry: _matchRegistry
            }
        );
        emit MarketCreated(key, market);
    }

    // view
    get fn marketOf(uint32 key) returns (address) {
        return _simpleMarkets[key];
    }
}
