// SPDX-License-Identifier: MIT

pragma solidity >=0.8.12;

import "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

library MerkleWhiteList {
    function verify(
        address sender,
        bytes32[] calldata merkleProof,
        bytes32 merkleRoot
    ) internal pure {
        // Verify whitelist
        require(address(0) != sender);
        bytes32 leaf = keccak256(abi.encodePacked(sender));
        require(
            MerkleProof.verify(merkleProof, merkleRoot, leaf),
            "Not whitelisted"
        );
    }
}
