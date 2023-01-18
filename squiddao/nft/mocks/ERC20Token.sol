// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Token is ERC20 {
    constructor() ERC20("Token", "TK") {}

    function mint(address receiver, uint256 amount)
        external
        returns (uint256 tokenId)
    {
        tokenId = totalSupply();
        _mint(receiver, amount);
    }
}
