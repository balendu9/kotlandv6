// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./RegionNFT.sol";
import "./Compute.sol";
import "./Users.sol";

contract QuestContract {
    address admin;
    Users public userContract;
    RegionNFT public tilecontract;
    Compute public computecontract;
    IERC20 public token;

    constructor(
        address _userContract,
        address _tilecontractaddress,
        address _computecontract,
        address _token
    ) {
        admin = msg.sender;
        userContract = Users(_userContract);
        tilecontract = RegionNFT(_tilecontractaddress);
        computecontract = Compute(_computecontract);
        token = IERC20(_token);
    }

    function fetchTileInfo(
        uint256 regionId,
        uint32 tileId
    )
        internal
        view
        returns (
            uint32 id,
            bool isBeingUsed,
            bool isCrop,
            uint8 cropTypeId,
            uint8 factoryTypeId,
            uint8 fertility,
            uint8 waterLevel,
            uint8 growthStage
        )
    {
        return tilecontract.getTileData(regionId, tileId);
    }

    function fetchRegionInfo(
        uint256 regionId
    )
        internal
        view
        returns (
            uint8 pollution,
            uint8 fertility,
            uint8 waterlevel,
            uint8 eco,
            uint256 lastupdate
        )
    {
        return tilecontract.getRegionMeta(regionId);
    }

    uint256 public cropPrice = 50000 * 10 ** 18;

    function plantCrop(
        uint256 regionId,
        uint8 tileId,
        uint8 cropTypeId
    ) external {
        (, bool isBeingUsed, , , , , , ) = fetchTileInfo(regionId, tileId);
        require(!isBeingUsed && cropTypeId <= 5, "INVALID_ACTION");
        require(
            token.transferFrom(msg.sender, admin, cropPrice),
            "TOKEN_TRANSFER_FAILED"
        );
        tilecontract.setCropOrFactory(
            true,
            tileId,
            cropTypeId,
            msg.sender,
            regionId
        );
        recordAction(msg.sender, 1);
        userContract.updateUserExp(msg.sender, 7);
    }

    uint256 public factoryPrice = 500000 * 10 ** 18;

    function buildFactory(
        uint256 regionId,
        uint8 tileId,
        uint8 _factoryTypeId
    ) external {
        (, bool isBeingUsed, , , , , , ) = fetchTileInfo(regionId, tileId);
        require(!isBeingUsed && _factoryTypeId <= 5, "INVALID");
        require(
            token.transferFrom(msg.sender, admin, factoryPrice),
            "TOKEN_TRANSFER_FAILED"
        );
        tilecontract.setCropOrFactory(
            false,
            tileId,
            _factoryTypeId,
            msg.sender,
            regionId
        );
        recordAction(msg.sender, 2);
        userContract.updateUserExp(msg.sender, 13);
    }

    mapping(uint256 => mapping(uint32 => uint256)) public lastWateredTime;

    function waterCrop(uint256 regionId, uint32 tileId) external {
        (
            ,
            bool isBeingUsed,
            bool isCrop,
            uint8 cropTypeId,
            ,
            uint8 fertility,
            uint8 waterLevel,

        ) = fetchTileInfo(regionId, tileId);
        require(
            isBeingUsed &&
                isCrop &&
                block.timestamp > lastWateredTime[regionId][tileId] + 1 days,
            "ONCE_IN_24_HOURS"
        );
        lastWateredTime[regionId][tileId] = block.timestamp;

        (uint8 pollution, , , uint8 eco, ) = fetchRegionInfo(regionId);

        uint8 growth = computecontract.plantGrowthCalculator(
            cropTypeId,
            fertility,
            waterLevel,
            eco,
            pollution,
            true,
            msg.sender
        );
        // uint8 _cropType, uint8 _fertility, uint8 _waterlevel, uint8 _ecoscore, uint8 _pollutionlevel, bool worf, address _user
        tilecontract.updateWFG(tileId, true, growth, regionId, msg.sender);

        userContract.updateUserExp(msg.sender, 2);
    }

    // updateWFG(uint32 tileId, bool worf, uint8 growth, uint256 regionId, address _user)

    function fertilizeCrop(uint256 regionId, uint32 tileId) external {
        (
            ,
            bool isBeingUsed,
            bool isCrop,
            uint8 cropTypeId,
            ,
            uint8 fertility,
            uint8 waterLevel,

        ) = fetchTileInfo(regionId, tileId);
        require(isBeingUsed && isCrop && fertility <= 100, "INVALID");
        (uint8 pollution, uint8 fertilityR, , uint8 eco, ) = fetchRegionInfo(
            regionId
        );

        uint8 growth = computecontract.plantGrowthCalculator(
            cropTypeId,
            fertilityR,
            waterLevel,
            eco,
            pollution,
            true,
            msg.sender
        );
        tilecontract.updateWFG(tileId, false, growth, regionId, msg.sender);
        userContract.updateUserExp(msg.sender, 4);
    }

    function harvestCrop(uint256 regionId, uint32 tileId) external {
        (
            ,
            bool isBeingUsed,
            bool isCrop,
            uint8 cropTypeId,
            ,
            ,
            ,
            uint8 growthStage
        ) = fetchTileInfo(regionId, tileId);
        require(isBeingUsed && isCrop && growthStage == 100, "INVALID");
        tilecontract.updateAfterHarvest(tileId, regionId, msg.sender);
        computecontract.getHarvestedResourceAndAmount(cropTypeId, msg.sender);
        recordAction(msg.sender, 3);
        userContract.updateUserExp(msg.sender, 15);
    }

    function produceFromFactory(
        uint256 regionId,
        uint32 tileId,
        uint8 _factoryTypeId
    ) external {
        (
            ,
            bool isBeingUsed,
            bool isCrop,
            ,
            uint8 factoryTypeId,
            ,
            ,

        ) = fetchTileInfo(regionId, tileId);
        require(
            isBeingUsed && !isCrop && _factoryTypeId == factoryTypeId,
            "INVALID"
        );
        computecontract._produceFromFactory(msg.sender, factoryTypeId);
        recordAction(msg.sender, 4);

        userContract.updateUserExp(msg.sender, 8);
    }

    // quests
    function getCurrentDay() public view returns (uint256) {
        return block.timestamp / 1 days;
    }

    struct DailyProgress {
        uint256 currDay;
        uint8 cropsPlanted;
        uint8 factoriesBuilt;
        uint8 cropsHarvested;
        uint8 factoryProduced;
    }

    struct LongProgress {
        uint8 cropsPlanted;
        uint8 factoriesBuilt;
        uint8 cropsHarvested;
        uint8 factoryProduced;
    }

    struct Quest {
        string name;
        string description;
        uint256 id;
        bool daily;
        uint256 currentParticipants;
        uint256 maxParticipants;
        address[] participantList;
        uint8 actionToDo;
        uint256 amountToComplete;
        uint256 reward;
        uint8 assetType;
        uint256 endDay;
        mapping(address => bool) participants;
        mapping(address => bool) claimed;
    }

    uint256 public nextQuestId = 1;
    mapping(uint256 => Quest) public quests;

    mapping(address => DailyProgress) public progress;
    mapping(address => LongProgress) public longprogress;

    function createQuest(
        string memory _name,
        string memory _description,
        bool _daily,
        uint8 _actionToDo,
        uint256 _amountToComplete,
        uint256 _reward,
        uint8 _assetType,
        uint256 _maxParticipants,
        uint256 _endDay
    ) external {
        uint256 questId = nextQuestId;
        Quest storage q = quests[questId];

        q.name = _name;
        q.description = _description;
        q.id = questId;
        q.daily = _daily;
        q.actionToDo = _actionToDo;
        q.amountToComplete = _amountToComplete;
        q.reward = _reward;
        q.assetType = _assetType;
        q.maxParticipants = _maxParticipants;

        q.endDay = getCurrentDay() + _endDay;
        nextQuestId++;
    }

    function joinQuest(uint256 questId) external {
        Quest storage q = quests[questId];
        require(q.id == questId, "Quest does not exist");
        uint256 today = getCurrentDay();
        require(today <= q.endDay, "Quest has expired");

        require(!q.participants[msg.sender], "ALREADY_JOINED");

        require(q.currentParticipants < q.maxParticipants, "QUEST_FULL");

        q.participants[msg.sender] = true;
        q.participantList.push(msg.sender);
        q.currentParticipants++;
    }

    function recordAction(address user, uint8 action) internal {
        uint256 currentDay = getCurrentDay();
        DailyProgress storage p = progress[user];
        LongProgress storage l = longprogress[user];

        if (p.currDay != currentDay) {
            p.currDay = currentDay;
            p.cropsPlanted = 0;
            p.factoriesBuilt = 0;
            p.cropsHarvested = 0;
            p.factoryProduced = 0;
        }

        // 1 = plant, 2 = build, 3 = harvest, 4 = produce
        if (action == 1) {
            p.cropsPlanted++;
            l.cropsPlanted++;
        } else if (action == 2) {
            p.factoriesBuilt++;
            l.factoriesBuilt++;
        } else if (action == 3) {
            p.cropsHarvested++;
            l.cropsHarvested++;
        } else if (action == 4) {
            p.factoryProduced++;
            l.factoryProduced++;
        }
        p.currDay = currentDay;
    }

    function claimReward(uint256 questId) external {
        Quest storage q = quests[questId];

        require(q.participants[msg.sender], "Not a participant");
        require(!q.claimed[msg.sender], "Already claimed");

        uint256 today = getCurrentDay();
        require(today <= q.endDay, "Quest expired");

        DailyProgress storage dp = progress[msg.sender];
        LongProgress storage lp = longprogress[msg.sender];

        uint256 userProgress;
        uint256 reward;

        uint8 assettype;
        if (q.daily) {
            if (q.actionToDo == 1) {
                userProgress = dp.cropsPlanted;
            } else if (q.actionToDo == 2) {
                userProgress = dp.factoriesBuilt;
            } else if (q.actionToDo == 3) {
                userProgress = dp.cropsHarvested;
            } else if (q.actionToDo == 4) {
                userProgress = dp.factoryProduced;
            } else {
                revert("Invalid actionToDo");
            }
            require(userProgress >= q.amountToComplete, "GOAL_NOT_ACHIEVED");
            q.claimed[msg.sender] = true;
            reward = q.reward;
            assettype = q.assetType;

            dp.currDay = today;
            dp.cropsPlanted = 0;
            dp.factoriesBuilt = 0;
            dp.cropsHarvested = 0;
            dp.factoryProduced = 0;
        } else {
            if (q.actionToDo == 1) {
                userProgress = lp.cropsPlanted;
            } else if (q.actionToDo == 2) {
                userProgress = lp.factoriesBuilt;
            } else if (q.actionToDo == 3) {
                userProgress = lp.cropsHarvested;
            } else if (q.actionToDo == 4) {
                userProgress = lp.factoryProduced;
            } else {
                revert("Invalid actionToDo");
            }
            require(userProgress >= q.amountToComplete, "GOAL_NOT_ACHIEVED");
            q.claimed[msg.sender] = true;
            reward = q.reward;
            assettype = q.assetType;

            lp.cropsPlanted = 0;
            lp.factoriesBuilt = 0;
            lp.cropsHarvested = 0;
            lp.factoryProduced = 0;
        }

        if (assettype == 0) {
            require(
                token.transfer(msg.sender, reward),
                "TOKEN_TRANSFER_FAILED"
            );
        } else {
            userContract.updateInventory(
                msg.sender,
                assettype,
                uint8(reward),
                true
            );
        }

        userContract.updateUserExp(msg.sender, 31);
    }

    function getQuest(
        uint256 questId
    )
        external
        view
        returns (
            string memory name,
            string memory description,
            uint256 id,
            bool daily,
            uint256 currentParticipants,
            uint256 maxParticipants,
            address[] memory participantList,
            uint8 actionToDo,
            uint256 amountToComplete,
            uint256 reward,
            uint8 assetType,
            uint256 endDay
        )
    {
        Quest storage q = quests[questId];

        return (
            q.name,
            q.description,
            q.id,
            q.daily,
            q.currentParticipants,
            q.maxParticipants,
            q.participantList,
            q.actionToDo,
            q.amountToComplete,
            q.reward,
            q.assetType,
            q.endDay
        );
    }
}
