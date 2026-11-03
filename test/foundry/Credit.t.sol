// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/XRC-Credit.sol";
import "../../contracts/XDC-Credit.sol";

/// Tests here run against both the XRC-20 and the XDC variant.
abstract contract CreditTests is Test {
    address creditor = makeAddr("creditor");
    address debtor = makeAddr("debtor");
    address buyer = makeAddr("buyer");
    address stranger = makeAddr("stranger");
    CreditBase credit;
    uint constant PRINCIPAL = 100 ether;
    uint constant OWED = 110 ether;
    bytes32 constant DOC = keccak256("salted documents");

    function deployCredit(uint principal, uint bps) internal virtual returns (CreditBase);
    function give(address who, uint amount) internal virtual;
    function holdings(address who) internal view virtual returns (uint);
    function fund(address from) internal virtual;
    function repay(address from, uint amount) internal virtual;

    function setUp() public virtual {
        credit = deployCredit(PRINCIPAL, 1000);
        give(creditor, 1000 ether);
        give(debtor, 1000 ether);
    }

    function toApproved() internal {
        fund(creditor);
        vm.prank(debtor);
        credit.KYC(DOC);
        vm.prank(creditor);
        credit.Aproove_Credit(true);
    }

    function toActive() internal {
        toApproved();
        vm.prank(debtor);
        credit.RedeemCredit();
    }

    function test_CreditorHoldsTheCreditTokenAndTermsAreStored() public {
        assertEq(credit.balanceOf(creditor, 0), 1);
        assertEq(credit.Principal(), PRINCIPAL);
        assertEq(credit.InterestBps(), 1000);
        assertEq(credit.DebtAmmount(), OWED);
        assertEq(credit.Debtor(), debtor);
        assertEq(credit.Creditor(), creditor);
        assertEq(uint(credit.state()), uint(CreditBase.State.Created));
    }

    function test_FullLoanFromFundingToProofOfPayment() public {
        uint creditorStart = holdings(creditor);
        uint debtorStart = holdings(debtor);
        toActive();
        assertEq(holdings(debtor), debtorStart + PRINCIPAL);
        repay(debtor, 60 ether);
        assertEq(credit.DebtAmmount(), 50 ether);
        assertEq(uint(credit.state()), uint(CreditBase.State.Active));
        assertEq(credit.balanceOf(debtor, 1), 0);
        repay(debtor, 50 ether);
        assertEq(uint(credit.state()), uint(CreditBase.State.Repaid));
        assertEq(credit.balanceOf(debtor, 1), 1);
        vm.prank(creditor);
        credit.WithdrawPayments();
        assertEq(holdings(creditor), creditorStart + 10 ether);
        assertEq(holdings(debtor), debtorStart - 10 ether);
        assertEq(holdings(address(credit)), 0);
    }

    function test_OnlyTheCreditorCanFundApproveWithdrawAndCancel() public {
        vm.startPrank(stranger);
        vm.expectRevert("only the holder of the credit token");
        credit.FundCredit();
        vm.expectRevert("only the holder of the credit token");
        credit.Aproove_Credit(true);
        vm.expectRevert("only the holder of the credit token");
        credit.WithdrawPayments();
        vm.expectRevert("only the holder of the credit token");
        credit.CancelCredit();
        vm.stopPrank();
    }

    function test_OnlyTheDebtorCanFileRedeemAndPay() public {
        vm.startPrank(stranger);
        vm.expectRevert("only the debtor");
        credit.KYC(DOC);
        vm.expectRevert("only the debtor");
        credit.RedeemCredit();
        vm.expectRevert("only the debtor");
        credit.IssuePayment(1);
        vm.stopPrank();
    }

    function test_KYCStoresOnlyAHash() public {
        vm.prank(debtor);
        credit.KYC(DOC);
        assertEq(credit.documentHash(), DOC);
        assertTrue(credit.contractDebtorStatus());
        vm.prank(debtor);
        vm.expectRevert("document hash is required");
        credit.KYC(bytes32(0));
    }

    function test_ApprovalNeedsFundingAndKYC() public {
        vm.prank(creditor);
        vm.expectRevert("credit must be funded");
        credit.Aproove_Credit(true);
        fund(creditor);
        vm.prank(creditor);
        vm.expectRevert("debtor must file KYC");
        credit.Aproove_Credit(true);
    }

    function test_ApprovalChangesStateAndCanBeWithdrawn() public {
        toApproved();
        assertTrue(credit.acceptStatus());
        vm.prank(creditor);
        credit.Aproove_Credit(false);
        assertFalse(credit.acceptStatus());
        vm.prank(debtor);
        vm.expectRevert("credit is not approved");
        credit.RedeemCredit();
    }

    function test_CannotFundTwice() public {
        fund(creditor);
        vm.prank(creditor);
        vm.expectRevert("credit is already funded");
        credit.FundCredit();
    }

    function test_DebtorRedeemsOnlyOnce() public {
        toActive();
        vm.prank(debtor);
        vm.expectRevert("credit is not approved");
        credit.RedeemCredit();
    }

    function test_CannotPayBeforeRedeeming() public {
        toApproved();
        vm.prank(debtor);
        vm.expectRevert("credit is not active");
        credit.IssuePayment(1);
    }

    function test_OverpaymentIsRefused() public {
        toActive();
        vm.prank(debtor);
        vm.expectRevert("payment is more than the debt");
        credit.IssuePayment(OWED + 1);
    }

    function test_CannotPayAfterRepaid() public {
        toActive();
        repay(debtor, OWED);
        vm.prank(debtor);
        vm.expectRevert("credit is not active");
        credit.IssuePayment(1);
    }

    function test_SellingTheDebtMovesTheRepayments() public {
        toActive();
        repay(debtor, 10 ether);
        vm.prank(creditor);
        credit.safeTransferFrom(creditor, buyer, 0, 1, "");
        uint before = holdings(buyer);
        repay(debtor, 100 ether);
        vm.prank(creditor);
        vm.expectRevert("only the holder of the credit token");
        credit.WithdrawPayments();
        vm.prank(buyer);
        credit.WithdrawPayments();
        assertEq(holdings(buyer), before + OWED);
    }

    function test_WithdrawTwiceFails() public {
        toActive();
        repay(debtor, 10 ether);
        vm.startPrank(creditor);
        credit.WithdrawPayments();
        vm.expectRevert("nothing to withdraw");
        credit.WithdrawPayments();
        vm.stopPrank();
    }

    function test_CancelRefundsTheFunding() public {
        uint before = holdings(creditor);
        toApproved();
        vm.prank(creditor);
        credit.CancelCredit();
        assertEq(holdings(creditor), before);
        assertEq(uint(credit.state()), uint(CreditBase.State.Cancelled));
        vm.prank(debtor);
        vm.expectRevert("credit is not approved");
        credit.RedeemCredit();
    }

    function test_CancelBeforeFundingSendsNothing() public {
        uint before = holdings(creditor);
        vm.prank(creditor);
        credit.CancelCredit();
        assertEq(holdings(creditor), before);
        vm.prank(creditor);
        vm.expectRevert("credit can no longer be cancelled");
        credit.CancelCredit();
    }

    function test_CannotCancelAfterRedemption() public {
        toActive();
        vm.prank(creditor);
        vm.expectRevert("credit can no longer be cancelled");
        credit.CancelCredit();
    }

    function testFuzz_MoneyInEqualsMoneyOut(uint64 principal, uint16 bps, uint64 first) public {
        vm.assume(principal > 0);
        CreditBase c = deployCredit(principal, bps);
        credit = c;
        give(creditor, uint(principal) * 8);
        give(debtor, uint(principal) * 8);
        uint total = holdings(creditor) + holdings(debtor);
        uint owed = c.DebtAmmount();
        toActive();
        uint part = bound(first, 1, owed);
        repay(debtor, part);
        assertEq(holdings(address(c)), part);
        if (part < owed) repay(debtor, owed - part);
        vm.prank(creditor);
        c.WithdrawPayments();
        assertEq(holdings(address(c)), 0);
        assertEq(holdings(creditor) + holdings(debtor), total);
        assertEq(c.balanceOf(debtor, 1), 1);
        assertEq(c.DebtAmmount(), 0);
    }
}

