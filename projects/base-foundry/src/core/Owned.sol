// SPDX-License-Identifier: MIT
pragma solidity >=0.8.35 <0.9.0;

/// @title Owned
/// @notice Basic owner access control module
contract Owned {
    error NotOwner();
    error ZeroAddressOwner();

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    address public owner;

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddressOwner();
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddressOwner();

        address previousOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(previousOwner, newOwner);
    }
}
