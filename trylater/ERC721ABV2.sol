//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ERC721AssetBacked is ERC721 {
    address public immutable OHM;
    using SafeMath for uint256;
    mapping(address => mapping (uint256 => bool)) public tokenOfOwner;
    mapping(address => uint256) private balanceOf;
    uint256 public totalSupply;
    constructor(address OHM_, string memory name_, string memory symbol_) ERC721(name_, symbol_) {
        OHM = OHM_;
        totalSupply = 0;
    }

    function mint(address to, uint256 amount) public {
        require(amount > 0);
        require(IERC20(OHM).transferFrom(msg.sender, address(this), amount));
        totalSupply = totalSupply.add(1);
        balanceOf[to] = balanceOf[to].add(1);
        tokenOfOwner[to][totalSupply] = true;
        emit Transfer(address(0), to, totalSupply);
    }

    function burn(uint256 tokenId) public {
        require(tokenOfOwner[msg.sender][tokenId]);
        require(balanceOf[msg.sender] > 0);
        IERC20(OHM).transfer(msg.sender, price(tokenId));
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(1);
        tokenOfOwner[msg.sender][tokenId] = false;
        emit Transfer(msg.sender, address(0), tokenId);
    }

    function approve(address _to, uint256 _tokenId) public override {
        require(tokenOfOwner[msg.sender][_tokenId]);
        require(_to != address(0));
        emit Approval(msg.sender, _to, _tokenId);
    }

    function price(uint256 _tokenId) public view returns(uint256) {
        // This function should return the price of a specific token ID, 
        // how you want to determine the price is up to you.
        return 0;
    }
}
