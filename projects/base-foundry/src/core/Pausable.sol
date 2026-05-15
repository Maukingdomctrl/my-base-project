// SPDX-License-Identifier: MIT
pragma solidity >=0.8.35 <0.9.0;

import {Owned} from "./Owned.sol";

/// @title Pausable
/// @notice Emergency stop mechanism controlled by owner
abstract contract Pausable is Owned {
    error EnforcedPause();
    error ExpectedPause();

    event PausedStateSet(bool indexed isPaused);

    bool private _paused;

    constructor(address initialOwner) Owned(initialOwner) {
        _paused = false;
    }

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    modifier whenPaused() {
        _requirePaused();
        _;
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    function pause() external onlyOwner {
        _requireNotPaused();
        _paused = true;
        emit PausedStateSet(true);
    }

    function unpause() external onlyOwner {
        _requirePaused();
        _paused = false;
        emit PausedStateSet(false);
    }

    function _requireNotPaused() internal view {
        if (_paused) revert EnforcedPause();
    }

    function _requirePaused() internal view {
        if (!_paused) revert ExpectedPause();
    }
}
