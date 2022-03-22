pragma solidity ^0.8.10;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

//main Credit contract
contract XRCCredit is ERC1155{
    bool public contractDebtorStatus= false;  // tells current status of Debtor on contract
    uint public DebtAmmount=0;                // Current Debt Ammount
    address public Debtor;                      
    address public Creditor;


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
    //Creditor can Aproove credit
    function Aproove_Credit()public OnlyCreditor{}
    //Debtor can redeem contract upon approval by Creditor
    function RedeemCredit() OnlyDebtor public {}
    //Debtor can
    function IssuePayment() OnlyDebtor public {} // XDC-Credit must change fromXRC to XDC
    //Debtor
    function KYC()public OnlyDebtor {} // user must enter KYC info to engage with contract

}

 