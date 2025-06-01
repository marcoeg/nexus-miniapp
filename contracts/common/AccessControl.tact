// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
//  Nexus26 – AccessControl Module (Ownable + Lightweight Role‑Based Access)
//  Shared by multiple contracts for ownership, admin roles, and pause control.
//  -----------------------------------------------------------------------------
//  NOTE: This contract is intended to be inherited via `extends` in Tact.
//        All child contracts must call `_initAccessControl(msg.sender)`
//        inside their constructor, OR forward their constructor parameters to
//        a parent constructor that does so.
// -----------------------------------------------------------------------------

import "../libraries/ErrorCodes.tact" as ErrorCodes;

abstract contract AccessControl {

    // -------------------------------------------------------------------------
    //  Storage
    // -------------------------------------------------------------------------
    address static _owner;                     // immutable after deployment
    mapping<address, bool> _admin;             // simple admin flag
    bool _paused = false;                      // circuit‑breaker flag

    // -------------------------------------------------------------------------
    //  Initialiser (call from inheriting constructor)
    // -------------------------------------------------------------------------
    inline fn _initAccessControl(address owner) internal {
        _owner = owner;
        _admin[owner] = true;
    }

    // -------------------------------------------------------------------------
    //  Modifiers (implemented as inline require helpers in Tact)
    // -------------------------------------------------------------------------
    inline fn _onlyOwner() internal view {
        require(msg.sender == _owner, ErrorCodes.ERR_NOT_OWNER);
    }

    inline fn _onlyAdmin() internal view {
        require(_admin[msg.sender], ErrorCodes.ERR_NOT_ADMIN);
    }

    inline fn _whenNotPaused() internal view {
        require(!_paused, ErrorCodes.ERR_PAUSED);
    }

    inline fn _whenPaused() internal view {
        require(_paused, ErrorCodes.ERR_PAUSED);
    }

    // -------------------------------------------------------------------------
    //  Owner functions
    // -------------------------------------------------------------------------
    external fn transferOwnership(address newOwner) {
        _onlyOwner();
        require(newOwner != 0, ErrorCodes.ERR_NOT_OWNER);
        _owner = newOwner;
    }

    external fn addAdmin(address account) {
        _onlyOwner();
        _admin[account] = true;
    }

    external fn removeAdmin(address account) {
        _onlyOwner();
        _admin[account] = false;
    }

    external fn pause() {
        _onlyOwner();
        _paused = true;
    }

    external fn unpause() {
        _onlyOwner();
        _paused = false;
    }

    // -------------------------------------------------------------------------
    //  Views
    // -------------------------------------------------------------------------
    get fn owner() returns (address) {
        return _owner;
    }

    get fn isAdmin(address account) returns (bool) {
        return _admin[account];
    }

    get fn paused() returns (bool) {
        return _paused;
    }
}
