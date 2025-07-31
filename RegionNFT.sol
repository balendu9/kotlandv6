// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

contract RegionNFT is ERC721Enumerable {
    using Counters for Counters.Counter;
    using String for uint256;

    address public admin;
    address public treasury;
    address public questscontract;

    IERC20 public immutable token;

    uint256 public nftMaxSupply = 3000;

    uint256 public totalCrops = 0;
    uint256 public totalFactory = 0;

    uint256 public constant PRICE_KOT = 5000000 ether;
    uint256 public constant PRICE_ETH = 0.02 ether;

    string public baseImageURL;
    constructor(address _token, address _treasury, address _quest, string calldata _baseurl) {
        admin = msg.sender;
        token = IERC20(_token);
        treasury = _treasury;
        questscontract = _quest;
        baseImageURL = _baseurl;
    }

    modifier onlyQuestsContract() {
        require(msg.sender == questscontract, "Not authorized");
        _;
    }

    Counters.Counter private _ids;

    struct RegionMeta {
        uint8 pollution;
        uint8 fertility;
        uint8 waterlevel;
        uint8 eco;
        uint256 lastupdate;
    }

    mapping (uint256 => RegionMeta) public regionMeta;

    function claimRegion() external returns (uint256 regionId) {
        require(totalSupply() < nftMaxSupply, "ALL_SOLD");
        require(token.transferFrom(msg.sender, treasury, PRICE_KOT), "TOKEN_TRANSFER_FAILED");
        _ids.increment();
        regionId = _ids.current();
        _safeMint(msg.sender, regionId);
        regionMeta[regionId] = RegionMeta({
            pollution: 0,
            fertility: 0,
            waterlevel: 0,
            eco: 0,
            lastupdate: block.timestamp
        });
        initializeRegion(regionId);      
    }

    function claimWithEth() external payable returns (uint256 regionId) {
        require(totalSupply() < nftMaxSupply, "ALL_SOLD");
        require(msg.value == PRICE_ETH, "INVALID_ETH");
        payable(treasury).transfer(msg.value);
        _ids.increment();
        regionId = _ids.current();
        _safeMint(msg.sender, regionId);
        regionMeta[regionId] = RegionMeta({
            pollution: 0,
            fertility: 0,
            waterlevel: 0,
            eco: 0,
            lastupdate: block.timestamp
        });
        initializeRegion(regionId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "NON_EXISTING_NFT");
        RegionMeta memory meta = regionMeta[tokenId];
        string memory attributes = string (
            abi.encodePacked(
                '[{"trait_type":"Pollution Level","value":', uint256(meta.pollution).toString(),
                '},{"trait_type":"Fertility Index","value":', uint256(meta.fertility).toString(),
                '},{"trait_type":"Water Level","value":', uint256(meta.waterlevel).toString(),
                '},{"trait_type":"Eco Score","value":', uint256(meta.eco).toString(),
                '}]'
            )
        );

        string memory json = string (
            abi.encodePacked(
                '{"name":"Region #', tokenId.toString(),
                '", "description":"Your region in KOTLAND", ',
                '"image":"', baseImageURL, '", ',
                '"attributes":', attributes, '}'
            )
        );

        return string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
    }

    

    function calculateRegionMeta(uint256 regionId) internal {
        TileData[9] memory tiles = regionTiles[regionId];
        uint256 len = tiles.length;
        uint256 p; uint256 f; uint256 w;

        for (uint256 i = 0; i < len; i++) {
            TileData memory t = tiles[i];
            if (t.factoryTypeId > 0) p += 13;
            f += t.fertility;
            w += t.waterLevel;
        }

        uint8 avgF = uint8(f / len);
        uint8 avgW = uint8(w / len);
        uint8 pol = uint8(p);
        uint256 ecoTmp = 100 - pol + avgF + avgW;
        uint8 eco = uint8(ecoTmp > 255 ? 255 : ecoTmp);

        regionMeta[regionId] = RegionMeta(pol, avgF, avgW, eco, block.timestamp);
    }


    struct TileData {
        uint32 id;
        bool isBeingUsed;
        bool isCrop;
        uint8 cropTypeId;
        uint8 factoryTypeId;
        uint8 fertility;
        uint8 waterLevel;
        uint8 growthStage;
    }

    mapping(uint256 => TileData[9]) public regionTiles;
    mapping(uint256 => bool) public regionInitialized;

    modifier onlyRegionOwner(uint256 regionId, address _user) {
        require(ownerOf(regionId) == _user, "NOT_OWNER");
        _;
    }

    function initializeRegion ( uint256 regionId ) internal {
        require(!regionInitialized[regionId], "ALREADY_INITIALIZED");     

        for ( uint8 i = 0; i < 9; ) {
            TileData storage t = regionTiles[regionId][i];
            t.id = i;
            unchecked { i++; }
        }
        regionInitialized[regionId]= true;
    }

    function getTileData(uint256 regionId, uint8 tileIndex) external view returns(
        uint32 id,
        bool isBeingUsed,
        bool isCrop,
        uint8 cropTypeId,
        uint8 factoryTypeId,
        uint8 fertility,
        uint8 waterLevel,
        uint8 growthStage
    ) {
        require(tileIndex < 9, "Invalid tile index");

        TileData memory tile = regionTiles[regionId][tileIndex];

        return (
            tile.id,
            tile.isBeingUsed,
            tile.isCrop,
            tile.cropTypeId,
            tile.factoryTypeId,
            tile.fertility,
            tile.waterLevel,
            tile.growthStage
        );
    }

    function getRegionMeta(uint256 regionId) external view returns (
        uint8 pollution,
        uint8 fertility,
        uint8 waterlevel,
        uint8 eco,
        uint256 lastupdate
    ) {
        RegionMeta memory meta = regionMeta[regionId];
        return (
            meta.pollution,
            meta.fertility,
            meta.waterlevel,
            meta.eco,
            meta.lastupdate
        );
    }


    function setCropOrFactory (bool corf, uint32 tileId, uint8 cofType, address _user, uint256 regionId) external onlyQuestsContract onlyRegionOwner(regionId, _user) {
        TileData storage tile = regionTiles[regionId][tileId];
        if (corf) {
            tile.isBeingUsed = true;
            tile.isCrop = true;
            tile.cropTypeId = cofType;
            totalCrops += 1;
        } else {
            tile.isBeingUsed = true;
            tile.isCrop = false;
            tile.factoryTypeId = cofType;
            totalFactory += 1;
        }
        calculateRegionMeta(regionId);
    }

    function updateWFG(uint32 tileId, bool worf, uint8 growth, uint256 regionId, address _user) external onlyQuestsContract onlyRegionOwner(regionId, _user) {
        TileData storage tile = regionTiles[regionId][tileId];
        // true: watering, false: fertilizer
        if (worf) {
            tile.waterLevel += 12;
        } else {
            tile.fertility += 100;
        }
        tile.growthStage = growth;
        if (tile.growthStage >= 100) {
            tile.growthStage = 100;
        }
        calculateRegionMeta(regionId);
    }

    function updateAfterHarvest(uint32 tileId, uint256 regionId, address _user) external onlyQuestsContract onlyRegionOwner(regionId, _user) {
        TileData storage tile = regionTiles[regionId][tileId];
        tile.isBeingUsed = false;
        tile.isCrop = false;
        tile.fertility = 0;
        tile.waterLevel = 0;
        tile.factoryTypeId = 0;

        calculateRegionMeta(regionId);
    }  


}