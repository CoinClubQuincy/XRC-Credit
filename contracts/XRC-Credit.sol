pragma solidity ^0.8.10;
// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./CreditBase.sol";

contract SimpleToken is ERC20 {
    constructor(string memory name,string memory symbol,uint256 initialSupply) public ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}
//Credit paid and repaid in an XRC-20 token. The caller must approve this contract first.
contract XRCCredit is CreditBase{
    using SafeERC20 for IERC20;

    IERC20 public immutable Token;

    constructor(string memory URI,uint _principal,uint _interestBps,address _debtor,address _creditor,address _token)
        CreditBase(URI,_principal,_interestBps,_debtor,_creditor){
        require(_token != address(0), "token is required");
        Token = IERC20(_token);
    }
    function _collect(uint _amount) internal override{
        require(msg.value == 0, "this credit does not take XDC");
        uint before = Token.balanceOf(address(this));
        Token.safeTransferFrom(msg.sender,address(this),_amount);
        require(Token.balanceOf(address(this)) - before == _amount, "tokens that take a fee are not supported");
    }
    function _send(address _to,uint _amount) internal override{
        Token.safeTransfer(_to,_amount);
    }
}
