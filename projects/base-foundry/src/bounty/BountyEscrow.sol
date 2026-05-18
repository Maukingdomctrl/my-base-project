// SPDX-License-Identifier: MIT
pragma solidity >=0.8.35 <0.9.0;

import {Pausable} from "../core/Pausable.sol";
import {ReentrancyGuard} from "../core/ReentrancyGuard.sol";

/// @title BountyEscrow
/// @notice Simple native-token escrow between sponsor and hunter with owner emergency controls
contract BountyEscrow is Pausable, ReentrancyGuard {
    error InvalidAddress();
    error ZeroAmount();
    error InvalidState();
    error Unauthorized();
    error TransferFailed();

    event Funded(address indexed sponsor, uint256 amount);
    event Released(address indexed hunter, uint256 amount);
    event Refunded(address indexed sponsor, uint256 amount);
    event Cancelled();

    enum State {
        Created,
        Funded,
        Released,
        Refunded,
        Cancelled
    }

    address public immutable sponsor;
    address public immutable hunter;

    State public state;
    uint256 public fundedAmount;

    constructor(address initialOwner, address _sponsor, address _hunter) Pausable(initialOwner) {
        if (_sponsor == address(0) || _hunter == address(0)) revert InvalidAddress();
        if (_sponsor == _hunter) revert InvalidAddress();

        sponsor = _sponsor;
        hunter = _hunter;
        state = State.Created;
    }

    modifier onlySponsor() {
        if (msg.sender != sponsor) revert Unauthorized();
        _;
    }

    modifier onlySponsorOrOwner() {
        if (msg.sender != sponsor && msg.sender != owner) revert Unauthorized();
        _;
    }

    function fund() external payable onlySponsor whenNotPaused nonReentrant {
        if (state != State.Created) revert InvalidState();
        if (msg.value == 0) revert ZeroAmount();

        fundedAmount = msg.value;
        state = State.Funded;

        emit Funded(msg.sender, msg.value);
    }

    /// @notice Releases escrowed funds to hunter
    function release() external onlySponsorOrOwner whenNotPaused nonReentrant {
        if (state != State.Funded) revert InvalidState();

        uint256 amount = fundedAmount;
        fundedAmount = 0;
        state = State.Released;

        (bool ok,) = payable(hunter).call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit Released(hunter, amount);
    }

    /// @notice Refunds escrowed funds to sponsor
    function refund() external onlySponsorOrOwner whenNotPaused nonReentrant {
        if (state != State.Funded) revert InvalidState();

        uint256 amount = fundedAmount;
        fundedAmount = 0;
        state = State.Refunded;

        (bool ok,) = payable(sponsor).call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit Refunded(sponsor, amount);
    }

    /// @notice Cancels before funding
    function cancel() external onlySponsorOrOwner whenNotPaused {
        if (state != State.Created) revert InvalidState();
        state = State.Cancelled;
        emit Cancelled();
    }
}
