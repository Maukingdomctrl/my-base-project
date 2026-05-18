// SPDX-License-Identifier: MIT
pragma solidity >=0.8.35 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {FeeTreasury} from "../../src/bounty/FeeTreasury.sol";
import {Owned} from "../../src/core/Owned.sol";

contract FeeTreasuryTest is Test {
    FeeTreasury internal treasury;

    address internal owner = address(0xA11CE);
    address internal recipient = address(0xBEEF);
    address internal alice = address(0xB0B);

    function setUp() public {
        vm.prank(owner);
        treasury = new FeeTreasury(owner, recipient, 250); // 2.5%
    }

    function test_constructor_setsState() public view {
        assertEq(treasury.owner(), owner);
        assertEq(treasury.feeRecipient(), recipient);
        assertEq(treasury.feeBps(), 250);
    }

    function test_constructor_zeroRecipient_reverts() public {
        vm.expectRevert(FeeTreasury.InvalidRecipient.selector);
        new FeeTreasury(owner, address(0), 100);
    }

    function test_constructor_invalidFee_reverts() public {
        vm.expectRevert(FeeTreasury.InvalidFeeBps.selector);
        new FeeTreasury(owner, recipient, 10_001);
    }

    function test_setFeeBps_byOwner_succeeds() public {
        vm.prank(owner);
        treasury.setFeeBps(500);
        assertEq(treasury.feeBps(), 500);
    }

    function test_setFeeBps_nonOwner_reverts() public {
        vm.prank(alice);
        vm.expectRevert(Owned.NotOwner.selector);
        treasury.setFeeBps(500);
    }

    function test_setFeeBps_invalid_reverts() public {
        vm.prank(owner);
        vm.expectRevert(FeeTreasury.InvalidFeeBps.selector);
        treasury.setFeeBps(10_001);
    }

    function test_setFeeRecipient_byOwner_succeeds() public {
        address newRecipient = address(0xCAFE);

        vm.prank(owner);
        treasury.setFeeRecipient(newRecipient);

        assertEq(treasury.feeRecipient(), newRecipient);
    }

    function test_setFeeRecipient_nonOwner_reverts() public {
        vm.prank(alice);
        vm.expectRevert(Owned.NotOwner.selector);
        treasury.setFeeRecipient(alice);
    }

    function test_setFeeRecipient_zero_reverts() public {
        vm.prank(owner);
        vm.expectRevert(FeeTreasury.InvalidRecipient.selector);
        treasury.setFeeRecipient(address(0));
    }

    function test_quoteFee_correctMath() public view {
        assertEq(treasury.quoteFee(10_000), 250); // 2.5%
        assertEq(treasury.quoteFee(1 ether), (1 ether * 250) / 10_000);
    }

    function test_receive_acceptsNative() public {
        vm.deal(alice, 5 ether);

        vm.prank(alice);
        (bool ok,) = address(treasury).call{value: 2 ether}("");
        assertTrue(ok);

        assertEq(address(treasury).balance, 2 ether);
    }

    function test_withdraw_byOwner_succeeds() public {
        vm.deal(alice, 3 ether);
        vm.prank(alice);
        (bool ok,) = address(treasury).call{value: 3 ether}("");
        assertTrue(ok);

        uint256 beforeBal = recipient.balance;

        vm.prank(owner);
        treasury.withdraw(1 ether);

        assertEq(address(treasury).balance, 2 ether);
        assertEq(recipient.balance, beforeBal + 1 ether);
    }

    function test_withdraw_nonOwner_reverts() public {
        vm.prank(alice);
        vm.expectRevert(Owned.NotOwner.selector);
        treasury.withdraw(1);
    }

    function test_withdraw_insufficientBalance_reverts() public {
        vm.prank(owner);
        vm.expectRevert(FeeTreasury.InsufficientBalance.selector);
        treasury.withdraw(1);
    }

    function test_withdrawAll_byOwner_succeeds() public {
        vm.deal(alice, 4 ether);
        vm.prank(alice);
        (bool ok,) = address(treasury).call{value: 4 ether}("");
        assertTrue(ok);

        uint256 beforeBal = recipient.balance;

        vm.prank(owner);
        treasury.withdrawAll();

        assertEq(address(treasury).balance, 0);
        assertEq(recipient.balance, beforeBal + 4 ether);
    }

    function test_withdrawAll_nonOwner_reverts() public {
        vm.prank(alice);
        vm.expectRevert(Owned.NotOwner.selector);
        treasury.withdrawAll();
    }
}
