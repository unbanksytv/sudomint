//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract BondStyle721A is ERC721 {
    address public treasury;  // Address of the treasury contract
    using SafeMath for uint256;
    mapping(address => mapping (uint256 => bool)) public tokenOfOwner;
    mapping(uint256 => uint256) public tokenPrice;
    uint256 public totalSupply;
    constructor(address _treasury, string memory name_, string memory symbol_) ERC721(name_, symbol_) {
        treasury = _treasury;
        totalSupply = 0;
    }

    function mint(address to, uint256 _tokenId, uint256 _price) public {
        require(msg.sender == treasury);
        require(_tokenId > totalSupply);
        require(_price > 0);
        totalSupply = totalSupply.add(1);
        tokenOfOwner[to][_tokenId] = true;
        tokenPrice[_tokenId] = _price;
        emit Transfer(address(0), to, _tokenId);
    }

    function sell(uint256 _tokenId) public {
        require(tokenOfOwner[msg.sender][_tokenId]);
        address seller = msg.sender;
        IERC20(treasury).transfer(seller, tokenPrice[_tokenId]);
        tokenOfOwner[seller][_tokenId] = false;
        emit Transfer(seller, address(0), _tokenId);
    }

    function approve(address _to, uint256 _tokenId) public override {
        require(tokenOfOwner[msg.sender][_tokenId]);
        require(_to != address(0));
        emit Approval(msg.sender, _to, _tokenId);
    }
}
