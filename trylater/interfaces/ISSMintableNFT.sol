// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC721/IERC721.sol";

interface ISSMintableNFT is IERC721 {
    /**
     * @notice This function is to be used by the Sudoswap Mint Wrapper contract. The 
     * PermissionedMint function should mint one NFT token on behalf of the user.
     * @param receiver_ the wallet address to send the newly minted NFT to.
     */
    function permissionedMint(address receiver_) external;
}