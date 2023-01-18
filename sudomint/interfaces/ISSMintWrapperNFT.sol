// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC721/extensions/IERC721Enumerable.sol";
import "openzeppelin/token/ERC721/IERC721.sol";

interface ISSMintWrapperNFT is IERC721, IERC721Enumerable {
    /**
     * @notice This accessor function is used to get the parent NFT contract that 
     * this wrapper mints.
     * @return address the contract address of the SSMintableNFT compliant smart cotnract.
     */
    function getMintContract() external returns (address);
}