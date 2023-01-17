// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.12;

import "@solmate/utils/ReentrancyGuard.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import {OdysseyLaunchPlatform} from "./OdysseyLaunchPlatform.sol";
import {OdysseyDatabase} from "./data/OdysseyDatabase.sol";
import {OdysseyTokenFactory} from "./factory/OdysseyTokenFactory.sol";
import {OdysseyLib} from "./libraries/OdysseyLib.sol";
import {OdysseyXpDirectory} from "./OdysseyXpDirectory.sol";
import {OdysseyXp} from "./OdysseyXp.sol";

contract OdysseyRouter is OdysseyDatabase, ReentrancyGuard {
    error OdysseyRouter_TokenIDSupplyMismatch();
    error OdysseyRouter_WhitelistUpdateFail();
    error OdysseyRouter_Unauthorized();
    error OdysseyRouter_OwnerMintFailure();
    error OdysseyRouter_BadTokenAddress();
    error OdysseyRouter_BadOwnerAddress();
    error OdysseyRouter_BadSenderAddress();
    error OdysseyRouter_BadRecipientAddress();
    error OdysseyRouter_BadTreasuryAddress();
    error OdysseyRouter_BadAdminAddress();

    constructor(
        address treasury_,
        address xpDirectory_,
        address xp_,
        address[] memory ohmCurrencies_
    ) {
        launchPlatform = address(new OdysseyLaunchPlatform());
        factory = address(new OdysseyTokenFactory());
        treasury = treasury_;
        admin = msg.sender;
        uint256 i;
        for (; i < ohmCurrencies_.length; i++) {
            ohmFamilyCurrencies[ohmCurrencies_[i]] = 1;
        }
        if (xp_ == address(0)) {
            if (xpDirectory_ == address(0)) {
                xpDirectory_ = address(new OdysseyXpDirectory());
                OdysseyXpDirectory(xpDirectory_).setDefaultRewards(
                    1,
                    1,
                    1,
                    3,
                    3,
                    1
                );
                OdysseyXpDirectory(xpDirectory_).transferOwnership(admin);
            }
            xp_ = address(
                new OdysseyXp(
                    ERC20(ohmCurrencies_[0]),
                    OdysseyXpDirectory(xpDirectory_),
                    address(this),
                    address(this),
                    admin
                )
            );
        }
        xp = xp_;
    }

    function Factory() public view returns (OdysseyTokenFactory) {
        return OdysseyTokenFactory(readSlotAsAddress(1));
    }

    function create1155(
        string calldata name,
        string calldata symbol,
        string calldata baseURI,
        OdysseyLib.Odyssey1155Info calldata info,
        OdysseyLib.Percentage calldata treasuryPercentage,
        address royaltyReceiver,
        bool whitelist
    ) external returns (address token) {
        if (info.maxSupply.length != info.tokenIds.length) {
            revert OdysseyRouter_TokenIDSupplyMismatch();
        }
        token = Factory().create1155(msg.sender, name, symbol, baseURI);
        ownerOf[token] = msg.sender;
        whitelistActive[token] = whitelist ? 1 : 0;
        royaltyRecipient[token] = royaltyReceiver;
        uint256 i;
        for (; i < info.tokenIds.length; ++i) {
            maxSupply1155[token][info.tokenIds[i]] = (info.maxSupply[i] == 0)
                ? type(uint256).max
                : info.maxSupply[i];
        }

        domainSeparator[token] = keccak256(
            abi.encode(
                // keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')
                0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                keccak256(bytes(Strings.toHexString(uint160(token)))),
                0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6, // keccak256(bytes("1"))
                block.chainid,
                token
            )
        );

        if (OdysseyLib.compareDefaultPercentage(treasuryPercentage)) {
            // Treasury % was greater than 3/100
            treasuryCommission[token] = treasuryPercentage;
        } else {
            // Treasury % was less than 3/100, using 3/100 as default
            treasuryCommission[token] = OdysseyLib.Percentage(3, 100);
        }

        if (info.reserveAmounts.length > 0) {
            (bool success, bytes memory data) = launchPlatform.delegatecall(
                abi.encodeWithSignature(
                    "mint1155OnCreate(uint256[],uint256[],address)",
                    info.tokenIds,
                    info.reserveAmounts,
                    token
                )
            );
            if (!success) {
                if (data.length == 0) revert();
                assembly {
                    revert(add(32, data), mload(data))
                }
            }
        }
        return token;
    }

    function create721(
        string calldata name,
        string calldata symbol,
        string calldata baseURI,
        uint256 maxSupply,
        uint256 reserveAmount,
        OdysseyLib.Percentage calldata treasuryPercentage,
        address royaltyReceiver,
        bool whitelist
    ) external returns (address token) {
        token = Factory().create721(msg.sender, name, symbol, baseURI);
        ownerOf[token] = msg.sender;
        maxSupply721[token] = (maxSupply == 0) ? type(uint256).max : maxSupply;
        whitelistActive[token] = whitelist ? 1 : 0;
        royaltyRecipient[token] = royaltyReceiver;
        domainSeparator[token] = keccak256(
            abi.encode(
                // keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')
                0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                keccak256(bytes(Strings.toHexString(uint160(token)))),
                0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6, // keccak256(bytes("1"))
                block.chainid,
                token
            )
        );

        if (OdysseyLib.compareDefaultPercentage(treasuryPercentage)) {
            // Treasury % was greater than 3/100
            treasuryCommission[token] = treasuryPercentage;
        } else {
            // Treasury % was less than 3/100, using 3/100 as default
            treasuryCommission[token] = OdysseyLib.Percentage(3, 100);
        }

        if (reserveAmount > 0) {
            (bool success, bytes memory data) = launchPlatform.delegatecall(
                abi.encodeWithSignature(
                    "mint721OnCreate(uint256,address)",
                    reserveAmount,
                    token
                )
            );
            if (!success) {
                if (data.length == 0) revert();
                assembly {
                    revert(add(32, data), mload(data))
                }
            }
        }

        return token;
    }

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
    ) public payable {
        (bool success, bytes memory data) = launchPlatform.delegatecall(
            abi.encodeWithSignature(
                "mintERC721(bytes32[],bytes32,uint256,uint256,address,address,uint8,bytes32,bytes32)",
                merkleProof,
                merkleRoot,
                minPrice,
                mintsPerUser,
                tokenAddress,
                currency,
                v,
                r,
                s
            )
        );
        if (!success) {
            if (data.length == 0) revert();
            assembly {
                revert(add(32, data), mload(data))
            }
        }
    }

    function batchMintERC721(OdysseyLib.BatchMint calldata batch)
        public
        payable
    {
        for (uint256 i = 0; i < batch.tokenAddress.length; i++) {
            (bool success, bytes memory data) = launchPlatform.delegatecall(
                abi.encodeWithSignature(
                    "mintERC721(bytes32[],bytes32,uint256,uint256,address,address,uint8,bytes32,bytes32)",
                    batch.merkleProof[i],
                    batch.merkleRoot[i],
                    batch.minPrice[i],
                    batch.mintsPerUser[i],
                    batch.tokenAddress[i],
                    batch.currency[i],
                    batch.v[i],
                    batch.r[i],
                    batch.s[i]
                )
            );
            if (!success) {
                if (data.length == 0) revert();
                assembly {
                    revert(add(32, data), mload(data))
                }
            }
        }
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
    ) public payable {
        (bool success, bytes memory data) = launchPlatform.delegatecall(
            abi.encodeWithSignature(
                "reserveERC721(bytes32[],bytes32,uint256,uint256,address,address,uint8,bytes32,bytes32)",
                merkleProof,
                merkleRoot,
                minPrice,
                mintsPerUser,
                tokenAddress,
                currency,
                v,
                r,
                s
            )
        );
        if (!success) {
            if (data.length == 0) revert();
            assembly {
                revert(add(32, data), mload(data))
            }
        }
    }

    function batchReserveERC721(OdysseyLib.BatchMint calldata batch)
        public
        payable
    {
        for (uint256 i = 0; i < batch.tokenAddress.length; i++) {
            (bool success, bytes memory data) = launchPlatform.delegatecall(
                abi.encodeWithSignature(
                    "reserveERC721(bytes32[],bytes32,uint256,uint256,address,address,uint8,bytes32,bytes32)",
                    batch.merkleProof[i],
                    batch.merkleRoot[i],
                    batch.minPrice[i],
                    batch.mintsPerUser[i],
                    batch.tokenAddress[i],
                    batch.currency[i],
                    batch.v[i],
                    batch.r[i],
                    batch.s[i]
                )
            );
            if (!success) {
                if (data.length == 0) revert();
                assembly {
                    revert(add(32, data), mload(data))
                }
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
    ) public payable {
        (bool success, bytes memory data) = launchPlatform.delegatecall(
            abi.encodeWithSignature(
                "mintERC1155(bytes32[],bytes32,uint256,uint256,uint256,address,address,uint8,bytes32,bytes32)",
                merkleProof,
                merkleRoot,
                minPrice,
                mintsPerUser,
                tokenId,
                tokenAddress,
                currency,
                v,
                r,
                s
            )
        );
        if (!success) {
            if (data.length == 0) revert();
            assembly {
                revert(add(32, data), mload(data))
            }
        }
    }

    function batchMintERC1155(OdysseyLib.BatchMint calldata batch)
        public
        payable
    {
        for (uint256 i = 0; i < batch.tokenAddress.length; i++) {
            (bool success, bytes memory data) = launchPlatform.delegatecall(
                abi.encodeWithSignature(
                    "mintERC1155(bytes32[],bytes32,uint256,uint256,uint256,address,address,uint8,bytes32,bytes32)",
                    batch.merkleProof[i],
                    batch.merkleRoot[i],
                    batch.minPrice[i],
                    batch.mintsPerUser[i],
                    batch.tokenId[i],
                    batch.tokenAddress[i],
                    batch.currency[i],
                    batch.v[i],
                    batch.r[i],
                    batch.s[i]
                )
            );
            if (!success) {
                if (data.length == 0) revert();
                assembly {
                    revert(add(32, data), mload(data))
                }
            }
        }
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
    ) public payable {
        (bool success, bytes memory data) = launchPlatform.delegatecall(
            abi.encodeWithSignature(
                "reserveERC1155(bytes32[],bytes32,uint256,uint256,uint256,address,address,uint8,bytes32,bytes32)",
                merkleProof,
                merkleRoot,
                minPrice,
                mintsPerUser,
                tokenId,
                tokenAddress,
                currency,
                v,
                r,
                s
            )
        );
        if (!success) {
            if (data.length == 0) revert();
            assembly {
                revert(add(32, data), mload(data))
            }
        }
    }

    function batchReserveERC1155(OdysseyLib.BatchMint calldata batch)
        public
        payable
    {
        for (uint256 i = 0; i < batch.tokenAddress.length; i++) {
            (bool success, bytes memory data) = launchPlatform.delegatecall(
                abi.encodeWithSignature(
                    "reserveERC1155(bytes32[],bytes32,uint256,uint256,uint256,address,address,uint8,bytes32,bytes32)",
                    batch.merkleProof[i],
                    batch.merkleRoot[i],
                    batch.minPrice[i],
                    batch.mintsPerUser[i],
                    batch.tokenId[i],
                    batch.tokenAddress[i],
                    batch.currency[i],
                    batch.v[i],
                    batch.r[i],
                    batch.s[i]
                )
            );
            if (!success) {
                if (data.length == 0) revert();
                assembly {
                    revert(add(32, data), mload(data))
                }
            }
        }
    }

    function setWhitelistStatus(address addr, bool active) public {
        if (msg.sender != ownerOf[addr]) {
            revert OdysseyRouter_Unauthorized();
        }
        (bool success, ) = launchPlatform.delegatecall(
            abi.encodeWithSignature(
                "setWhitelistStatus(address,bool)",
                addr,
                active
            )
        );
        if (!success) {
            revert OdysseyRouter_WhitelistUpdateFail();
        }
    }

    function ownerMint721(address token, address to) public {
        if (ownerOf[token] != msg.sender) {
            revert OdysseyRouter_Unauthorized();
        }
        (bool success, ) = launchPlatform.delegatecall(
            abi.encodeWithSignature("ownerMint721(address,address)", token, to)
        );
        if (!success) {
            revert OdysseyRouter_OwnerMintFailure();
        }
    }

    function ownerMint1155(
        uint256 id,
        uint256 amount,
        address token,
        address to
    ) public {
        if (ownerOf[token] != msg.sender) {
            revert OdysseyRouter_Unauthorized();
        }
        (bool success, ) = launchPlatform.delegatecall(
            abi.encodeWithSignature(
                "ownerMint1155(uint256,uint256,address,address)",
                id,
                amount,
                token,
                to
            )
        );
        if (!success) {
            revert OdysseyRouter_OwnerMintFailure();
        }
    }

    function setOwnerShip(address token, address newOwner) public {
        if (token == address(0)) {
            revert OdysseyRouter_BadTokenAddress();
        }
        if (newOwner == address(0)) {
            revert OdysseyRouter_BadOwnerAddress();
        }
        if (msg.sender == address(0)) {
            revert OdysseyRouter_BadSenderAddress();
        }
        if (ownerOf[token] != msg.sender) {
            revert OdysseyRouter_Unauthorized();
        }
        ownerOf[token] = newOwner;
    }

    function setRoyaltyRecipient(address token, address recipient) public {
        if (token == address(0)) {
            revert OdysseyRouter_BadTokenAddress();
        }
        if (recipient == address(0)) {
            revert OdysseyRouter_BadRecipientAddress();
        }
        if (msg.sender == address(0)) {
            revert OdysseyRouter_BadSenderAddress();
        }
        if (ownerOf[token] != msg.sender) {
            revert OdysseyRouter_Unauthorized();
        }
        royaltyRecipient[token] = recipient;
    }

    function setTreasury(address newTreasury) public {
        if (msg.sender != admin) {
            revert OdysseyRouter_Unauthorized();
        }
        if (msg.sender == address(0)) {
            revert OdysseyRouter_BadSenderAddress();
        }
        if (newTreasury == address(0)) {
            revert OdysseyRouter_BadTreasuryAddress();
        }
        treasury = newTreasury;
    }

    function setXP(address newXp) public {
        if (msg.sender != admin) {
            revert OdysseyRouter_Unauthorized();
        }
        if (msg.sender == address(0)) {
            revert OdysseyRouter_BadSenderAddress();
        }
        if (newXp == address(0)) {
            revert OdysseyRouter_BadTokenAddress();
        }
        xp = newXp;
    }

    function setAdmin(address newAdmin) public {
        if (msg.sender != admin) {
            revert OdysseyRouter_Unauthorized();
        }
        if (msg.sender == address(0)) {
            revert OdysseyRouter_BadSenderAddress();
        }
        if (newAdmin == address(0)) {
            revert OdysseyRouter_BadAdminAddress();
        }
        admin = newAdmin;
    }

    function setMaxSupply721(address token, uint256 amount) public {
        if (ownerOf[token] != msg.sender) {
            revert OdysseyRouter_Unauthorized();
        }
        maxSupply721[token] = amount;
    }

    function setMaxSupply1155(
        address token,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts
    ) public {
        if (ownerOf[token] != msg.sender) {
            revert OdysseyRouter_Unauthorized();
        }
        uint256 i;
        for (; i < tokenIds.length; ++i) {
            maxSupply1155[token][tokenIds[i]] = amounts[i];
        }
    }
}
