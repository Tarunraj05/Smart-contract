// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ElectricityTrading {
    // Struct Definitions
    struct GO {
        string ownerID;
        uint256 electricityAmount;
        bool isConsumed;
    }

    struct Wallet {
        uint256 currency;
        uint256 electricity;
    }

    struct Order {
        string orderType; // "Buy" or "Sell"
        uint256 price;
        uint256 electricityAmount;
        address buyerWalletID;
        address sellerWalletID;
        string goID;
    }

    // State Variables
    address public owner;
    mapping(string => GO) public GOs;
    mapping(address => Wallet) public wallets;
    mapping(string => Order) public orders;

    // Events
    event WalletCreated(address walletId, uint256 currency, uint256 electricity);
    event GOCreated(string goId, string ownerId, uint256 electricityAmount);
    event OrderCreated(string orderId, string orderType, uint256 price, uint256 electricityAmount);
    event OrderFinalized(string orderId, string goId, bool isConsumed);
    event TradeExecuted(
        string orderId,
        address buyerWalletId,
        address sellerWalletId,
        uint256 price,
        uint256 electricityAmount
    );

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier validString(string memory str) {
        require(bytes(str).length > 0, "String cannot be empty");
        _;
    }

    modifier validAddress(address addr) {
        require(addr != address(0), "Invalid address");
        _;
    }

    // Constructor
    constructor() {
        owner = msg.sender;
    }

    // Utility Functions
    function createGO(string memory goId, string memory ownerId, uint256 electricityAmount)
        public
        onlyOwner
        validString(goId)
        validString(ownerId)
    {
        require(GOs[goId].electricityAmount == 0, "GO already exists");
        GOs[goId] = GO(ownerId, electricityAmount, false);
        emit GOCreated(goId, ownerId, electricityAmount);
    }

    function createWallet(address walletId, uint256 currency, uint256 electricity)
        public
        onlyOwner
        validAddress(walletId)
    {
        require(wallets[walletId].currency == 0, "Wallet already exists");
        wallets[walletId] = Wallet(currency, electricity);
        emit WalletCreated(walletId, currency, electricity);
    }

    function createSellOrder(
        string memory orderId,
        string memory goId,
        uint256 price,
        uint256 electricityAmount,
        address sellerWalletId
    )
        public
        validString(orderId)
        validString(goId)
        validAddress(sellerWalletId)
        returns (string memory)
    {
        require(GOs[goId].electricityAmount == electricityAmount, "Mismatch in electricity amount");
        require(!GOs[goId].isConsumed, "GO is already consumed");

        orders[orderId] = Order("Sell", price, electricityAmount, address(0), sellerWalletId, goId);
        emit OrderCreated(orderId, "Sell", price, electricityAmount);
        return "Sell order created successfully";
    }

    function createBuyOrder(
        string memory orderId,
        address buyerWalletId,
        uint256 price,
        uint256 electricityAmount
    )
        public
        validString(orderId)
        validAddress(buyerWalletId)
        returns (string memory)
    {
        require(orders[orderId].price == 0, "Order already exists");

        orders[orderId] = Order("Buy", price, electricityAmount, buyerWalletId, address(0), "");
        emit OrderCreated(orderId, "Buy", price, electricityAmount);
        return "Buy order created successfully";
    }

    // Core Functions
    function buyElectricity(string memory orderId, address buyerWalletId)
        public
        validString(orderId)
        validAddress(buyerWalletId)
        returns (string memory)
    {
        Order storage order = orders[orderId];
        GO storage go = GOs[order.goID];
        Wallet storage buyerWallet = wallets[buyerWalletId];
        Wallet storage sellerWallet = wallets[order.sellerWalletID];

        // Validate order and wallets
        require(buyerWallet.currency >= order.price, "Insufficient buyer currency");
        require(!go.isConsumed, "Invalid GO attached to order");

        // Execute trade
        order.buyerWalletID = buyerWalletId;
        buyerWallet.currency -= order.price;
        buyerWallet.electricity += order.electricityAmount;
        sellerWallet.currency += order.price;
        go.isConsumed = true;

        // Save updates
        emit TradeExecuted(orderId, buyerWalletId, order.sellerWalletID, order.price, order.electricityAmount);
        return "Trade executed successfully";
    }

    function finalizeOrder(string memory orderId, string memory goId)
        public
        validString(orderId)
        validString(goId)
        onlyOwner
        returns (string memory)
    {
        GO storage go = GOs[goId];

        require(!go.isConsumed, "GO already consumed");
        go.isConsumed = true;

        delete orders[orderId];
        emit OrderFinalized(orderId, goId, go.isConsumed);
        return "Order finalized successfully";
    }

    function autoSellElectricity(address sellerWalletId, uint256 currencyAmount)
        public
        validAddress(sellerWalletId)
        returns (string memory)
    {
        Wallet storage sellerWallet = wallets[sellerWalletId];
        sellerWallet.currency += currencyAmount;
        emit TradeExecuted("AutoSell", address(0), sellerWalletId, currencyAmount, 0);
        return "Auto-sell electricity completed successfully";
    }
}
