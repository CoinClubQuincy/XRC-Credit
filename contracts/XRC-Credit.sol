pragma solidity ^0.8.10;
// SPDX-License-Identifier: MIT

//import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
//IERC1155 interface
interface IERC1155 is IERC165 {
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);

    function balanceOf(address account, uint256 id) external view returns (uint256);
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address account, address operator) external view returns (bool);

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}


//main Credit contract
contract XRCCredit is ERC1155,IERC1155{
    bool public contractDebtorStatus= false;  // tells current status of Debtor on contract
    uint public DebtAmmount=0;                // Current Debt Ammount
    address public Debtor;                      
    address public Creditor;


    uint256 public constant CreditContractToken = 0;
    constructor(string memory URI,uint DebtAmmount,address Debtor, address Creditor) public ERC1155(URI){
        _mint(msg.sender, CreditContractToken, 1, "");

    }

modifier OnlyCreditor{
    require(msg.sender == balanceOf(CreditContractToken,1));
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

