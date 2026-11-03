pragma solidity ^0.8.10;
// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title A single loan between a creditor and a debtor
/// @notice Proof of concept. There is no default handling, collateral or late penalty. If the
/// debtor stops paying, this contract does nothing about it.
/// @dev Token 0 is the debt. Whoever holds it acts as the creditor and receives the repayments,
/// so the debt can be sold. Token 1 is minted to the debtor once the debt is repaid.
abstract contract CreditBase is ERC1155, ReentrancyGuard {
    enum State { Created, Funded, Approved, Active, Repaid, Cancelled }

    uint256 public constant CreditContractToken = 0;
    uint256 public constant PaidToken = 1;

    State public state = State.Created;
    bool public contractDebtorStatus = false;  // true once the debtor has filed KYC
    bool public acceptStatus = false;          // true while the creditor approves the debtor
    bytes32 public documentHash;               // hash of the debtor's documents, never the documents
    uint public DebtAmmount;                   // what the debtor still owes
    uint public PaymentsHeld = 0;              // repayments waiting for the holder of token 0
    uint public immutable Principal;
    uint public immutable InterestBps;         // flat interest in hundredths of a percent
    address public immutable Debtor;
    address public immutable Creditor;         // the original creditor. Token 0 may have moved since

    event Funded(address indexed _by, uint _amount);
    event Filed(bytes32 _documentHash);
    event Approval(bool _status);
    event Redeemed(uint _amount);
    event Payment(uint _amount, uint _remaining);
    event Withdrawn(address indexed _to, uint _amount);
    event Cancelled(uint _refunded);

    constructor(string memory URI,uint _principal,uint _interestBps,address _debtor,address _creditor) ERC1155(URI){
        require(_principal > 0, "principal is required");
        require(_debtor != address(0), "debtor is required");
        require(_creditor != address(0), "creditor is required");
        require(_debtor != _creditor, "debtor and creditor must differ");
        Principal = _principal;
        InterestBps = _interestBps;
        Debtor = _debtor;
        Creditor = _creditor;
        DebtAmmount = _principal + (_principal * _interestBps) / 10000;
        _mint(_creditor, CreditContractToken, 1, "");
    }
    modifier OnlyCreditor{
        require(balanceOf(msg.sender,CreditContractToken) == 1, "only the holder of the credit token");
        _;
    }
    modifier OnlyDebtor{
        require(msg.sender == Debtor, "only the debtor");
        _;
    }
    /// @dev takes exactly _amount from the caller, or reverts
    function _collect(uint _amount) internal virtual;
    /// @dev sends _amount to _to, or reverts
    function _send(address _to,uint _amount) internal virtual;

    //Creditor puts up the loan. It stays here until the debtor redeems it or the credit is cancelled
    function FundCredit() public payable OnlyCreditor nonReentrant {
        require(state == State.Created, "credit is already funded");
        state = State.Funded;
        emit Funded(msg.sender,Principal);
        _collect(Principal);
    }
    //Debtor files a hash of their documents. The documents themselves stay off-chain
    function KYC(bytes32 _documentHash) public OnlyDebtor {
        require(_documentHash != bytes32(0), "document hash is required");
        require(state == State.Created || state == State.Funded, "KYC is closed");
        documentHash = _documentHash;
        contractDebtorStatus = true;
        emit Filed(_documentHash);
    }
    //Creditor can Aproove credit once it is funded and KYC is filed, or withdraw that approval
    function Aproove_Credit(bool _status) public OnlyCreditor returns(bool){
        if(_status){
            require(state == State.Funded, "credit must be funded");
            require(contractDebtorStatus, "debtor must file KYC");
            state = State.Approved;
        } else {
            require(state == State.Approved, "credit is not approved");
            state = State.Funded;
        }
        acceptStatus = _status;
        emit Approval(_status);
        return _status;
    }
    //Debtor receives the loan once, after approval
    function RedeemCredit() public OnlyDebtor nonReentrant {
        require(state == State.Approved, "credit is not approved");
        state = State.Active;
        emit Redeemed(Principal);
        _send(Debtor,Principal);
    }
    //Debtor repays. Paying more than is owed is refused. The final payment mints the paid token
    function IssuePayment(uint _amount) public payable OnlyDebtor nonReentrant {
        require(state == State.Active, "credit is not active");
        require(_amount > 0, "amount is required");
        require(_amount <= DebtAmmount, "payment is more than the debt");
        DebtAmmount -= _amount;
        PaymentsHeld += _amount;
        emit Payment(_amount,DebtAmmount);
        if(DebtAmmount == 0){
            state = State.Repaid;
        }
        _collect(_amount);
        if(DebtAmmount == 0){
            _mint(Debtor,PaidToken,1,"");
        }
    }
    //Whoever holds the credit token now collects the repayments made so far
    function WithdrawPayments() public OnlyCreditor nonReentrant {
        uint amount = PaymentsHeld;
        require(amount > 0, "nothing to withdraw");
        PaymentsHeld = 0;
        emit Withdrawn(msg.sender,amount);
        _send(msg.sender,amount);
    }
    //Creditor can call it off before the debtor redeems, and any funding comes back
    function CancelCredit() public OnlyCreditor nonReentrant {
        require(state == State.Created || state == State.Funded || state == State.Approved, "credit can no longer be cancelled");
        bool funded = state != State.Created;
        state = State.Cancelled;
        acceptStatus = false;
        emit Cancelled(funded ? Principal : 0);
        if(funded){
            _send(msg.sender,Principal);
        }
    }
}
