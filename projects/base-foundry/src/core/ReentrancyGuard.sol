// SPDX-License-Identifier: MIT
pragma solidity >=0.8.35 <0.9.0;

/// @title ReentrancyGuard
/// @notice Prevents reentrant calls to protected functions
/// @dev Use nonReentrant on state-changing functions, nonReentrantView
///      on view functions that read state used in pricing or accounting
abstract contract ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a reentrant call is detected
    error ReentrantCall();

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _status = _NOT_ENTERED;
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Prevents reentrant calls on state-changing functions
    modifier nonReentrant() {
        _requireNotEntered();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    /// @notice Prevents read-only reentrancy attacks on view functions
    modifier nonReentrantView() {
        _requireNotEntered();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Reverts if the contract is currently entered
    function _requireNotEntered() internal view {
        if (_status == _ENTERED) revert ReentrantCall();
    }

    /// @dev Returns true if execution is currently inside a nonReentrant call
    function _entered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}
