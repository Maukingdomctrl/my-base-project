// SPDX-License-Identifier: MIT
pragma solidity >=0.8.35 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {ReentrancyGuard} from "../../src/core/ReentrancyGuard.sol";

contract MockGuarded is ReentrancyGuard {
    uint256 public counter;

    function increment() external nonReentrant {
        counter++;
    }

    // Reenter by making an external call to self while lock is active
    function reentrantIncrement() external nonReentrant {
        counter++;
        this.increment(); // should revert with ReentrantCall
    }

    // Sequential calls (not nested) should succeed
    function incrementTwiceSequential() external {
        this.increment();
        this.increment();
    }
}

contract CrossVictim is ReentrancyGuard {
    uint256 public counter;
    address public attacker;

    function setAttacker(address _attacker) external {
        attacker = _attacker;
    }

    function increment() external nonReentrant {
        counter++;
    }

    function vulnerableFunction() external nonReentrant {
        counter++;
        (bool ok,) = attacker.call(abi.encodeWithSignature("attack()"));
        require(ok, "attack failed");
    }
}

contract Attacker {
    CrossVictim public victim;
    uint256 public callCount;

    constructor(address _victim) {
        victim = CrossVictim(_victim);
    }

    function attack() external {
        callCount++;
        victim.increment(); // should revert with ReentrantCall
    }
}

contract ReentrancyGuardTest is Test {
    MockGuarded internal guarded;
    CrossVictim internal victim;
    Attacker internal attacker;

    function setUp() public {
        guarded = new MockGuarded();
        victim = new CrossVictim();
        attacker = new Attacker(address(victim));
        victim.setAttacker(address(attacker));
    }

    function test_increment_succeeds() public {
        guarded.increment();
        assertEq(guarded.counter(), 1);
    }

    function test_incrementTwiceSequential_succeeds() public {
        guarded.incrementTwiceSequential();
        assertEq(guarded.counter(), 2);
    }

    function test_reentrantCall_self_reverts() public {
        vm.expectRevert(ReentrancyGuard.ReentrantCall.selector);
        guarded.reentrantIncrement();
    }

    function test_crossContractReentrancy_reverts() public {
        vm.expectRevert(bytes("attack failed"));
        victim.vulnerableFunction();
    }

    function testFuzz_increment_nTimes(uint8 n) public {
        for (uint256 i = 0; i < n; i++) {
            guarded.increment();
        }
        assertEq(guarded.counter(), n);
    }
}
