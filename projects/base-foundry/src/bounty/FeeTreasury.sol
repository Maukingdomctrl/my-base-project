// SPDX-License-Identifier: MIT
pragma solidity >=0.8.35 <0.9.0;

import {Owned} from "../core/Owned.sol";
import {ReentrancyGuard} from "../core/ReentrancyGuard.sol";

/// @title FeeTreasury
/// @notice Stores protocol fees and allows owner-managed fee configuration/withdrawals
contract FeeTreasury is Owned, ReentrancyGuard {
    error InvalidFeeBps();
    error InvalidRecipient();
    error InsufficientBalance();

    event FeeBpsUpdated(uint16 previousFeeBps, uint16 newFeeBps);
    event FeeRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);
    event FeeWithdrawn(address indexed to, uint256 amount);
    event NativeReceived(address indexed from, uint256 amount);

    uint16 public constant MAX_BPS = 10_000; // 100%

    uint16 public feeBps;          // protocol fee in basis points
    address public feeRecipient;   // destination for withdrawn fees

    constructor(address initialOwner, address initialRecipient, uint16 initialFeeBps) Owned(initialOwner) {
        if (initialRecipient == address(0)) revert InvalidRecipient();
        if (initialFeeBps > MAX_BPS) revert InvalidFeeBps();

        feeRecipient = initialRecipient;
        feeBps = initialFeeBps;
    }

    receive() external payable {
        emit NativeReceived(msg.sender, msg.value);
    }

    function setFeeBps(uint16 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_BPS) revert InvalidFeeBps();
        uint16 prev = feeBps;
        feeBps = newFeeBps;
        emit FeeBpsUpdated(prev, newFeeBps);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert InvalidRecipient();
        address prev = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(prev, newRecipient);
    }

    function quoteFee(uint256 amount) external view returns (uint256) {
        return (amount * feeBps) / MAX_BPS;
    }

    function withdraw(uint256 amount) external onlyOwner nonReentrant {
        if (amount > address(this).balance) revert InsufficientBalance();

        (bool ok,) = feeRecipient.call{value: amount}("");
        require(ok, "transfer failed");

        emit FeeWithdrawn(feeRecipient, amount);
    }

    function withdrawAll() external onlyOwner nonReentrant {
        uint256 amount = address(this).balance;

        (bool ok,) = feeRecipient.call{value: amount}("");
        require(ok, "transfer failed");

        emit FeeWithdrawn(feeRecipient, amount);
    }
}
