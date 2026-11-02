// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/XRC-Credit.sol";

/// XRC-Credit is a skeleton. These tests pin what it does today.
contract CreditTest is Test {
    address creditor = makeAddr("creditor");
    address debtor = makeAddr("debtor");
    XRCCredit credit;

    function setUp() public {
        vm.prank(creditor);
        credit = new XRCCredit("uri", 100, debtor, creditor);
    }

    function test_DeployerHoldsTheCreditToken() public {
        assertEq(credit.balanceOf(creditor, 0), 1);
    }

    function test_KnownIssue_ConstructorArgumentsAreNotStored() public {
        assertEq(credit.DebtAmmount(), 0);
        assertEq(credit.Debtor(), address(0));
        assertEq(credit.Creditor(), address(0));
    }

    function test_KnownIssue_ApprovalDoesNotChangeState() public {
        vm.prank(creditor);
        assertTrue(credit.Aproove_Credit(true));
        assertFalse(credit.acceptStatus());
    }

    function test_KnownIssue_TheNamedDebtorIsLockedOut() public {
        vm.prank(debtor);
        vm.expectRevert();
        credit.IssuePayment();
    }
}
