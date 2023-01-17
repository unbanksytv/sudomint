// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.12;

import "./libraries/Signature.sol";
import "./libraries/MerkleWhitelist.sol";
import "@solmate/utils/ReentrancyGuard.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {OdysseyERC721} from "./tokens/OdysseyERC721.sol";
import {OdysseyERC1155} from "./tokens/OdysseyERC1155.sol";
import {OdysseyTokenFactory} from "./factory/OdysseyTokenFactory.sol";
import {OdysseyDatabase} from "./data/OdysseyDatabase.sol";
import {OdysseyLib} from "./libraries/OdysseyLib.sol";
import {OdysseyXp} from "./OdysseyXp.sol";

contract OdysseyLaunchPlatform is OdysseyDatabase, ReentrancyGuard {
    /*///////////////////////////////////////////////////////////////
                                ACTIONS
    //////////////////////////////////////////////////////////////*/
    function mintERC721(
        bytes32[] calldata merkleProof,
        bytes32 merkleRoot,
        uint256 minPrice,
        uint256 mintsPerUser,
        address tokenAddress,
        address currency,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable nonReentrant {
        if (OdysseyTokenFactory(factory).tokenExists(tokenAddress) == 0) {
            revert OdysseyLaunchPlatform_TokenDoesNotExist();
        }
        if (whitelistClaimed721[tokenAddress][msg.sender] >= mintsPerUser) {
            revert OdysseyLaunchPlatform_AlreadyClaimed();
        }
        // Check if user is already reserved + paid
        if (isReserved721[tokenAddress][msg.sender] == 0) {
            if (
                cumulativeSupply721[tokenAddress] >= maxSupply721[tokenAddress]
            ) {
                revert OdysseyLaunchPlatform_MaxSupplyCap();
            }
            {
                // Verify merkle root and minPrice signed by owner (all id's have same min price)
                bytes32 hash = keccak256(
                    abi.encode(
                        MERKLE_TREE_ROOT_ERC721_TYPEHASH,
                        merkleRoot,
                        minPrice,
                        mintsPerUser,
                        tokenAddress,
                        currency
                    )
                );
                Signature.verify(
                    hash,
                    ownerOf[tokenAddress],
                    v,
                    r,
                    s,
                    domainSeparator[tokenAddress]
                );
            }
            if (whitelistActive[tokenAddress] == 1) {
                // Verify user whitelisted
                MerkleWhiteList.verify(msg.sender, merkleProof, merkleRoot);
            }
            cumulativeSupply721[tokenAddress]++;

            OdysseyLib.Percentage storage percent = treasuryCommission[
                tokenAddress
            ];
            uint256 commission = (minPrice * percent.numerator) /
                percent.denominator;

            if (currency == address(0)) {
                if (msg.value < minPrice) {
                    revert OdysseyLaunchPlatform_InsufficientFunds();
                }
                (bool treasurySuccess, ) = treasury.call{value: commission}("");
                if (!treasurySuccess) {
                    revert OdysseyLaunchPlatform_TreasuryPayFailure();
                }
                (bool success, ) = royaltyRecipient[tokenAddress].call{
                    value: minPrice - commission
                }("");
                if (!success) {
                    revert OdysseyLaunchPlatform_FailedToPayEther();
                }
            } else {
                if (
                    ERC20(currency).allowance(msg.sender, address(this)) <
                    minPrice
                ) {
                    revert OdysseyLaunchPlatform_InsufficientFunds();
                }
                bool result = ERC20(currency).transferFrom(
                    msg.sender,
                    treasury,
                    commission
                );
                if (!result) {
                    revert OdysseyLaunchPlatform_TreasuryPayFailure();
                }
                result = ERC20(currency).transferFrom(
                    msg.sender,
                    royaltyRecipient[tokenAddress],
                    minPrice - commission
                );
                if (!result) {
                    revert OdysseyLaunchPlatform_FailedToPayERC20();
                }
                if (ohmFamilyCurrencies[currency] == 1) {
                    OdysseyXp(xp).ohmMintReward(msg.sender, tokenAddress, 0);
                }
            }
        } else {
            isReserved721[tokenAddress][msg.sender]--;
        }
        // Update State
        whitelistClaimed721[tokenAddress][msg.sender]++;
        OdysseyERC721(tokenAddress).mint(
            msg.sender,
            mintedSupply721[tokenAddress]++
        );
    }

    function reserveERC721(
        bytes32[] calldata merkleProof,
        bytes32 merkleRoot,
        uint256 minPrice,
        uint256 mintsPerUser,
        address tokenAddress,
        address currency,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable nonReentrant {
        if (OdysseyTokenFactory(factory).tokenExists(tokenAddress) == 0) {
            revert OdysseyLaunchPlatform_TokenDoesNotExist();
        }
        if (cumulativeSupply721[tokenAddress] >= maxSupply721[tokenAddress]) {
            revert OdysseyLaunchPlatform_MaxSupplyCap();
        }
        if (
            isReserved721[tokenAddress][msg.sender] +
                whitelistClaimed721[tokenAddress][msg.sender] >=
            mintsPerUser
        ) {
            revert OdysseyLaunchPlatform_ReservedOrClaimedMax();
        }
        {
            // Verify merkle root and minPrice signed by owner (all id's have same min price)
            bytes32 hash = keccak256(
                abi.encode(
                    MERKLE_TREE_ROOT_ERC721_TYPEHASH,
                    merkleRoot,
                    minPrice,
                    mintsPerUser,
                    tokenAddress,
                    currency
                )
            );
            Signature.verify(
                hash,
                ownerOf[tokenAddress],
                v,
                r,
                s,
                domainSeparator[tokenAddress]
            );
        }
        if (whitelistActive[tokenAddress] == 1) {
            // Verify user whitelisted
            MerkleWhiteList.verify(msg.sender, merkleProof, merkleRoot);
        }

        // Set user is reserved
        isReserved721[tokenAddress][msg.sender]++;
        // Increate Reserved + minted supply
        cumulativeSupply721[tokenAddress]++;

        OdysseyLib.Percentage storage percent = treasuryCommission[
            tokenAddress
        ];
        uint256 commission = (minPrice * percent.numerator) /
            percent.denominator;

        if (currency == address(0)) {
            if (msg.value < minPrice) {
                revert OdysseyLaunchPlatform_InsufficientFunds();
            }
            (bool treasurySuccess, ) = treasury.call{value: commission}("");
            if (!treasurySuccess) {
                revert OdysseyLaunchPlatform_TreasuryPayFailure();
            }
            (bool success, ) = royaltyRecipient[tokenAddress].call{
                value: minPrice - commission
            }("");
            if (!success) {
                revert OdysseyLaunchPlatform_FailedToPayEther();
            }
        } else {
            if (
                ERC20(currency).allowance(msg.sender, address(this)) < minPrice
            ) {
                revert OdysseyLaunchPlatform_InsufficientFunds();
            }
            bool result = ERC20(currency).transferFrom(
                msg.sender,
                treasury,
                commission
            );
            if (!result) {
                revert OdysseyLaunchPlatform_TreasuryPayFailure();
            }
            result = ERC20(currency).transferFrom(
                msg.sender,
                royaltyRecipient[tokenAddress],
                minPrice - commission
            );
            if (!result) {
                revert OdysseyLaunchPlatform_FailedToPayERC20();
            }
            if (ohmFamilyCurrencies[currency] == 1) {
                OdysseyXp(xp).ohmMintReward(msg.sender, tokenAddress, 0);
            }
        }
    }

    function mintERC1155(
        bytes32[] calldata merkleProof,
        bytes32 merkleRoot,
        uint256 minPrice,
        uint256 mintsPerUser,
        uint256 tokenId,
        address tokenAddress,
        address currency,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable nonReentrant {
        if (OdysseyTokenFactory(factory).tokenExists(tokenAddress) == 0) {
            revert OdysseyLaunchPlatform_TokenDoesNotExist();
        }
        if (
            whitelistClaimed1155[tokenAddress][msg.sender][tokenId] >=
            mintsPerUser
        ) {
            revert OdysseyLaunchPlatform_AlreadyClaimed();
        }
        // Check if user is already reserved + paid
        if (isReserved1155[tokenAddress][msg.sender][tokenId] == 0) {
            if (
                cumulativeSupply1155[tokenAddress][tokenId] >=
                maxSupply1155[tokenAddress][tokenId]
            ) {
                revert OdysseyLaunchPlatform_MaxSupplyCap();
            }
            {
                // Verify merkle root and minPrice signed by owner (all id's have same min price)
                bytes32 hash = keccak256(
                    abi.encode(
                        MERKLE_TREE_ROOT_ERC1155_TYPEHASH,
                        merkleRoot,
                        minPrice,
                        mintsPerUser,
                        tokenId,
                        tokenAddress,
                        currency
                    )
                );
                Signature.verify(
                    hash,
                    ownerOf[tokenAddress],
                    v,
                    r,
                    s,
                    domainSeparator[tokenAddress]
                );
            }

            if (whitelistActive[tokenAddress] == 1) {
                // Verify user whitelisted
                MerkleWhiteList.verify(msg.sender, merkleProof, merkleRoot);
            }
            cumulativeSupply1155[tokenAddress][tokenId]++;

            OdysseyLib.Percentage storage percent = treasuryCommission[
                tokenAddress
            ];
            uint256 commission = (minPrice * percent.numerator) /
                percent.denominator;

            if (currency == address(0)) {
                if (msg.value < minPrice) {
                    revert OdysseyLaunchPlatform_InsufficientFunds();
                }
                (bool treasurySuccess, ) = treasury.call{value: commission}("");
                if (!treasurySuccess) {
                    revert OdysseyLaunchPlatform_TreasuryPayFailure();
                }
                (bool success, ) = royaltyRecipient[tokenAddress].call{
                    value: minPrice - commission
                }("");
                if (!success) {
                    revert OdysseyLaunchPlatform_FailedToPayEther();
                }
            } else {
                if (
                    ERC20(currency).allowance(msg.sender, address(this)) <
                    minPrice
                ) {
                    revert OdysseyLaunchPlatform_InsufficientFunds();
                }
                bool result = ERC20(currency).transferFrom(
                    msg.sender,
                    treasury,
                    commission
                );
                if (!result) {
                    revert OdysseyLaunchPlatform_TreasuryPayFailure();
                }
                result = ERC20(currency).transferFrom(
                    msg.sender,
                    royaltyRecipient[tokenAddress],
                    minPrice - commission
                );
                if (!result) {
                    revert OdysseyLaunchPlatform_FailedToPayERC20();
                }
                if (ohmFamilyCurrencies[currency] == 1) {
                    OdysseyXp(xp).ohmMintReward(
                        msg.sender,
                        tokenAddress,
                        tokenId
                    );
                }
            }
        } else {
            isReserved1155[tokenAddress][msg.sender][tokenId]--;
        }
        // Update State
        whitelistClaimed1155[tokenAddress][msg.sender][tokenId]++;

        OdysseyERC1155(tokenAddress).mint(msg.sender, tokenId);
    }

    function reserveERC1155(
        bytes32[] calldata merkleProof,
        bytes32 merkleRoot,
        uint256 minPrice,
        uint256 mintsPerUser,
        uint256 tokenId,
        address tokenAddress,
        address currency,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable nonReentrant {
        if (OdysseyTokenFactory(factory).tokenExists(tokenAddress) == 0) {
            revert OdysseyLaunchPlatform_TokenDoesNotExist();
        }
        if (
            cumulativeSupply1155[tokenAddress][tokenId] >=
            maxSupply1155[tokenAddress][tokenId]
        ) {
            revert OdysseyLaunchPlatform_MaxSupplyCap();
        }
        if (
            isReserved1155[tokenAddress][msg.sender][tokenId] +
                whitelistClaimed1155[tokenAddress][msg.sender][tokenId] >=
            mintsPerUser
        ) {
            revert OdysseyLaunchPlatform_ReservedOrClaimedMax();
        }
        {
            // Verify merkle root and minPrice signed by owner (all id's have same min price)
            bytes32 hash = keccak256(
                abi.encode(
                    MERKLE_TREE_ROOT_ERC1155_TYPEHASH,
                    merkleRoot,
                    minPrice,
                    mintsPerUser,
                    tokenId,
                    tokenAddress,
                    currency
                )
            );
            Signature.verify(
                hash,
                ownerOf[tokenAddress],
                v,
                r,
                s,
                domainSeparator[tokenAddress]
            );
        }

        if (whitelistActive[tokenAddress] == 1) {
            // Verify user whitelisted
            MerkleWhiteList.verify(msg.sender, merkleProof, merkleRoot);
        }

        // Set user is reserved
        isReserved1155[tokenAddress][msg.sender][tokenId]++;
        // Increase Reserved + minted supply
        cumulativeSupply1155[tokenAddress][tokenId]++;

        OdysseyLib.Percentage storage percent = treasuryCommission[
            tokenAddress
        ];
        uint256 commission = (minPrice * percent.numerator) /
            percent.denominator;

        if (currency == address(0)) {
            if (msg.value < minPrice) {
                revert OdysseyLaunchPlatform_InsufficientFunds();
            }
            (bool treasurySuccess, ) = treasury.call{value: commission}("");
            if (!treasurySuccess) {
                revert OdysseyLaunchPlatform_TreasuryPayFailure();
            }
            (bool success, ) = royaltyRecipient[tokenAddress].call{
                value: minPrice - commission
            }("");
            if (!success) {
                revert OdysseyLaunchPlatform_FailedToPayEther();
            }
        } else {
            if (
                ERC20(currency).allowance(msg.sender, address(this)) < minPrice
            ) {
                revert OdysseyLaunchPlatform_InsufficientFunds();
            }
            bool result = ERC20(currency).transferFrom(
                msg.sender,
                treasury,
                commission
            );
            if (!result) {
                revert OdysseyLaunchPlatform_TreasuryPayFailure();
            }
            result = ERC20(currency).transferFrom(
                msg.sender,
                royaltyRecipient[tokenAddress],
                minPrice - commission
            );
            if (!result) {
                revert OdysseyLaunchPlatform_FailedToPayERC20();
            }
            if (ohmFamilyCurrencies[currency] == 1) {
                OdysseyXp(xp).ohmMintReward(msg.sender, tokenAddress, tokenId);
            }
        }
    }

    function setWhitelistStatus(address addr, bool active)
        external
        nonReentrant
    {
        if (OdysseyTokenFactory(factory).tokenExists(addr) == 0) {
            revert OdysseyLaunchPlatform_TokenDoesNotExist();
        }
        whitelistActive[addr] = active ? 1 : 0;
    }

    function mint721OnCreate(uint256 amount, address token)
        external
        nonReentrant
    {
        cumulativeSupply721[token] = amount;
        mintedSupply721[token] = amount;
        uint256 i;
        for (; i < amount; ++i) {
            OdysseyERC721(token).mint(msg.sender, i);
        }
    }

    function mint1155OnCreate(
        uint256[] calldata tokenIds,
        uint256[] calldata amounts,
        address token
    ) external nonReentrant {
        uint256 i;
        for (; i < tokenIds.length; ++i) {
            cumulativeSupply1155[token][tokenIds[i]] = amounts[i];
            OdysseyERC1155(token).mintBatch(
                msg.sender,
                tokenIds[i],
                amounts[i]
            );
        }
    }

    function ownerMint721(address token, address to) external nonReentrant {
        if (cumulativeSupply721[token] >= maxSupply721[token]) {
            revert OdysseyLaunchPlatform_MaxSupplyCap();
        }
        cumulativeSupply721[token]++;
        OdysseyERC721(token).mint(to, mintedSupply721[token]++);
    }

    function ownerMint1155(
        uint256 id,
        uint256 amount,
        address token,
        address to
    ) external nonReentrant {
        if (
            cumulativeSupply1155[token][id] + amount > maxSupply1155[token][id]
        ) {
            revert OdysseyLaunchPlatform_MaxSupplyCap();
        }
        cumulativeSupply1155[token][id] += amount;
        OdysseyERC1155(token).mintBatch(to, id, amount);
    }
}
