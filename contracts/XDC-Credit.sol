pragma solidity ^0.8.10;
// SPDX-License-Identifier: MIT
import "./CreditBase.sol";

//Credit paid and repaid in XDC. FundCredit and IssuePayment must send the exact amount.
contract XDCCredit is CreditBase{
    constructor(string memory URI,uint _principal,uint _interestBps,address _debtor,address _creditor)
        CreditBase(URI,_principal,_interestBps,_debtor,_creditor){}

    function _collect(uint _amount) internal override{
        require(msg.value == _amount, "send the exact amount");
    }
    function _send(address _to,uint _amount) internal override{
        (bool success, ) = payable(_to).call{value: _amount}("");
        require(success, "payment failed");
    }
}
