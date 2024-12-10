pragma solidity ^0.8.0;

import "./Wallet.sol";

contract Dex is Wallet {
    // Enum that describe wheter the order is a SELL or BUY order
    enum Side {
        BUY,
        SELL
    }

     struct Trader {
        address account ;
        uint256 share;
    }

    /**
     *  Order Struct used to describe an order
     *
     */
    struct Order {
        uint id;
        uint position;
        Side side;
        bytes32 ticker;
        uint256 amount;
        uint256 price; 
        bool filled;
    }

    /**
    * used to track the share a trader have in each order
    *
    *
    **/
    struct Ordermap{
        Trader[] traders;
        mapping(address => uint256) indexes;
    }
    // used to initialize the order ID
    uint256 orderID = 0;

    /**
     * used to fetch orders from the order book
     * need the ticker and the side of the order
     */
    mapping(bytes32 => mapping(uint => Order[])) public orderbook;
    // map an order to the involved traders
    mapping(uint => Ordermap) orderTotradersmapping;
    /**
    * used to  synchronize amount on buy side based on the price
    *
    */
    modifier checkbalances(bytes32 _ticker,Side side, uint256 _amount, uint256 _price){
           if (side == Side.BUY) {
            (, uint256 price) = SafeMath.tryMul(_amount, _price);
            require(
                balances[msg.sender][bytes32("ETH")] >= price,
                "balance no sufficient"
            );
           
        } else if (side == Side.SELL) {
            require(
                balances[msg.sender][_ticker] >= _amount,
                "no Enough tokens"
            );
         
        }
        _;
    }
    /**
     * used to set the user Ether balance
     * is a public payable function
     */
    function depositEther() public payable {
        balances[msg.sender][bytes32("ETH")] += msg.value;
    }
     

    function createMarketOrder(uint256 _amount, bytes32 _ticker, Side side) public {
        uint otherside = 0;
        if (side == Side.BUY) {
            otherside = 1;
        }
       if (side == Side.SELL) {
            require(balances[msg.sender][_ticker] >= _amount, "Token balance not sufficient");
            otherside = 0;
        }
        uint256 r_amount = _amount;
        uint256 counter = 0;
        Order[] storage orders = orderbook[_ticker][otherside];
        if(orders.length==0){
            return ;
        }
        while (r_amount > 0 && counter < orders.length) {
            r_amount = _marketOrderTrade(r_amount, _ticker,orders[counter],otherside);
            counter++;
        }
    }

    function _marketOrderTrade( uint256 _amount, bytes32 _ticker, Order storage order,uint _otherside) private returns (uint256 remaining) {
        uint256 traded = 0;
        // if side is buy i.e otherside == 1 ; msg.sender  want to buy _amount token from order.traders 
        // if side is sell i.e otherside == 0; msg.sender want to sell _amount token to order.traders
        if (_otherside == 1) {
            uint i=0;
            //get the list of the buyers
            Trader[] storage buyers = orderTotradersmapping[order.id].traders;
            while(i <buyers.length && traded<_amount){
                uint256 tradable = getTradable(order.amount,buyers[i].share);
                _buy(buyers[i],_ticker,tradable, order.price);
                (,traded) = SafeMath.tryAdd(traded,tradable);
                (,order.amount) = SafeMath.trySub(order.amount,tradable);
                i++;
            }
        }else if(_otherside == 0){
            uint j=0;
            //get the list of sellers 
            Trader[] storage sellers = orderTotradersmapping[order.id].traders;
            while(j <sellers.length && traded<_amount){
                uint256 tradable = getTradable(order.amount,sellers[j].share);
                _sell(sellers[j],_ticker,tradable, order.price);
                (,traded) = SafeMath.tryAdd(traded,tradable);
                j++;
            }
        }
        (,remaining) = SafeMath.trySub(_amount,traded);
        return remaining;
    }

   
    function _buy(Trader storage _from, bytes32 _ticker, uint256 _amount,uint256 price) private {
         // Estimate the price in ETH for the trade for each order on the sell side
        (bool success, uint256 due) = SafeMath.tryMul(price, _amount);
        // require the buy must have enough ETH to proceed to the trade
        require(balances[msg.sender][bytes32("ETH")] >= due,"ETH balance not sufficient for this Buy Market Order ");
         
        if (success) {
            // decrease the ETH balance of the buyer
            (, balances[msg.sender][bytes32("ETH")]) = SafeMath.trySub(balances[msg.sender][bytes32("ETH")], due);
            // increase the ETH balance of the trader on the SELL side
            (, balances[_from.account][bytes32("ETH")]) = SafeMath.tryAdd(balances[_from.account][bytes32("ETH")], due);
            // decrease the Token balance of the trader on the SELL side
            (, balances[_from.account][_ticker]) = SafeMath.trySub(balances[_from.account][_ticker], _amount);
            // transfer the token to Buyer
            (, balances[msg.sender][_ticker]) = SafeMath.tryAdd(balances[msg.sender][_ticker], _amount);
            // adjust trader share 
            (,_from.share) = SafeMath.trySub(_from.share, _amount);
        }  
    }

    function _sell(Trader storage _to, bytes32 _ticker, uint256 _amount,uint256 price) private  {
        // get the estimate eth due  by the trader on the buy side for each order to process
        (bool success, uint256 due) = SafeMath.tryMul(_amount, price);
        if (success) {
            // decrease  ETH balance of the  trader on the buy side
            (, balances[_to.account][bytes32("ETH")]) = SafeMath.trySub(balances[_to.account][bytes32("ETH")], due);
             // Increase seller ETH balance
            (, balances[msg.sender][bytes32("ETH")]) = SafeMath.tryAdd(balances[msg.sender][bytes32("ETH")],due);
            //decrease seller token balance
            (, balances[msg.sender][_ticker]) = SafeMath.trySub(balances[msg.sender][_ticker], _amount);
            //transfer token to  the trader on the buy side
            (, balances[_to.account][_ticker]) = SafeMath.tryAdd(balances[_to.account][_ticker],_amount);
            (,_to.share) = SafeMath.trySub(_to.share, _amount);
        }
    }

    function _trade(bytes32 ticker,Trader storage buyer, Trader storage seller,uint256 price,uint256 _amount) private {
            (bool success, uint256 due) = SafeMath.tryMul(_amount, price);
            //require(balances[buyer.trader]["ETH"]>=due, "Balance not enough");
            if(success){
                (,balances[buyer.account]["ETH"]) = SafeMath.trySub(balances[buyer.account]["ETH"],due);
                (,balances[seller.account]["ETH"]) = SafeMath.tryAdd(balances[seller.account]["ETH"],due);
                (,balances[seller.account][ticker]) = SafeMath.trySub(balances[seller.account][ticker],_amount);
                (,balances[buyer.account][ticker]) = SafeMath.tryAdd(balances[buyer.account][ticker],_amount);
                (,buyer.share) = SafeMath.trySub(buyer.share, _amount);
                (,seller.share) = SafeMath.trySub(seller.share, _amount);
            }
    }
    /**
     * @param _amount the amount of token
     *
     *
     *
     */
    function createLimitOrder(uint256 _amount, uint256 _price, bytes32 _ticker,Side side) public checkbalances(_ticker,side,_amount,_price){
        Order[] storage orders = orderbook[_ticker][uint(side)];
        (uint position, bool exist)  = _lookfor(_ticker,_price, side);
        Order storage currentOrder;
        if(exist){
                 currentOrder = orders[position];
                 addTraderToOrder(currentOrder, _amount);  
        }else{

            orders.push( Order({id: orderID, position: orders.length, side: side,ticker: _ticker, amount: _amount, price: _price, filled: false }));
            // store the new added Order
            currentOrder = orders[orders.length-1];
            // create a Trader struct to store informations about the buyer
            Trader memory trader  = Trader(msg.sender, _amount);
            // link the order to the Trader with orderTotradersmapping 
            orderTotradersmapping[currentOrder.id].traders.push(trader);
            orderTotradersmapping[currentOrder.id].indexes[trader.account] =   orderTotradersmapping[orderID].traders.length;
        }
            //sort the orderbook
            _quicksort(orders,0, orders.length, side);
            orderID++;
            if(currentOrder.side == Side.BUY){
                (uint index, bool exist) = _lookfor(_ticker, _price,Side.SELL);
                if(exist){
                     _processLimitOrder(currentOrder,orderbook[_ticker][uint(Side.SELL)][index]);
                }
                // proceed the limit orders if a matching is founded
            } else if(currentOrder.side == Side.SELL){
                (uint index, bool exist) = _lookfor(_ticker, _price,Side.BUY);
                if(exist){
                     _processLimitOrder(orderbook[_ticker][uint(Side.BUY)][index],currentOrder);
                }
            }
    }

    // we use a _quicksort(_tosort, low, high); algorithm to sort orders
    function _quicksort(Order[] storage _tosort, uint low, uint high,Side _side) private {
        if (low < high) {
            uint256 pivot = partition(_tosort, low, high, _side);
            _quicksort(_tosort, low, pivot, _side);
            _quicksort(_tosort, pivot + 1, high, _side);
        }
    }

     function addTraderToOrder(Order storage current,uint256 _amount) private{
            uint256 trader_index = orderTotradersmapping[current.id].indexes[msg.sender];
              // trader_index == 0 mean the trader does not have any shares in the order
            if(trader_index == 0){
                    // add the buyer to trader list 
                orderTotradersmapping[current.id].traders.push(Trader(msg.sender,_amount));
                orderTotradersmapping[current.id].indexes[msg.sender] =  orderTotradersmapping[current.id].traders.length;
                (, current.amount) = SafeMath.tryAdd(current.amount, _amount);
                 }// trader already have a share in the order
                 else if(trader_index >0){
                (,orderTotradersmapping[current.id].traders[trader_index-1].share) = SafeMath.tryAdd(orderTotradersmapping[current.id].traders[trader_index-1].share, _amount); 
                (, current.amount) = SafeMath.tryAdd(current.amount, _amount);
          }
     }
    function _lookfor(bytes32 _ticker, uint256 _price,Side side) private view returns(uint index, bool found){
            Order[] storage tolookup = orderbook[_ticker][uint(side)];
            for(uint i=0; i<tolookup.length; i++){
                if((tolookup[i].ticker ==_ticker)&&(tolookup[i].price == _price)){
                    index = i;
                    found = true;
                    return (index, found);
                }
            }
            return (0, false);
    }

    function _processLimitOrder(Order storage current, Order storage matching) private {
                uint256 tradable = getTradable(current.amount, matching.amount);
                Trader[] storage buyers = orderTotradersmapping[current.id].traders;
                Trader[] storage sellers = orderTotradersmapping[matching.id].traders;
                uint i=0;
                uint j=0;
                while(tradable >0){
                    if(i >= buyers.length){
                        return;
                    }
                    if(j >= sellers.length){
                        return;
                    }
                    if(buyers[i].share < sellers[j].share){
                        uint256 trade_amount = buyers[i].share;
                        _trade(current.ticker, buyers[i],sellers[j],current.price,trade_amount);
                        (, tradable)  = SafeMath.trySub(tradable,trade_amount);
                        (,current.amount) = SafeMath.trySub(current.amount, trade_amount);
                        (,matching.amount) = SafeMath.trySub(matching.amount,trade_amount);
                        i++;
                    }else if(buyers[i].share > sellers[j].share){
                        uint256 trade_amount = sellers[i].share;
                        _trade(current.ticker,buyers[i],sellers[j],current.price,trade_amount);
                        (, tradable)  = SafeMath.trySub(tradable,trade_amount);
                        (,current.amount) =  SafeMath.trySub(current.amount,trade_amount);
                        (,matching.amount) = SafeMath.trySub(matching.amount,trade_amount);
                        j++;
                    }else{
                        uint256 trade_amount = buyers[i].share;
                        _trade(current.ticker, buyers[i],sellers[j],current.price,trade_amount);
                        (, tradable)  = SafeMath.trySub(tradable,trade_amount);
                        (,current.amount) = SafeMath.trySub(current.amount, trade_amount);
                        (,matching.amount) = SafeMath.trySub(matching.amount,trade_amount);
                        i++;
                        j++;
                    }
                }
            if(current.amount == 0){
                    _deleteFromOrderBook(current);
            }
            if(matching.amount == 0){
                    _deleteFromOrderBook(matching);
            }
    }
    // partition functions returns the
    function partition(Order[] storage arr, uint low, uint high,Side _side) private returns (uint256 index) {
        Order memory pivot = arr[low];
        uint i = low;
        uint j = high - 1;
        while (true) {
            //sort descending
            if (_side == Side.BUY) {
                while (arr[i].price > pivot.price) {
                    i++;
                }

                while (arr[j].price < pivot.price) {
                    j--;
                }
            } else if (_side == Side.SELL) {
                //sort ascending
                while (arr[i].price < pivot.price) {
                    i++;
                }

                while (arr[j].price > pivot.price) {
                    j--;
                }
                if (i >= j) {
                    return j;
                }
            }
            if (i >= j) {
                return j;
            }
            
            Order memory temp = arr[i];
            arr[j].position = i;
            arr[i] = arr[j];
            temp.position = j;
            arr[j] = temp;
        }
    }

     function getTradable(uint256 first, uint256 second) private  pure returns(uint256){
             if(first>second){
                return first;
             }
             return second;
    }


    function _deleteFromOrderBook(Order storage _todelete) private {
        require(orderbook[_todelete.ticker][uint(_todelete.side)].length > 0," orderbook not empty");
        Order[] storage orders = orderbook[_todelete.ticker][uint(_todelete.side)];
        if(_todelete.position == orders.length-1){
            orders.pop();
            return;
        }
        Order memory toremove = orders[_todelete.position];
        orders[_todelete.position] =  orders[orders.length-1];
        orders[orders.length-1] = toremove;
        orders.pop();
        delete orderTotradersmapping[_todelete.id];
    }

    function getOrderbook(bytes32 _ticker,Side side) public view returns (Order[] memory) {
        return orderbook[_ticker][uint(side)];
    }
}
