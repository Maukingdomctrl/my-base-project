// SPDX-License-Identifier: MIT
pragma solidity >=0.8.35 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {BountyEscrow} from "../../src/bounty/BountyEscrow.sol";
import {Owned} from "../../src/core/Owned.sol";
import {Pausable} from "../../src/core/Pausable.sol";

contract BountyEscrowTest is Test {
    BountyEscrow internal escrow;

    address internal owner = address(0xA11CE);
    address internal sponsor = address(0xB0B);
    address internal hunter = address(0xCAFE);
    address internal alice = address(0xD00D);

    function setUp() public {
        vm.prank(owner);
        escrow = new BountyEscrow(owner, sponsor, hunter);
    }

    function test_constructor_setsState() public view {
        assertEq(escrow.owner(), owner);
        assertEq(escrow.sponsor(), sponsor);
        assertEq(escrow.hunter(), hunter);
        assertEq(uint256(escrow.state()), uint256(BountyEscrow.State.Created));
        assertEq(escrow.fundedAmount(), 0);
    }

    function test_constructor_zeroAddress_reverts() public {
        vm.expectRevert(BountyEscrow.InvalidAddress.selector);
        new BountyEscrow(owner, address(0), hunter);

        vm.expectRevert(BountyEscrow.InvalidAddress.selector);
        new BountyEscrow(owner, sponsor, address(0));
    }

    function test_constructor_sameSponsorHunter_reverts() public {
        vm.expectRevert(BountyEscrow.InvalidAddress.selector);
        new BountyEscrow(owner, sponsor, sponsor);
    }

    function test_fund_bySponsor_succeeds() public {
        vm.deal(sponsor, 2 ether);

        vm.prank(sponsor);
        escrow.fund{value: 2 ether}();

        assertEq(escrow.fundedAmount(), 2 ether);
        assertEq(uint256(escrow.state()), uint256(BountyEscrow.State.Funded));
        assertEq(address(escrow).balance, 2 ether);
    }

    function test_fund_nonSponsor_reverts() public {
        vm.deal(alice, 1 ether);

        vm.prank(alice);
        vm.expectRevert(BountyEscrow.Unauthorized.selector);
        escrow.fund{value: 1 ether}();
    }

    function test_fund_zeroAmount_reverts() public {
        vm.prank(sponsor);
        vm.expectRevert(BountyEscrow.ZeroAmount.selector);
        escrow.fund{value: 0}();
    }

    function test_fund_twice_reverts() public {
        vm.deal(sponsor, 2 ether);

        vm.prank(sponsor);
        escrow.fund{value: 1 ether}();

        vm.prank(sponsor);
        vm.expectRevert(BountyEscrow.InvalidState.selector);
        escrow.fund{value: 1 ether}();
    }

    function test_release_bySponsor_sendsToHunter() public {
        vm.deal(sponsor, 3 ether);

        vm.prank(sponsor);
        escrow.fund{value: 3 ether}();

        uint256 hunterBefore = hunter.balance;

        vm.prank(sponsor);
        escrow.release();

        assertEq(hunter.balance, hunterBefore + 3 ether);
        assertEq(address(escrow).balance, 0);
        assertEq(escrow.fundedAmount(), 0);
        assertEq(uint256(escrow.state()), uint256(BountyEscrow.State.Released));
    }

    function test_release_byOwner_succeeds() public {
        vm.deal(sponsor, 1 ether);

        vm.prank(sponsor);
        escrow.fund{value: 1 ether}();

        vm.prank(owner);
        escrow.release();

        assertEq(uint256(escrow.state()), uint256(BountyEscrow.State.Released));
    }

    function test_release_unauthorized_reverts() public {
        vm.prank(alice);
        vm.expectRevert(BountyEscrow.Unauthorized.selector);
        escrow.release();
    }

    function test_release_invalidState_reverts() public {
        vm.prank(sponsor);
        vm.expectRevert(BountyEscrow.InvalidState.selector);
        escrow.release();
    }

    function test_refund_bySponsor_sendsBackToSponsor() public {
        vm.deal(sponsor, 4 ether);

        vm.prank(sponsor);
        escrow.fund{value: 4 ether}();

        uint256 sponsorBefore = sponsor.balance;

        vm.prank(sponsor);
        escrow.refund();

        assertEq(sponsor.balance, sponsorBefore + 4 ether);
        assertEq(address(escrow).balance, 0);
        assertEq(escrow.fundedAmount(), 0);
        assertEq(uint256(escrow.state()), uint256(BountyEscrow.State.Refunded));
    }

    function test_refund_byOwner_succeeds() public {
        vm.deal(sponsor, 1 ether);

        vm.prank(sponsor);
        escrow.fund{value: 1 ether}();

        vm.prank(owner);
        escrow.refund();

        assertEq(uint256(escrow.state()), uint256(BountyEscrow.State.Refunded));
    }

    function test_cancel_beforeFunding_bySponsor_succeeds() public {
        vm.prank(sponsor);
        escrow.cancel();

        assertEq(uint256(escrow.state()), uint256(BountyEscrow.State.Cancelled));
    }

    function test_cancel_beforeFunding_byOwner_succeeds() public {
        vm.prank(owner);
        escrow.cancel();

        assertEq(uint256(escrow.state()), uint256(BountyEscrow.State.Cancelled));
    }

    function test_cancel_afterFunding_reverts() public {
        vm.deal(sponsor, 1 ether);
        vm.prank(sponsor);
        escrow.fund{value: 1 ether}();

        vm.prank(sponsor);
        vm.expectRevert(BountyEscrow.InvalidState.selector);
        escrow.cancel();
    }

    function test_pause_blocksFundReleaseRefundCancel() public {
        vm.prank(owner);
        escrow.pause();

        vm.deal(sponsor, 1 ether);
        vm.prank(sponsor);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        escrow.fund{value: 1 ether}();

        // Deploy fresh funded escrow to test release/refund/cancel while paused
        vm.prank(owner);
        BountyEscrow e2 = new BountyEscrow(owner, sponsor, hunter);
        vm.deal(sponsor, 1 ether);
        vm.prank(sponsor);
        e2.fund{value: 1 ether}();

        vm.prank(owner);
        e2.pause();

        vm.prank(owner);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        e2.release();

        vm.prank(owner);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        e2.refund();

        vm.prank(owner);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        e2.cancel();
    }

    function test_unpause_restoresFlow() public {
        vm.prank(owner);
        escrow.pause();

        vm.prank(owner);
        escrow.unpause();

        vm.deal(sponsor, 1 ether);
        vm.prank(sponsor);
        escrow.fund{value: 1 ether}();

        vm.prank(owner);
        escrow.release();

        assertEq(uint256(escrow.state()), uint256(BountyEscrow.State.Released));
    }
}
