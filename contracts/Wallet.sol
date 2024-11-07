pragma solidity ^0.8.0;

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
        //check if token exist
        require(tokenMapping[_ticker].ticker == 0, "Token already exists");
        require(
            tokenMapping[_ticker].tokenAddress != _tokenadress,
            "Token already exists"
        );
        //define the new token if non existent
        tokenMapping[_ticker] = Token(_ticker, _tokenadress);
        tokenList.push(_ticker);
    }

    function deposit(bytes32 _ticker, uint256 _amount) external {}

    function withdraw(bytes32 _ticker, uint256 _amount) external {
        //check if the user have enough balance to witdraw
    }
}
