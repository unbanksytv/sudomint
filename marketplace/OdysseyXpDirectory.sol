// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.12;
import {OdysseyERC1155} from "./tokens/OdysseyERC1155.sol";
import {OdysseyERC721} from "./tokens/OdysseyERC721.sol";
import {ERC165Checker} from "../lib/openzeppelin-contracts/contracts/utils/introspection/ERC165Checker.sol";

struct Rewards {
    uint256 sale;
    uint256 purchase;
    uint256 mint;
    uint256 ohmPurchase;
    uint256 ohmMint;
    uint256 multiplier;
}

struct NFT {
    address contractAddress;
    uint256 id;
}

enum NftType {
    ERC721,
    ERC1155
}

error OdysseyXpDirectory_Unauthorized();

contract OdysseyXpDirectory {
    using ERC165Checker for address;

    Rewards public defaultRewards;
    mapping(address => Rewards) public erc721rewards;
    mapping(address => mapping(uint256 => Rewards)) public erc1155rewards;
    NFT[] public customRewardTokens;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    // modifier substitute
    function notOwner() internal view returns (bool) {
        return msg.sender != owner;
    }

    function transferOwnership(address newOwner) external {
        if (notOwner()) revert OdysseyXpDirectory_Unauthorized();
        owner = newOwner;
    }

    /*///////////////////////////////////////////////////////////////
                            Reward Setters
    //////////////////////////////////////////////////////////////*/

    /// @notice Set default rewards for contracts without a custom reward set
    /// @param sale XP reward for selling an NFT
    /// @param purchase XP reward for purchasing an NFT
    /// @param mint XP reward for minting an NFT
    /// @param ohmPurchase XP reward for purchasing an NFT with OHM
    /// @param ohmMint XP reward for minting an NFT with OHM
    /// @param multiplier XP reward multiplier for wallets holding an NFT
    function setDefaultRewards(
        uint256 sale,
        uint256 purchase,
        uint256 mint,
        uint256 ohmPurchase,
        uint256 ohmMint,
        uint256 multiplier
    ) public {
        if (notOwner()) revert OdysseyXpDirectory_Unauthorized();
        defaultRewards = Rewards(
            sale,
            purchase,
            mint,
            ohmPurchase,
            ohmMint,
            multiplier
        );
    }

    /// @notice Set custom rewards for an ERC721 contract
    /// @param sale XP reward for selling this NFT
    /// @param purchase XP reward for purchasing this NFT
    /// @param mint XP reward for minting this NFT
    /// @param ohmPurchase XP reward for purchasing this NFT with OHM
    /// @param ohmMint XP reward for minting this NFT with OHM
    /// @param multiplier XP reward multiplier for wallets holding this NFT
    function setErc721CustomRewards(
        address tokenAddress,
        uint256 sale,
        uint256 purchase,
        uint256 mint,
        uint256 ohmPurchase,
        uint256 ohmMint,
        uint256 multiplier
    ) public {
        if (notOwner()) revert OdysseyXpDirectory_Unauthorized();
        customRewardTokens.push(NFT(tokenAddress, 0));
        erc721rewards[tokenAddress] = Rewards(
            sale,
            purchase,
            mint,
            ohmPurchase,
            ohmMint,
            multiplier
        );
    }

    /// @notice Set custom rewards for an ERC1155 contract and token ID
    /// @param sale XP reward for selling this NFT
    /// @param purchase XP reward for purchasing this NFT
    /// @param mint XP reward for minting this NFT
    /// @param ohmPurchase XP reward for purchasing this NFT with OHM
    /// @param ohmMint XP reward for minting this NFT with OHM
    /// @param multiplier XP reward multiplier for wallets holding this NFT
    function setErc1155CustomRewards(
        address tokenAddress,
        uint256 tokenId,
        uint256 sale,
        uint256 purchase,
        uint256 mint,
        uint256 ohmPurchase,
        uint256 ohmMint,
        uint256 multiplier
    ) public {
        if (notOwner()) revert OdysseyXpDirectory_Unauthorized();
        customRewardTokens.push(NFT(tokenAddress, tokenId));
        erc1155rewards[tokenAddress][tokenId] = Rewards(
            sale,
            purchase,
            mint,
            ohmPurchase,
            ohmMint,
            multiplier
        );
    }

    /*///////////////////////////////////////////////////////////////
                            Reward Getters
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the XP reward for selling an NFT
    /// @param seller Seller of the NFT
    /// @param contractAddress Address of the NFT being sold
    /// @param tokenId ID of the NFT being sold
    function getSaleReward(
        address seller,
        address contractAddress,
        uint256 tokenId
    ) public view returns (uint256) {
        (
            bool isCustomErc721,
            bool isCustomErc1155,
            uint256 multiplier
        ) = _getRewardDetails(seller, contractAddress, tokenId);
        if (isCustomErc721) {
            return erc721rewards[contractAddress].sale * multiplier;
        } else if (isCustomErc1155) {
            return erc1155rewards[contractAddress][tokenId].sale * multiplier;
        } else {
            return defaultRewards.sale * multiplier;
        }
    }

    /// @notice Get the XP reward for buying an NFT
    /// @param buyer Buyer of the NFT
    /// @param contractAddress Address of the NFT being sold
    /// @param tokenId ID of the NFT being sold
    function getPurchaseReward(
        address buyer,
        address contractAddress,
        uint256 tokenId
    ) public view returns (uint256) {
        (
            bool isCustomErc721,
            bool isCustomErc1155,
            uint256 multiplier
        ) = _getRewardDetails(buyer, contractAddress, tokenId);
        if (isCustomErc721) {
            return erc721rewards[contractAddress].purchase * multiplier;
        } else if (isCustomErc1155) {
            return
                erc1155rewards[contractAddress][tokenId].purchase * multiplier;
        } else {
            return defaultRewards.purchase * multiplier;
        }
    }

    /// @notice Get the XP reward for minting an NFT
    /// @param buyer Buyer of the NFT
    /// @param contractAddress Address of the NFT being sold
    /// @param tokenId ID of the NFT being sold
    function getMintReward(
        address buyer,
        address contractAddress,
        uint256 tokenId
    ) public view returns (uint256) {
        (
            bool isCustomErc721,
            bool isCustomErc1155,
            uint256 multiplier
        ) = _getRewardDetails(buyer, contractAddress, tokenId);
        if (isCustomErc721) {
            return erc721rewards[contractAddress].mint * multiplier;
        } else if (isCustomErc1155) {
            return erc1155rewards[contractAddress][tokenId].mint * multiplier;
        } else {
            return defaultRewards.mint * multiplier;
        }
    }

    /// @notice Get the XP reward for buying an NFT with OHM
    /// @param buyer Buyer of the NFT
    /// @param contractAddress Address of the NFT being sold
    /// @param tokenId ID of the NFT being sold
    function getOhmPurchaseReward(
        address buyer,
        address contractAddress,
        uint256 tokenId
    ) public view returns (uint256) {
        (
            bool isCustomErc721,
            bool isCustomErc1155,
            uint256 multiplier
        ) = _getRewardDetails(buyer, contractAddress, tokenId);
        if (isCustomErc721) {
            return erc721rewards[contractAddress].ohmPurchase * multiplier;
        } else if (isCustomErc1155) {
            return
                erc1155rewards[contractAddress][tokenId].ohmPurchase *
                multiplier;
        } else {
            return defaultRewards.ohmPurchase * multiplier;
        }
    }

    /// @notice Get the XP reward for minting an NFT with OHM
    /// @param buyer Buyer of the NFT
    /// @param contractAddress Address of the NFT being sold
    /// @param tokenId ID of the NFT being sold
    function getOhmMintReward(
        address buyer,
        address contractAddress,
        uint256 tokenId
    ) public view returns (uint256) {
        (
            bool isCustomErc721,
            bool isCustomErc1155,
            uint256 multiplier
        ) = _getRewardDetails(buyer, contractAddress, tokenId);
        if (isCustomErc721) {
            return erc721rewards[contractAddress].ohmMint * multiplier;
        } else if (isCustomErc1155) {
            return
                erc1155rewards[contractAddress][tokenId].ohmMint * multiplier;
        } else {
            return defaultRewards.ohmMint * multiplier;
        }
    }

    /// @notice Determine if an NFT has custom rewards and any multiplier based on the user's held NFTs
    /// @dev The multiplier and custom rewards are determined simultaneously to save on gas costs of iteration
    /// @param user Wallet address with potential multiplier NFTs
    /// @param contractAddress Address of the NFT being sold
    /// @param tokenId ID of the NFT being sold
    function _getRewardDetails(
        address user,
        address contractAddress,
        uint256 tokenId
    )
        internal
        view
        returns (
            bool isCustomErc721,
            bool isCustomErc1155,
            uint256 multiplier
        )
    {
        NFT[] memory _customRewardTokens = customRewardTokens; // save an SLOAD from length reading
        for (uint256 i = 0; i < _customRewardTokens.length; i++) {
            NFT memory token = _customRewardTokens[i];
            if (token.contractAddress.supportsInterface(0x80ac58cd)) {
                // is ERC721
                if (OdysseyERC721(token.contractAddress).balanceOf(user) > 0) {
                    uint256 reward = erc721rewards[token.contractAddress]
                        .multiplier;
                    multiplier = reward > 1 ? multiplier + reward : multiplier; // only increment if multiplier is non-one
                }
                if (contractAddress == token.contractAddress) {
                    isCustomErc721 = true;
                }
            } else if (token.contractAddress.supportsInterface(0xd9b67a26)) {
                // is isERC1155
                if (
                    OdysseyERC1155(token.contractAddress).balanceOf(
                        user,
                        token.id
                    ) > 0
                ) {
                    uint256 reward = erc1155rewards[token.contractAddress][
                        token.id
                    ].multiplier;
                    multiplier = reward > 1 ? multiplier + reward : multiplier; // only increment if multiplier is non-one
                    if (
                        contractAddress == token.contractAddress &&
                        tokenId == token.id
                    ) {
                        isCustomErc1155 = true;
                    }
                }
            }
        }
        multiplier = multiplier == 0 ? defaultRewards.multiplier : multiplier; // if no custom multiplier, use default
        multiplier = multiplier > 4 ? 4 : multiplier; // multiplier caps at 4
    }
}
