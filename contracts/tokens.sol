pragma solidity ^0.8.0;

// import the IERC2O interface
import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MTK is ERC20 {
    constructor() ERC20("mytoken", "MTK") {
        _mint(msg.sender, 1000);
    }
}
