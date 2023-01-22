
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title NFT with Ongoing Subscription
 * @author Breakthrough Labs Inc.
 * @notice NFT, Sale, ERC721, Whitelist, Subscription
 * @custom:version 1.0.0
 * @custom:address 42
 * @custom:default-precision 0
 * @custom:simple-description NFT with a subscription. Users must deposit funds into the contract to make sure their NFT remains active.
 * @dev ERC721 NFT with the following features:
 *
 *  - Subscription where users must pay to keep their NFT active.
 *  - Reserve function for the owner to mint free NFTs.
 *  - Fixed maximum supply.
 *  - Optional whitelist so the owner can choose who is able to mint.
 *
 */

contract SubscriptionNFT is ERC721, ERC721Enumerable, Ownable {
    using Strings for uint256;
    using Address for address payable;

    bool public saleIsActive = true;
    bool public whitelistIsActive = false;

    uint256 public immutable MAX_SUPPLY;
    /// @custom:precision 18
    uint256 public subscriptionPrice;
    /// @custom:precision 18
    uint256 public currentPrice;

    mapping(address => bool) public whitelist;
    mapping(uint256 => uint256) public expireTime;
    string public tokenUriA;
    string public tokenUriB;

    /**
     * @param name NFT Name
     * @param symbol NFT Symbol
     * @param activeURI Token URI used for active NFTs
     * @param inactiveURI Token URI used for inactive NFTs
     * @param initialSubscriptionPrice Starting subscription price (yearly) | precision:18
     * @param price Initial Price | precision:18
     * @param maxSupply Maximum # of NFTs
     */
    constructor(
        string memory name,
        string memory symbol,
        string memory activeURI,
        string memory inactiveURI,
        uint256 initialSubscriptionPrice,
        uint256 price,
        uint256 maxSupply
    ) ERC721(name, symbol) {
        tokenUriA = activeURI;
        tokenUriB = inactiveURI;
        subscriptionPrice = initialSubscriptionPrice;
        currentPrice = price;
        MAX_SUPPLY = maxSupply;
    }

    /**
     * @dev An external method for users to purchase and mint NFTs. Requires that the sale
     * is active, that the whitelist is either inactive or the user is whitelisted, that
     * the minted NFTs will not exceed the `MAX_SUPPLY`, and that a sufficient payable value is sent.
     * @param amount The number of NFTs to mint.
     */
    function mint(uint256 amount) external payable {
        uint256 ts = totalSupply();

        require(
            !whitelistIsActive || whitelist[msg.sender],
            "Address must be whitelisted."
        );
        require(saleIsActive, "Sale must be active to mint tokens");
        require(ts + amount <= MAX_SUPPLY, "Purchase would exceed max tokens");

        require(
            currentPrice * amount <= msg.value,
            "Value sent is not correct"
        );

        uint256 oneYearFromNow = block.timestamp + 31556952;
        for (uint256 i = 0; i < amount; i++) {
            _safeMint(msg.sender, ts + i);
            expireTime[ts + i] = oneYearFromNow;
        }
    }

    /**
     * @dev Refill the NFT's subscription.
     * @param tokenId The ID of the token to be refilled.
     */
    function refillSubscription(uint256 tokenId) external payable {
        require(_exists(tokenId), "Invalid token ID");
        require(msg.value > 0, "Cannot refill with 0 time.");

        // 31,556,952 seconds in a year. 365.2425 days
        uint256 time = (msg.value * 31556952) / subscriptionPrice;
        if (isActive(tokenId)) expireTime[tokenId] += time;
        else expireTime[tokenId] = block.timestamp + time;
    }

    /**
     * @dev A way for the owner to reserve a specific number of NFTs without having to
     * interact with the sale.
     * @param n The number of NFTs to reserve.
     */
    function reserve(uint256 n) external onlyOwner {
        uint256 supply = totalSupply();
        require(supply + n <= MAX_SUPPLY, "Purchase would exceed max tokens");

        uint256 oneYearFromNow = block.timestamp + 31556952;
        for (uint256 i = 0; i < n; i++) {
            _safeMint(msg.sender, supply + i);
            expireTime[supply + i] = oneYearFromNow;
        }
    }

    /**
     * @dev Sets whether or not the NFT sale is active.
     * @param _saleIsActive Whether or not the sale will be active.
     */
    function setSaleIsActive(bool _saleIsActive) external onlyOwner {
        saleIsActive = _saleIsActive;
    }

    /**
     * @dev Sets whether or not the NFT sale whitelist is active.
     * @param active Whether or not the whitelist will be active.
     */
    function setWhitelistActive(bool active) external onlyOwner {
        whitelistIsActive = active;
    }

    /**
     * @dev Adds an address to the NFT sale whitelist.
     * @param wallet The wallet to add to the whitelist.
     */
    function addToWhitelist(address wallet) external onlyOwner {
        whitelist[wallet] = true;
    }

    /**
     * @dev Adds an array of addresses to the NFT sale whitelist.
     * @param wallets The wallets to add to the whitelist.
     */
    function addManyToWhitelist(address[] calldata wallets) external onlyOwner {
        for (uint256 i = 0; i < wallets.length; i++) {
            whitelist[wallets[i]] = true;
        }
    }

    /**
     * @dev Removes an address from the NFT sale whitelist.
     * @param wallet The wallet to remove from the whitelist.
     */
    function removeFromWhitelist(address wallet) external onlyOwner {
        delete whitelist[wallet];
    }

    /**
     * @dev Sets the price of each NFT during the initial sale.
     * @param price The price of each NFT during the initial sale | precision:18
     */
    function setCurrentPrice(uint256 price) external onlyOwner {
        currentPrice = price;
    }

    /**
     * @dev Sets the active NFT URI
     * @param uri The new Active URI
     */
    function setActiveURI(string memory uri) external onlyOwner {
        tokenUriA = uri;
    }

    /**
     * @dev Sets the inactive NFT URI
     * @param uri The new Inactive URI
     */
    function setInactiveURI(string memory uri) external onlyOwner {
        tokenUriB = uri;
    }

    /**
     * @dev Sets the subscription price.
     * @param annualPrice The new annual subscription price | precision:18
     */
    function setSubscriptionPrice(uint256 annualPrice) external onlyOwner {
        subscriptionPrice = annualPrice;
    }

    /**
     * @dev Allows the owner to withdraw subscription and sale proceeds.
     */
    function ownerWithdraw() external onlyOwner {
        require(address(this).balance > 0, "Nothing to withdraw.");
        payable(msg.sender).transfer(address(this).balance);
    }

    /**
     * @dev Used to check if an NFT is active.
     * @param tokenId The NFT to check.
     */
    function isActive(uint256 tokenId) public view returns (bool) {
        return expireTime[tokenId] > block.timestamp;
    }

    /**
     * @dev Used to retrieve an NFT's URI.
     * @param tokenId The NFT to check.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "ERC721: invalid token ID");

        string memory baseURI = isActive(tokenId) ? tokenUriA : tokenUriB;
        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }

    // Required Overrides

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

