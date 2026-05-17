// SPDX-License-Identifier: MIT
pragma solidity >=0.8.35 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {Owned} from "../../src/core/Owned.sol";

contract OwnedHarness is Owned {
    uint256 public value;

    constructor(address initialOwner) Owned(initialOwner) {}

    function ownerOnlySet(uint256 newValue) external onlyOwner {
        value = newValue;
    }
}

contract OwnedTest is Test {
    OwnedHarness internal owned;

    address internal deployer = address(0xA11CE);
    address internal alice = address(0xB0B);
    address internal bob = address(0xC0B);

    function setUp() public {
        vm.prank(deployer);
        owned = new OwnedHarness(deployer);
    }

    function test_constructor_setsOwner() public view {
        assertEq(owned.owner(), deployer);
    }

    function test_constructor_zeroOwner_reverts() public {
        vm.expectRevert(Owned.ZeroAddressOwner.selector);
        new OwnedHarness(address(0));
    }

    function test_ownerOnly_function_byOwner_succeeds() public {
        vm.prank(deployer);
        owned.ownerOnlySet(42);
        assertEq(owned.value(), 42);
    }

    function test_ownerOnly_function_byNonOwner_reverts() public {
        vm.prank(alice);
        vm.expectRevert(Owned.NotOwner.selector);
        owned.ownerOnlySet(99);
    }

    function test_transferOwnership_byOwner_updatesOwner() public {
        vm.prank(deployer);
        owned.transferOwnership(alice);
        assertEq(owned.owner(), alice);
    }

    function test_transferOwnership_zeroAddress_reverts() public {
        vm.prank(deployer);
        vm.expectRevert(Owned.ZeroAddressOwner.selector);
        owned.transferOwnership(address(0));
    }

    function test_transferOwnership_byNonOwner_reverts() public {
        vm.prank(alice);
        vm.expectRevert(Owned.NotOwner.selector);
        owned.transferOwnership(bob);
    }

    function test_oldOwner_losesAccess_afterTransfer() public {
        vm.prank(deployer);
        owned.transferOwnership(alice);

        vm.prank(deployer);
        vm.expectRevert(Owned.NotOwner.selector);
        owned.ownerOnlySet(1);
    }

    function test_newOwner_gainsAccess_afterTransfer() public {
        vm.prank(deployer);
        owned.transferOwnership(alice);

        vm.prank(alice);
        owned.ownerOnlySet(77);
        assertEq(owned.value(), 77);
    }

    function test_transferOwnership_emitsEvent() public {
        vm.prank(deployer);
        vm.expectEmit(true, true, false, true);
        emit Owned.OwnershipTransferred(deployer, alice);
        owned.transferOwnership(alice);
    }
}
