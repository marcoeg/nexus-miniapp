// SPDX‑License‑Identifier: MIT
import "../common/AccessControl.tact";
import "../libraries/ErrorCodes.tact";

contract EmergencyController is AccessControl {

    mapping<address, bool> _pausedMarkets;

    constructor(address owner) {
        _initAccessControl(owner);
    }

    external fn pauseMarket(address mkt) onlyAdmin {
        _pausedMarkets[mkt] = true;
    }

    external fn unpauseMarket(address mkt) onlyAdmin {
        delete _pausedMarkets[mkt];
    }

    external fn drainToTreasury(address mkt, address treasury)
        onlyOwner
    {
        sendInternalMessage(
            mkt,
            treasury,
            0,
            false,
            beginCell().storeUint(0, 32).endCell()   // market implements withdrawAll()
        );
    }

    get fn isPaused(address mkt) returns (bool) {
        return _pausedMarkets[mkt];
    }
}
