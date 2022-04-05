pragma solidity ^0.8.10;
// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SimpleToken is ERC20 {
    constructor(string memory name,string memory symbol,uint256 initialSupply) public ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}
//main Credit contract
contract XRCCredit is ERC1155{
    bool public contractDebtorStatus= false;  // tells current status of Debtor on contract
    uint public DebtAmmount=0;                // Current Debt Ammount
    address public Debtor;                      
    address public Creditor;
    bool public acceptStatus;

    uint256 public constant CreditContractToken = 0;
    constructor(string memory URI,uint DebtAmmount,address Debtor, address Creditor) public ERC1155(URI){
        _mint(msg.sender, CreditContractToken, 1, "");
    }
    modifier OnlyCreditor{
        require(1 == balanceOf(msg.sender,CreditContractToken));
        _;
    }
    modifier OnlyDebtor{
        require(msg.sender == Debtor);
        _;
    }
    modifier ContractAprooveStatus{
        require(acceptStatus == true);
        _;
    } 
    //Creditor can Aproove credit
    function Aproove_Credit(bool _status)public OnlyCreditor returns(bool){
        acceptStatus == _status;
        return _status;
    }
    //Debtor can redeem contract upon approval by Creditor
    function RedeemCredit() OnlyDebtor ContractAprooveStatus public {}
    //Debtor can Issue Payments to contract
    function IssuePayment() OnlyDebtor public {} // XDC-Credit must change fromXRC to XDC
    //Debtor can File KYC info to get Aprooved
    function KYC()public OnlyDebtor {} // user must enter KYC info to engage with contract
}