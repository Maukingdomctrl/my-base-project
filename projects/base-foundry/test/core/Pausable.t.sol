// SPDX-License-Identifier: MIT
pragma solidity >=0.8.35 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {Pausable} from "../../src/core/Pausable.sol";
import {Owned} from "../../src/core/Owned.sol";

contract PausableHarness is Pausable {
    uint256 public value;

    constructor(address initialOwner) Pausable(initialOwner) {}

    function setValue(uint256 newValue) external whenNotPaused {
        value = newValue;
    }

    function setValueWhenPaused(uint256 newValue) external whenPaused {
        value = newValue;
    }
}

contract PausableTest is Test {
    PausableHarness internal p;

    address internal owner = address(0xA11CE);
    address internal alice = address(0xB0B);

    function setUp() public {
        vm.prank(owner);
        p = new PausableHarness(owner);
    }

    function test_initialState_notPaused() public view {
        assertFalse(p.paused());
    }

    function test_pause_byOwner_setsPausedTrue() public {
        vm.prank(owner);
        p.pause();
        assertTrue(p.paused());
    }

    function test_pause_byNonOwner_reverts() public {
        vm.prank(alice);
        vm.expectRevert(Owned.NotOwner.selector);
        p.pause();
    }

    function test_pause_whenAlreadyPaused_reverts() public {
        vm.prank(owner);
        p.pause();

        vm.prank(owner);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        p.pause();
    }

    function test_unpause_byOwner_setsPausedFalse() public {
        vm.startPrank(owner);
        p.pause();
        p.unpause();
        vm.stopPrank();

        assertFalse(p.paused());
    }

    function test_unpause_byNonOwner_reverts() public {
        vm.prank(owner);
        p.pause();

        vm.prank(alice);
        vm.expectRevert(Owned.NotOwner.selector);
        p.unpause();
    }

    function test_unpause_whenNotPaused_reverts() public {
        vm.prank(owner);
        vm.expectRevert(Pausable.ExpectedPause.selector);
        p.unpause();
    }

    function test_whenNotPaused_allowsFunction() public {
        p.setValue(10);
        assertEq(p.value(), 10);
    }

    function test_whenNotPaused_revertsIfPaused() public {
        vm.prank(owner);
        p.pause();

        vm.expectRevert(Pausable.EnforcedPause.selector);
        p.setValue(11);
    }

    function test_whenPaused_allowsFunctionOnlyWhenPaused() public {
        vm.prank(owner);
        p.pause();

        p.setValueWhenPaused(22);
        assertEq(p.value(), 22);
    }

    function test_whenPaused_revertsIfNotPaused() public {
        vm.expectRevert(Pausable.ExpectedPause.selector);
        p.setValueWhenPaused(33);
    }

    function test_pause_emitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit Pausable.PausedStateSet(true);
        p.pause();
    }

    function test_unpause_emitsEvent() public {
        vm.prank(owner);
        p.pause();

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit Pausable.PausedStateSet(false);
        p.unpause();
    }
}
