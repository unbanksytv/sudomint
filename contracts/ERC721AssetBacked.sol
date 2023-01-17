//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC721AssetBacked is ERC721 {

//asset used to back token
address public immutable OHM;
uint256 public immutable backingAmount;

constructor(address OHM_, uint256 backingAmount_, string memory name_, string memory symbol_) ERC721(name_, symbol_) {
OHM = OHM_;
backingAmount = backingAmount_;
}

function _mint(address to, uint256 tokenId) internal virtual override{
IERC20(OHM).transferFrom(to, address(this), backingAmount);
ERC721._mint(to, tokenId);
}

function _burn(uint256 tokenId) internal virtual override{
address owner = ERC721.ownerOf(tokenId);
IERC20(OHM).transfer(owner, backingAmount);
ERC721._burn(tokenId);
}
}