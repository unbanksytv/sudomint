// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Rebaseable721 {
    // event to emit when new NFTs are minted and distributed
    event Mint(address indexed to, uint256 tokenId);
    // mapping from token ID to owner address
    mapping(uint256 => address) public tokenOwner;
    // array to store total supply of NFTs
    uint256[] public tokenSupply;
    // variable to store current supply
    uint256 public currentSupply;
    // variable to store total supply cap
    uint256 public totalSupplyCap;
    // array to store genesis collection holders
    address[] public genesisCollectionHolders;

    constructor() public {
        totalSupplyCap = 3300;
    }

    function mint(address _to) public {
        require(currentSupply < totalSupplyCap, "Cannot mint more tokens, total supply cap reached");
        // mint new NFT
        uint256 tokenId = tokenSupply.push(1) - 1;
        // assign NFT to user
        tokenOwner[tokenId] = _to;
        currentSupply++;
        // emit event to notify of new mint
        emit Mint(_to, tokenId);
    }

    function distribute() public {
        // loop through genesis collection holders and airdrop new NFT
        for (uint i = 0; i < genesisCollectionHolders.length; i++) {
            address holder = genesisCollectionHolders[i];
            // check if holder is still valid
            require(holder.isValid(), "Invalid address");
            // mint new NFT and assign to holder
            mint(holder);
        }
    }

    function rebase() public {
        // calculate number of NFTs to distribute
        uint256 numToDistribute = 2 ** (now / (33 days));
        // distribute new NFTs to holders
        for (uint i = 0; i < numToDistribute; i++) {
            distribute();
        }
    }
}
