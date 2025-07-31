// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
contract Users {
    using Strings for uint32;
    using Strings for uint256;

    address admin;
    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "ONLY_ADMIN");
        _;
    }

    address public computecontract;
    address public marketplace;

    modifier internalContracts() {
        require(msg.sender == computecontract || msg.sender == marketplace, "UNAUTHORIZED_CALLER");
        _;
    }
    function setContracts(address _compute, address _market) external onlyAdmin {
        computecontract = _compute;
        marketplace = _market;
    }



    uint8 totalres = 9;

    struct UserData {
        address userAddress;
        uint32 userExp;
        mapping(uint8 => uint256) inventory;
    }

    mapping(address => UserData) public users;

    struct Transaction {
        uint256 id;
        string txtype;
        string description;
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address => Transaction[]) public transactionHistory;

    function getUserData(address _user) external view returns(
        address userAddress, uint32 userExp
    ) {
        UserData storage userData = users[_user];
        return (
            userData.userAddress,
            userData.userExp
        );
    }


    function getUserInventory(address user, uint8 resource) external view returns (uint256) {
        return users[user].inventory[uint8(resource)];
    }

    function getUserAllInventory(address user) external view returns(uint256[] memory) {
        uint256[] memory inventoryData = new uint256[](totalres);
        for (uint8 i = 0; i < totalres; i++) {
            inventoryData[i] = users[user].inventory[i];
        }
        return inventoryData;
    }


    function updateInventory(address _user, uint8 resource, uint32 amount, bool increase) external internalContracts{
        if (increase) {
            users[_user].inventory[resource] += amount;
        } else {
            users[_user].inventory[resource] -= amount;
        }
    }

    mapping(address => uint256) public userTxIdCounter;
    function croporfactorytxn(address _user, bool corf, uint256 price, bool action, uint32 tileId) external internalContracts {
        UserData storage user = users[_user];
        // true: crop, false: factory
        //action: true: planting or factory build.. false: harvesting

        userTxIdCounter[_user] += 1;
        if ( corf ) {
            user.userExp += 15;
            if (action) {
                 
                transactionHistory[_user].push(Transaction({
                    id: userTxIdCounter[_user],
                    txtype: "Sow",
                    description: string(abi.encodePacked("Crop Planted on Tile #", tileId.toString())),
                    amount: price,
                    timestamp: block.timestamp
                }));
            } else  {
                 
                transactionHistory[_user].push(Transaction({
                    id: userTxIdCounter[_user],
                    txtype: "Harvest",
                    description: string(abi.encodePacked("Crop Harvested on Tile #", tileId.toString())),
                    amount: price,
                    timestamp: block.timestamp
                }));
            }
        } else {
            user.userExp += 40;
            if (action) {
                 
                transactionHistory[_user].push(Transaction({
                    id: userTxIdCounter[_user],
                    txtype: "Investment",
                    description: string(abi.encodePacked("Built Factory on Tile #", tileId.toString())),
                    amount: price,
                    timestamp: block.timestamp
                }));
            }
        }
    }

    function recordMarketplacetx(
        address _user, string memory _txtype, string memory _resource, uint256 amount, bool _spent, uint256 _price
    ) external internalContracts {
        userTxIdCounter[_user] += 1;

        if (_spent) {
            transactionHistory[_user].push(Transaction({
                id: userTxIdCounter[_user],
                txtype: _txtype,
                description: string(abi.encodePacked("Bought ", amount.toString(), " ", _resource)),
                amount: _price,
                timestamp: block.timestamp
            }));
        } else {
            transactionHistory[_user].push(Transaction({
                id: userTxIdCounter[_user],
                txtype: _txtype,
                description: string(abi.encodePacked("Sold ", amount.toString(), " ", _resource)),
                amount: _price,
                timestamp: block.timestamp
            }));
        }
        users[_user].userExp += 10;
    }


    function getTransactionHistory(address user, uint256 page) external view returns (
        string[] memory txtype,
        string[] memory descriptions,
        uint256[] memory amounts,
        uint256[] memory timestamps
    ) {
        uint256 total = transactionHistory[user].length;
        require(total >0, "NO_TRANSACTION_HISTORY");
        uint256 itemsPerPage = 10;
        uint256 start = total > page * itemsPerPage ? total - (page * itemsPerPage) : 0;

        uint256 end = total - ((page - 1) * itemsPerPage);
        if (end > total) end = total;
        if (start > end) start = 0;
        uint256 len = end - start;

        txtype = new string[](len);
        descriptions = new string[](len);
        amounts = new uint256[](len);
        timestamps = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            Transaction memory txData = transactionHistory[user][start + i];
            txtype[i] = txData.txtype;
            descriptions[i] = txData.description;
            amounts[i] = txData.amount;
            timestamps[i] = txData.timestamp;
        }
    }

    function updateUserExp(address _user, uint32 exp) external internalContracts {
        users[_user].userExp += exp;
    }


    
}