// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./IContent.sol";

import "hardhat/console.sol";

contract MyNFT is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(uint256 => IContent.Item) Content;
    uint256 price = 5000000000000000;

    address public renderingContractAddress;

    event NewItem(address sender, uint256 tokenId, string name);

    constructor() ERC721("MYNFT", "MYCOLLECTION") {

    function GenerateNFT(
        string calldata ItemName,
        string calldata description,
        uint256[6] calldata Magic
    ) public payable virtual {
        require(msg.value >= price, "Not enough ETH sent; check price!");

        uint256 newItemId = _tokenIds.current();

        if (newItemId >= 10000) {
            revert("This NFT is sold out.");
        }

        IContent.Item memory Item;

        Item.name = ItemName;
        Item.magic = Magic;

        Item.seed = uint256(
            keccak256(
                abi.encodePacked(
                    newItemId,
                    msg.sender,
                    block.difficulty,
                    block.timestamp
                )
            )
        );

        _safeMint(msg.sender, newItemId);

        Content[newItemId] = Item;

        emit NewItem(msg.sender, newItemId, ItemName);

        _tokenIds.increment();
    }

    function setRenderingContractAddress(address _renderingContractAddress)
        public
        onlyOwner
    {
        renderingContractAddress = _renderingContractAddress;
    }

    function setPrice(uint256 _price) public onlyOwner {
        price = _price;
    }

    function totalContent() public view virtual returns (uint256) {
        return _tokenIds.current();
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (renderingContractAddress == address(0)) {
            return "";
        }

        IItemRenderer renderer = IItemRenderer(renderingContractAddress);
        return renderer.tokenURI(_tokenId, Content[_tokenId]);
    }

    function withdraw() public onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }
    
}