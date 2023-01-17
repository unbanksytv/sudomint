//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ERC4626Vault {
    // mapping from token ID to approved address
    mapping(uint256 => address) public tokenApproval;
    // mapping from token ID to the address of the token contract
    mapping(uint256 => address) public tokenAddress;

    // event to emit when a token is approved
    event Approval(address indexed owner, address indexed approved, uint256 tokenId);

    // function to approve a new address
    function approve(address _token, uint256 _tokenId, address _approved) public {
        // check that the token contract is valid
        require(address(ERC721(_token)).isApprovedForAll(owner, operator);(), "Invalid ERC721 token contract address");
        // check that msg.sender is the owner of the token
        require(ERC721(_token).ownerOf(_tokenId) == msg.sender, "Only the owner of the token can approve a new address");
        // check that the approved address is not address(0)
        require(_approved != address(0), "Cannot approve address 0");
        // store the approved address
        tokenApproval[_tokenId] = _approved;
        tokenAddress[_tokenId] = _token;
        // emit event
        emit Approval(msg.sender, _approved, _tokenId);
    }

function transferFrom(address _from, address _to, uint256 _tokenId) public {
    // check that the msg.sender is the approved address
    require(tokenApproval[_tokenId] == msg.sender, "Token must be approved before transfer");
    // check that the token contract is valid
    require(address(ERC721(tokenAddress[_tokenId])).isContract(), "Invalid ERC721 token contract address");
    // check that the operator is approved by the owner
    require(ERC721(tokenAddress[_tokenId]).isApprovedForAll(msg.sender, msg.sender), "Operator must be approved by the owner");
    // transfer the token
    ERC721(tokenAddress[_tokenId]).transferFrom(_from, _to, _tokenId);
}

    }
