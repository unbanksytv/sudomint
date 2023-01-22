// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

/**
 * @title NFT Sale with burnable NFTs and wallet cap
 * @author Breakthrough Labs Inc.
 * @notice NFT, Sale, ERC721, Limited, Whitelist, Burnable
 * @custom:version 1.0.3
 * @custom:address 12
 * @custom:default-precision 0
 * @custom:simple-description NFT and whitelisted Sale, with burn functions to completely remove NFTs from circulation.
 * @dev ERC721 NFT with the following features:
 *
 *  - Built-in sale with an adjustable price.
 *  - Wallets can only purchase a limited number of NFTs during the sale.
 *  - Reserve function for the owner to mint free NFTs.
 *  - Fixed maximum supply.
 *  - Methods that allow users to burn their NFTs. This directly decreases total supply.
 *
 */

contract BurnableLimitedNFT is
    ERC721,
    ERC721Enumerable,
    ERC721Burnable,
    Ownable
{
    uint256 public immutable MAX_SUPPLY;

    /// @custom:precision 18
    uint256 public currentPrice;
    uint256 public walletLimit;

    bool public saleIsActive = true;
    bool public whitelistIsActive = false;

    string private _baseURIextended;

    mapping(address => bool) public whitelist;

    /**
     * @param _name NFT Name
     * @param _symbol NFT Symbol
     * @param _uri Token URI used for metadata
     * @param limit Wallet Limit
     * @param price Initial Price | precision:18
     * @param maxSupply Maximum # of NFTs
     */
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri,
        uint256 limit,
        uint256 price,
        uint256 maxSupply
    ) payable ERC721(_name, _symbol) {
        _baseURIextended = _uri;
        walletLimit = limit;
        currentPrice = price;
        MAX_SUPPLY = maxSupply;
    }

    /**
     * @dev An external method for users to purchase and mint NFTs. Requires that the sale
     * is active, that the whitelist is either inactive or the user is whitelisted, that
     * the minted NFTs will not exceed the `MAX_SUPPLY`, that the user's `walletLimit` will
     * not be exceeded, and that a sufficient payable value is sent.
     * @param amount The number of NFTs to mint.
     */
    function mint(uint256 amount) external payable {
        uint256 ts = totalSupply();
        uint256 minted = balanceOf(msg.sender);

        require(
            !whitelistIsActive || whitelist[msg.sender],
            "Address must be whitelisted."
        );
        require(saleIsActive, "Sale must be active to mint tokens");
        require(ts + amount <= MAX_SUPPLY, "Purchase would exceed max tokens");
        require(amount + minted <= walletLimit, "Exceeds wallet limit");

        require(
            currentPrice * amount <= msg.value,
            "Value sent is not correct"
        );

        for (uint256 i = 0; i < amount; i++) {
            _safeMint(msg.sender, ts + i);
        }
    }

    /**
     * @dev A way for the owner to reserve a specifc number of NFTs without having to
     * interact with the sale.
     * @param n The number of NFTs to reserve.
     */
    function reserve(uint256 n) external onlyOwner {
        uint256 supply = totalSupply();
        require(supply + n <= MAX_SUPPLY, "Purchase would exceed max tokens");
        for (uint256 i = 0; i < n; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }

    /**
     * @dev A way for the owner to withdraw all proceeds from the sale.
     */
    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    /**
     * @dev Updates the baseURI that will be used to retrieve NFT metadata.
     * @param baseURI_ The baseURI to be used.
     */
    function setBaseURI(string memory baseURI_) external onlyOwner {
        _baseURIextended = baseURI_;
    }

    /**
     * @dev Sets whether or not the NFT sale is active.
     * @param isActive Whether or not the sale will be active.
     */
    function setSaleIsActive(bool isActive) external onlyOwner {
        saleIsActive = isActive;
    }

    /**
     * @dev Sets the price of each NFT during the initial sale.
     * @param price The price of each NFT during the initial sale | precision:18
     */
    function setCurrentPrice(uint256 price) external onlyOwner {
        currentPrice = price;
    }

    /**
     * @dev Sets the maximum number of NFTs that can be sold to a specific address.
     * @param limit The maximum number of NFTs that be bought by a wallet.
     */
    function setWalletLimit(uint256 limit) external onlyOwner {
        walletLimit = limit;
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

    // Required Overrides

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }

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

