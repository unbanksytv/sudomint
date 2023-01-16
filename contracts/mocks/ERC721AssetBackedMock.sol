

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { FloorPrice } from "../floorprice.sol";


contract ERC721AssetBackedMock is FloorPrice {

    constructor(address asset_, uint256 backingAmount_, string memory name_, string memory symbol_) 
    FloorPrice(asset_, backingAmount_, name_, symbol_) {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId) public {
        _burn(tokenId);
    }
}