contract XRCCreditTest is CreditTests {
    SimpleToken token;

    function deployCredit(uint principal, uint bps) internal override returns (CreditBase) {
        if (address(token) == address(0)) token = new SimpleToken("Tok", "TOK", 0);
        return new XRCCredit("uri", principal, bps, debtor, creditor, address(token));
    }
    function give(address who, uint amount) internal override {
        deal(address(token), who, token.balanceOf(who) + amount, true);
    }
    function holdings(address who) internal view override returns (uint) {
        return token.balanceOf(who);
    }
    function fund(address from) internal override {
        vm.startPrank(from);
        token.approve(address(credit), type(uint).max);
        credit.FundCredit();
        vm.stopPrank();
    }
    function repay(address from, uint amount) internal override {
        vm.startPrank(from);
        token.approve(address(credit), type(uint).max);
        credit.IssuePayment(amount);
        vm.stopPrank();
    }

    function test_ConstructorRejectsBadTerms() public {
        vm.expectRevert("principal is required");
        new XRCCredit("uri", 0, 0, debtor, creditor, address(token));
        vm.expectRevert("debtor is required");
        new XRCCredit("uri", 1, 0, address(0), creditor, address(token));
        vm.expectRevert("creditor is required");
        new XRCCredit("uri", 1, 0, debtor, address(0), address(token));
        vm.expectRevert("debtor and creditor must differ");
        new XRCCredit("uri", 1, 0, debtor, debtor, address(token));
        vm.expectRevert("token is required");
        new XRCCredit("uri", 1, 0, debtor, creditor, address(0));
    }

    function test_RefusesXDCOnATokenCredit() public {
        vm.deal(creditor, 1 ether);
        vm.startPrank(creditor);
        token.approve(address(credit), type(uint).max);
        vm.expectRevert("this credit does not take XDC");
        credit.FundCredit{value: 1 ether}();
        vm.stopPrank();
    }
}

