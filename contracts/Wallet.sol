pragma solidity ^0.8.0;

// import the IERC2O interface
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

//import safeMath
import "../node_modules/@openzeppelin/contracts/utils/math/Math.sol";

contract Wallet {
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
    mapping(bytes32 => Token) tokenMapping;

    // event is emitted each time a  withdraw happens
    event withdrawal(
        address indexed _to,
        bytes32 _ticker,
        uint256 indexed _amount
    );

    function addToken(address _tokenadress, bytes32 _ticker) external {
        require(
            tokenMapping[_ticker].tokenAddress != _tokenadress,
            "Token already exists"
        );
        //define the new token if non existent
        tokenMapping[_ticker] = Token(_ticker, _tokenadress);
        tokenList.push(_ticker);
    }

    function deposit(bytes32 _ticker, uint256 _amount) external {}

    /**
     * withdraw _amount from this wallet to msg.sender balances into ERC20 Token contract
     * requirements
     * balance of msg.sender must be greater than or equal to _amount
     * make call of transfer function in ERC20 token contract to transfer from this wallet address to msg.sender address
     */

    function withdraw(bytes32 _ticker, uint256 _amount) external {
        //check if token exist
        require(
            tokenMapping[_ticker].tokenAddress != address(0),
            "Token does not exist"
        );
        //check if the user have enough balance to witdraw
        require(
            balances[msg.sender][_ticker] >= _amount,
            "Balance not sufficient"
        );

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
