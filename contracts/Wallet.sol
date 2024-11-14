pragma solidity ^0.8.0;

// import the IERC2O interface
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
//import safeMath
import "../node_modules/@openzeppelin/contracts/utils/math/Math.sol";
//import Owernable.sol
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";

contract Wallet is Ownable(msg.sender) {
    // define token struct with token name and address
    struct Token {
        bytes32 ticker;
        address tokenAddress;
    }
    /*
    keep balances of user. 
    using double mapping to keep track of differnt assets
    */
    mapping(address => mapping(bytes32 => uint256)) public balances;

    // define a token list to store all supported tokens.
    bytes32[] public tokenList;

    // define a token mapping to fetch token
    mapping(bytes32 => Token) public tokenMapping;

    // event is emitted each time a  withdraw happens
    event withdrawal(
        address indexed _to,
        bytes32 _ticker,
        uint256 indexed _amount
    );

    modifier tokenExist(bytes32 _ticker) {
        //check if token exist
        require(
            tokenMapping[_ticker].tokenAddress != address(0),
            "Token does not exist"
        );
        _;
    }

    modifier hasEnoughBalance(uint256 _amount, bytes32 _ticker) {
        //check if the user have enough balance to witdraw
        require(
            balances[msg.sender][_ticker] >= _amount,
            "Balance not sufficient"
        );
        _;
    }

    function addToken(
        bytes32 _ticker,
        address _tokenadress
    ) external onlyOwner {
        require(
            tokenMapping[_ticker].tokenAddress != _tokenadress,
            "Token already exists"
        );
        //define the new token if non existent
        tokenMapping[_ticker] = Token(_ticker, _tokenadress);
        tokenList.push(_ticker);
    }

    /**
     *
     * deposit  _amount of Token named by _ticker into the DEX
     * make call of the tranferfrom function of Token contract
     * requirements
     * Dex needs to receive approval from User in Token Contract
     */
    function deposit(
        bytes32 _ticker,
        uint256 _amount
    ) external tokenExist(_ticker) {
        IERC20 MTK = IERC20(tokenMapping[_ticker].tokenAddress);
        require(MTK.balanceOf(msg.sender) >= _amount, "no enough token");
        uint256 _currentbalance = balances[msg.sender][_ticker];
        (bool success, uint newBalance) = Math.tryAdd(_currentbalance, _amount);
        if (success) {
            balances[msg.sender][_ticker] = newBalance;
            MTK.transferFrom(msg.sender, address(this), _amount);
        }
    }

    /**
     * withdraw _amount from this wallet to msg.sender balances into ERC20 Token contract
     * requirements
     * balance of msg.sender must be greater than or equal to _amount
     * make call of transfer function in ERC20 token contract to transfer from this wallet address to msg.sender address
     */

    function withdraw(
        bytes32 _ticker,
        uint256 _amount
    ) external tokenExist(_ticker) hasEnoughBalance(_amount, _ticker) {
        uint256 _actualBalance = balances[msg.sender][_ticker];
        // using Math library to avoid overflow
        (bool sucess, uint256 newBalance) = Math.trySub(
            _actualBalance,
            _amount
        );

        // if no overflow adjust balances
        if (sucess) {
            balances[msg.sender][_ticker] = newBalance;
            IERC20(tokenMapping[_ticker].tokenAddress).transfer(
                msg.sender,
                _amount
            );
        }
    }
}