contract XDCCreditTest is CreditTests {
    function deployCredit(uint principal, uint bps) internal override returns (CreditBase) {
        return new XDCCredit("uri", principal, bps, debtor, creditor);
    }
    function give(address who, uint amount) internal override {
        vm.deal(who, who.balance + amount);
    }
    function holdings(address who) internal view override returns (uint) {
        return who.balance;
    }
    function fund(address from) internal override {
        uint principal = credit.Principal();
        vm.prank(from);
        credit.FundCredit{value: principal}();
    }
    function repay(address from, uint amount) internal override {
        vm.prank(from);
        credit.IssuePayment{value: amount}(amount);
    }

    function test_WrongAmountIsRefused() public {
        vm.prank(creditor);
        vm.expectRevert("send the exact amount");
        credit.FundCredit{value: 1 ether}();
        toActive();
        vm.prank(debtor);
        vm.expectRevert("send the exact amount");
        credit.IssuePayment{value: 1 ether}(2 ether);
    }

    function test_ReentrantDebtorCannotRedeemTwice() public {
        ReentrantParty party = new ReentrantParty();
        XDCCredit c = new XDCCredit("uri", 10 ether, 0, address(party), creditor);
        vm.deal(creditor, 10 ether);
        vm.prank(creditor);
        c.FundCredit{value: 10 ether}();
        party.fileKYC(c);
        vm.prank(creditor);
        c.Aproove_Credit(true);
        party.redeem(c);
        assertTrue(party.attempted());
        assertFalse(party.reentered());
        assertEq(address(party).balance, 10 ether);
        assertEq(address(c).balance, 0);
    }

    function test_ReentrantCreditorCannotWithdrawTwice() public {
        ReentrantParty party = new ReentrantParty();
        toActive();
        repay(debtor, 10 ether);
        vm.prank(creditor);
        credit.safeTransferFrom(creditor, address(party), 0, 1, "");
        party.withdraw(credit);
        assertTrue(party.attempted());
        assertFalse(party.reentered());
        assertEq(address(party).balance, 10 ether);
    }
}

contract ReentrantParty {
    CreditBase target;
    bool withdrawing;
    bool public attempted;
    bool public reentered;

    function fileKYC(CreditBase c) external { c.KYC(keccak256("doc")); }

    function redeem(CreditBase c) external {
        target = c;
        c.RedeemCredit();
    }

    function withdraw(CreditBase c) external {
        target = c;
        withdrawing = true;
        c.WithdrawPayments();
    }

    receive() external payable {
        attempted = true;
        if (withdrawing) {
            try target.WithdrawPayments() { reentered = true; } catch {}
        } else {
            try target.RedeemCredit() { reentered = true; } catch {}
        }
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}
