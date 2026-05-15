// SPDX-License-Identifier: MIT
pragma solidity >=0.8.35 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {ReentrancyGuard} from "../../src/core/ReentrancyGuard.sol";

/*//////////////////////////////////////////////////////////////
                        MOCK CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @dev Minimal concrete implementation for testing
contract MockGuarded is ReentrancyGuard {
    uint256 public counter;
    bool public viewLockSeen;

    // Normal protected function
    function increment() external nonReentrant {
        counter++;
    }

    // Reentrant attacker: calls back into itself
    function reentrantIncrement(address self) external nonReentrant {
        counter++;
        // attempt reentrant call — must revert
        MockGuarded(self).increment();
    }

    // Protected view
    function getCounterSafe() external view nonReentrantView returns (uint256) {
        return counter;
    }

    // Exposes _entered() for testing
    function isEntered() external view returns (bool) {
        return _entered();
    }

    // Calls a view function while inside nonReentrant — read-only reentrancy
    function callViewWhileLocked(address self) external nonReentrant returns (uint256) {
        counter++;
        // attempt read-only reentrant call — must revert
        return MockGuarded(self).getCounterSafe();
    }

    // Two independent nonReentrant calls in sequence (must NOT revert)
    function incrementTwiceSequential() external {
        this.increment();
        this.increment();
    }
}

/// @dev Attacker contract for cross-contract reentrancy
contract Attacker {
    MockGuarded public target;
    uint256 public callCount;

    constructor(address _target) {
        target = MockGuarded(_target);
    }

    // Called by target during nonReentrant — simulates cross-contract attack
    function attack() external {
        callCount++;
        target.increment(); // should revert with ReentrantCall
    }
}

contract CrossContractVictim is ReentrancyGuard {
    Attacker public attacker;
    uint256 public counter;

    function setAttacker(address _attacker) external {
        attacker = Attacker(_attacker);
    }

    function vulnerableFunction() external nonReentrant {
        counter++;
        attacker.attack(); // triggers reentrant call back into increment
    }
}

/*//////////////////////////////////////////////////////////////
                            TEST SUITE
//////////////////////////////////////////////////////////////*/

contract ReentrancyGuardTest is Test {
    MockGuarded internal guarded;
    Attacker internal attacker;
    CrossContractVictim internal victim;

    event ReentrantCall(); // for event checking if added later

    function setUp() public {
        guarded = new MockGuarded();
        attacker = new Attacker(address(guarded));
        victim = new CrossContractVictim();
        victim.setAttacker(address(attacker));
    }

    /*//////////////////////////////////////////////////////////////
                          BASIC FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    function test_increment_normalCall_succeeds() public {
        guarded.increment();
        assertEq(guarded.counter(), 1);
    }

    function test_increment_multipleCalls_accumulatesCorrectly() public {
        guarded.increment();
        guarded.increment();
        guarded.increment();
        assertEq(guarded.counter(), 3);
    }

    function test_sequentialNonReentrantCalls_succeed() public {
        // Two sequential (not nested) nonReentrant calls must not revert
        guarded.incrementTwiceSequential();
        assertEq(guarded.counter(), 2);
    }

    /*//////////////////////////////////////////////////////////////
                        DIRECT REENTRANCY
    //////////////////////////////////////////////////////////////*/

    function test_reentrantCall_self_reverts() public {
        vm.expectRevert(ReentrancyGuard.ReentrantCall.selector);
        guarded.reentrantIncrement(address(guarded));
    }

    function test_reentrantCall_doesNotIncrementCounter() public {
        try guarded.reentrantIncrement(address(guarded)) {} catch {}
        // counter incremented once before revert, then reverted entirely
        assertEq(guarded.counter(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                      CROSS-CONTRACT REENTRANCY
    //////////////////////////////////////////////////////////////*/

    function test_crossContractReentrancy_reverts() public {
        vm.expectRevert(ReentrancyGuard.ReentrantCall.selector);
        victim.vulnerableFunction();
    }

    function test_crossContractReentrancy_attackerCallCountZero() public {
        try victim.vulnerableFunction() {} catch {}
        // entire tx reverted — attacker never successfully called
        assertEq(attacker.callCount(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                       READ-ONLY REENTRANCY
    //////////////////////////////////////////////////////////////*/

    function test_nonReentrantView_normalCall_succeeds() public view {
        uint256 val = guarded.getCounterSafe();
        assertEq(val, 0);
    }

    function test_readOnlyReentrancy_whileLocked_reverts() public {
        vm.expectRevert(ReentrancyGuard.ReentrantCall.selector);
        guarded.callViewWhileLocked(address(guarded));
    }

    /*//////////////////////////////////////////////////////////////
                         _entered() HELPER
    //////////////////////////////////////////////////////////////*/

    function test_entered_beforeCall_isFalse() public view {
        assertFalse(guarded.isEntered());
    }

    function test_entered_afterCall_isFalse() public {
        guarded.increment();
        // lock must be released after call
        assertFalse(guarded.isEntered());
    }

    /*//////////////////////////////////////////////////////////////
                           FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_increment_nTimes_counterMatchesN(uint8 n) public {
        for (uint256 i = 0; i < n; i++) {
            guarded.increment();
        }
        assertEq(guarded.counter(), n);
    }

    function testFuzz_nonReentrantView_alwaysReturnsCorrectCounter(
        uint8 n
    ) public {
        for (uint256 i = 0; i < n; i++) {
            guarded.increment();
        }
        assertEq(guarded.getCounterSafe(), n);
    }

    /*//////////////////////////////////////////////////////////////
                         INVARIANT HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev After any successful call, lock must always be released
    function invariant_lockAlwaysReleased() public view {
        assertFalse(guarded.isEntered());
    }
}
