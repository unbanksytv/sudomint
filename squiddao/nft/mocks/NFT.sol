// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract NFT is ERC721Enumerable {
    constructor() ERC721("NFT", "NFT") {}

    function mintOne(address receiver) external returns (uint256 tokenId) {
        tokenId = totalSupply();
        _safeMint(receiver, tokenId);
    }
}
