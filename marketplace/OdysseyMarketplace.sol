// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.12;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC721} from "@solmate/tokens/ERC721.sol";
import {ERC1155} from "@solmate/tokens/ERC1155.sol";
// todo replace with ownable interface
import {OdysseyERC721} from "@odyssey/tokens/OdysseyERC721.sol";
import {OdysseyXpDirectory} from "./OdysseyXpDirectory.sol";
import {OdysseyXp} from "./OdysseyXp.sol";

//import {console} from "./test/utils/Console.sol";
contract Marketplace {
    error OdysseyMarket_CollectionSize();
    error OdysseyMarket_NotOwner();
    error OdysseyMarket_SetPrice();
    error OdysseyMarket_BadRoyalties();
    error OdysseyMarket_UnknownListing();
    error OdysseyMarket_BuyError();
    error OdysseyMarket_NoSaleApproval();
    error OdysseyMarket_InsufficientFunds();
    error OdysseyMarket_FailedToPayEther();
    error OdysseyMarket_FailedToPayERC20();
    error OdysseyMarket_NotEnoughSupply();
    error OdysseyMarket_BadSender();
    error OdysseyMarket_NoAccess();

    struct PaymentInfo {
        uint256 amount;
        address currencyAddress;
    }
    struct Royalties {
        address receiver;
        uint8 percent;
    }
    struct NewCollection {
        address contractAddress;
        uint256 collectionSize;
        PaymentInfo[] paymentInfo;
        Royalties[] royalties;
    }
    struct CollectionListing {
        mapping(uint256 => uint256) tokenIdSold;
        PaymentInfo[] paymentInfo;
        Royalties[] royalties;
    }
    struct NewListing {
        address contractAddress;
        uint256 tokenId;
        uint256 tokenAmount; // for 1155
        PaymentInfo[] paymentInfo;
        Royalties[] royalties;
        bool isERC1155;
    }
    struct BuyOrder {
        address owner;
        address contractAddress;
        uint256 tokenId;
        uint256 tokenAmount;
        address currencyAddress;
    }
    struct InternalListing {
        uint256 tokenAmount;
        PaymentInfo[] paymentInfo;
        Royalties[] royalties;
        bool isERC1155;
    }
    struct AccessPass {
        uint256[] tokenIds;
        address contractAddress;
        bool isERC1155;
    }

    address xp;
    address public treasury;
    address public admin;
    AccessPass public globalAccessPass;
    mapping(address => mapping(address => CollectionListing)) collectionListings;
    mapping(address => mapping(address => mapping(uint256 => InternalListing)))
        public saleListings;
    mapping(address => mapping(address => AccessPass)) public accessPassMap;
    mapping(address => Royalties[]) public secondaryRoyalties;

    constructor(
        address treasury_,
        address xpDirectory_,
        address xp_,
        address rewardCurrency_
    ) {
        treasury = treasury_;
        admin = msg.sender;
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
                    ERC20(rewardCurrency_),
                    OdysseyXpDirectory(xpDirectory_),
                    address(this),
                    address(this),
                    admin
                )
            );
        }
        xp = xp_;
    }

    function getCollectionListing(
        address owner,
        address contractAddress,
        uint256 tokenId
    ) external view returns (uint256, uint256) {
        CollectionListing storage listing = collectionListings[owner][
            contractAddress
        ];
        return (listing.tokenIdSold[tokenId], listing.paymentInfo.length);
    }

    function setSecondaryRoyalties(
        Royalties[] calldata royalties,
        address contractAddress
    ) external {
        if (OdysseyERC721(contractAddress).owner() != msg.sender) {
            revert OdysseyMarket_NotOwner();
        }
        Royalties[] storage sRoyalties = secondaryRoyalties[contractAddress];
        uint256 i;
        for (; i < royalties.length; ++i) {
            sRoyalties.push(royalties[i]);
        }
    }

    function setGlobalAccessPass(AccessPass calldata pass) external {
        if (msg.sender != admin) {
            revert OdysseyMarket_NoAccess();
        }
        globalAccessPass.contractAddress = pass.contractAddress;
        globalAccessPass.isERC1155 = pass.isERC1155;
        uint256 i;
        for (; i < pass.tokenIds.length; ++i) {
            globalAccessPass.tokenIds.push(pass.tokenIds[i]);
        }
    }

    function clearGlobalAccessPass() external {
        if (msg.sender != admin) {
            revert OdysseyMarket_BadSender();
        }
        globalAccessPass.contractAddress = address(0);
    }

    function setAccessPass(AccessPass calldata pass, address contractAddress)
        external
    {
        if (msg.sender == address(0)) {
            revert OdysseyMarket_BadSender();
        }
        AccessPass storage access = accessPassMap[msg.sender][contractAddress];
        uint256 i;
        for (; i < pass.tokenIds.length; ++i) {
            access.tokenIds.push(pass.tokenIds[i]);
        }
        access.contractAddress = pass.contractAddress;
        access.isERC1155 = pass.isERC1155;
    }

    function clearAccessPass(address contractAddress) external {
        if (msg.sender == address(0)) {
            revert OdysseyMarket_BadSender();
        }
        delete accessPassMap[msg.sender][contractAddress];
    }

    function verifyListing(
        uint256 tokenAmount,
        uint256 tokenId,
        address contractAddress,
        address owner,
        bool isERC1155
    ) public view returns (bool) {
        if (isERC1155) {
            if (
                !ERC1155(contractAddress).isApprovedForAll(owner, address(this))
            ) {
                return false;
            }
        } else {
            if (
                !ERC721(contractAddress).isApprovedForAll(
                    owner,
                    address(this)
                ) &&
                ERC721(contractAddress).getApproved(tokenId) != address(this)
            ) {
                return false;
            }
        }
        return true;
    }

    function listERC721Collection(NewCollection calldata collection) external {
        if (
            ERC721(collection.contractAddress).balanceOf(msg.sender) !=
            collection.collectionSize ||
            collection.collectionSize == 0
        ) {
            revert OdysseyMarket_CollectionSize();
        }
        CollectionListing storage listing = collectionListings[msg.sender][
            collection.contractAddress
        ];

        if (listing.paymentInfo.length > 0) {
            delete listing.paymentInfo;
        }
        uint256 i;
        uint256 paymentSize = collection.paymentInfo.length;
        for (; i < paymentSize; ++i) {
            listing.paymentInfo.push(collection.paymentInfo[i]);
        }

        if (listing.royalties.length > 0) {
            delete listing.royalties;
        }
        uint256 j;
        uint256 royaltySize = collection.royalties.length;
        for (; j < royaltySize; ++j) {
            listing.royalties.push(collection.royalties[j]);
        }
    }

    function listERC721(NewListing[] calldata listings) external {
        uint256 size = listings.length;
        uint256 i;
        for (; i < size; ++i) {
            address contractAddress = listings[i].contractAddress;
            uint256 tokenId = listings[i].tokenId;

            if (ERC721(contractAddress).ownerOf(tokenId) != msg.sender) {
                revert OdysseyMarket_NotOwner();
            }

            InternalListing storage internalListing = saleListings[msg.sender][
                contractAddress
            ][tokenId];
            internalListing.tokenAmount = 1;
            internalListing.isERC1155 = false;

            if (internalListing.paymentInfo.length > 0) {
                delete internalListing.paymentInfo;
            }

            for (uint256 j; j < listings[i].paymentInfo.length; ++j) {
                internalListing.paymentInfo.push(listings[i].paymentInfo[j]);
            }

            if (internalListing.royalties.length > 0) {
                delete internalListing.royalties;
            }

            uint256 royaltyCount;
            for (uint256 k; k < listings[i].royalties.length; ++k) {
                royaltyCount += listings[i].royalties[k].percent;
                internalListing.royalties.push(listings[i].royalties[k]);
            }
            if (royaltyCount != 100) {
                revert OdysseyMarket_BadRoyalties();
            }
        }
    }

    function checkGlobalAccessPass() internal view {
        if (globalAccessPass.contractAddress != address(0)) {
            // Access pass required
            if (globalAccessPass.isERC1155) {
                bool hasPass;
                uint256 n;
                for (; n < globalAccessPass.tokenIds.length; ++n) {
                    if (
                        ERC1155(globalAccessPass.contractAddress).balanceOf(
                            msg.sender,
                            globalAccessPass.tokenIds[n]
                        ) != 0
                    ) {
                        hasPass = true;
                        break;
                    }
                }
                if (!hasPass) {
                    revert OdysseyMarket_NoAccess();
                }
            } else if (
                ERC721(globalAccessPass.contractAddress).balanceOf(
                    msg.sender
                ) == 0
            ) {
                revert OdysseyMarket_NoAccess();
            }
        }
    }

    function buyERC721(BuyOrder[] calldata orders) external payable {
        checkGlobalAccessPass();
        uint256 size = orders.length;
        uint256 i;
        for (; i < size; ++i) {
            //(uint256 price, bytes32 hash, address owner) = verifyListing(listings[i]);
            if (
                !verifyListing(
                    0,
                    orders[i].tokenId,
                    orders[i].contractAddress,
                    orders[i].owner,
                    false
                )
            ) {
                revert OdysseyMarket_BuyError();
            }

            AccessPass storage access = accessPassMap[orders[i].owner][
                orders[i].contractAddress
            ];

            if (access.contractAddress != address(0)) {
                // Access pass required
                if (access.isERC1155) {
                    bool hasPass;
                    uint256 n;
                    for (; n < access.tokenIds.length; ++n) {
                        if (
                            ERC1155(access.contractAddress).balanceOf(
                                msg.sender,
                                access.tokenIds[n]
                            ) != 0
                        ) {
                            hasPass = true;
                            break;
                        }
                    }
                    if (!hasPass) {
                        revert OdysseyMarket_NoAccess();
                    }
                } else if (
                    ERC721(access.contractAddress).balanceOf(msg.sender) == 0
                ) {
                    revert OdysseyMarket_NoAccess();
                }
            }

            bool purchasedSingle = false;
            InternalListing storage listing = saleListings[orders[i].owner][
                orders[i].contractAddress
            ][orders[i].tokenId];
            for (uint256 j; j < listing.paymentInfo.length; ++j) {
                if (
                    listing.paymentInfo[j].currencyAddress ==
                    orders[i].currencyAddress &&
                    listing.paymentInfo[j].amount != 0
                ) {
                    OdysseyXp(xp).saleReward(
                        orders[i].owner,
                        orders[i].contractAddress,
                        orders[i].tokenId
                    );
                    OdysseyXp(xp).purchaseReward(
                        msg.sender,
                        orders[i].contractAddress,
                        orders[i].tokenId
                    );
                    _takePayment(
                        orders[i].contractAddress,
                        listing.paymentInfo[j].currencyAddress,
                        listing.paymentInfo[j].amount,
                        listing.royalties
                    );
                    ERC721(orders[i].contractAddress).transferFrom(
                        orders[i].owner,
                        msg.sender,
                        orders[i].tokenId
                    );
                    purchasedSingle = true;
                    delete saleListings[orders[i].owner][
                        orders[i].contractAddress
                    ][orders[i].tokenId];
                    break;
                }
            }

            if (!purchasedSingle) {
                CollectionListing
                    storage collectionListing = collectionListings[
                        orders[i].owner
                    ][orders[i].contractAddress];
                if (
                    collectionListing.paymentInfo.length != 0 &&
                    collectionListing.tokenIdSold[orders[i].tokenId] == 0
                ) {
                    for (
                        uint256 j;
                        j < collectionListing.paymentInfo.length;
                        ++j
                    ) {
                        if (
                            collectionListing.paymentInfo[j].currencyAddress ==
                            orders[i].currencyAddress &&
                            collectionListing.paymentInfo[j].amount != 0
                        ) {
                            OdysseyXp(xp).saleReward(
                                orders[i].owner,
                                orders[i].contractAddress,
                                orders[i].tokenId
                            );
                            OdysseyXp(xp).purchaseReward(
                                msg.sender,
                                orders[i].contractAddress,
                                orders[i].tokenId
                            );
                            _takePayment(
                                orders[i].contractAddress,
                                collectionListing
                                    .paymentInfo[j]
                                    .currencyAddress,
                                collectionListing.paymentInfo[j].amount,
                                collectionListing.royalties
                            );
                            ERC721(orders[i].contractAddress).transferFrom(
                                orders[i].owner,
                                msg.sender,
                                orders[i].tokenId
                            );
                            collectionListing.tokenIdSold[
                                orders[i].tokenId
                            ] = 1;
                            break;
                        }
                    }
                }
            }
        }
    }

    function listERC1155(NewListing[] calldata listings) external {
        uint256 size = listings.length;
        uint256 i;
        for (; i < size; ++i) {
            address contractAddress = listings[i].contractAddress;
            uint256 tokenId = listings[i].tokenId;
            uint256 tokenAmount = listings[i].tokenAmount;

            if (
                ERC1155(contractAddress).balanceOf(msg.sender, tokenId) <
                tokenAmount
            ) {
                revert OdysseyMarket_NotOwner();
            }

            InternalListing storage internalListing = saleListings[msg.sender][
                contractAddress
            ][tokenId];
            internalListing.tokenAmount = tokenAmount;
            internalListing.isERC1155 = true;

            if (internalListing.paymentInfo.length > 0) {
                delete internalListing.paymentInfo;
            }

            for (uint256 j; j < listings[i].paymentInfo.length; ++j) {
                internalListing.paymentInfo.push(listings[i].paymentInfo[j]);
            }

            if (internalListing.royalties.length > 0) {
                delete internalListing.royalties;
            }

            uint256 royaltyCount;
            for (uint256 k; k < listings[i].royalties.length; ++k) {
                royaltyCount += listings[i].royalties[k].percent;
                internalListing.royalties.push(listings[i].royalties[k]);
            }
            if (royaltyCount != 100) {
                revert OdysseyMarket_BadRoyalties();
            }
        }
    }

    function buyERC1155(BuyOrder[] calldata orders) external payable {
        checkGlobalAccessPass();
        uint256 size = orders.length;
        uint256 i;
        for (; i < size; ++i) {
            if (
                !verifyListing(
                    orders[i].tokenAmount,
                    orders[i].tokenId,
                    orders[i].contractAddress,
                    orders[i].owner,
                    true
                )
            ) {
                revert OdysseyMarket_BuyError();
            }

            AccessPass storage access = accessPassMap[orders[i].owner][
                orders[i].contractAddress
            ];
            if (access.contractAddress != address(0)) {
                // Access pass required
                if (access.isERC1155) {
                    bool hasPass;
                    uint256 n;
                    for (; n < access.tokenIds.length; ++n) {
                        if (
                            ERC1155(access.contractAddress).balanceOf(
                                msg.sender,
                                access.tokenIds[n]
                            ) != 0
                        ) {
                            hasPass = true;
                            break;
                        }
                    }
                    if (!hasPass) {
                        revert OdysseyMarket_NoAccess();
                    }
                } else if (
                    ERC721(access.contractAddress).balanceOf(msg.sender) == 0
                ) {
                    revert OdysseyMarket_NoAccess();
                }
            }

            InternalListing storage listing = saleListings[orders[i].owner][
                orders[i].contractAddress
            ][orders[i].tokenId];
            if (listing.tokenAmount < orders[i].tokenAmount) {
                revert OdysseyMarket_NotEnoughSupply();
            }
            for (uint256 j; j < listing.paymentInfo.length; ++j) {
                if (
                    listing.paymentInfo[j].currencyAddress ==
                    orders[i].currencyAddress &&
                    listing.paymentInfo[j].amount != 0
                ) {
                    OdysseyXp(xp).saleReward(
                        orders[i].owner,
                        orders[i].contractAddress,
                        orders[i].tokenId
                    );
                    OdysseyXp(xp).purchaseReward(
                        msg.sender,
                        orders[i].contractAddress,
                        orders[i].tokenId
                    );
                    _takePayment(
                        orders[i].contractAddress,
                        listing.paymentInfo[j].currencyAddress,
                        listing.paymentInfo[j].amount * orders[i].tokenAmount,
                        listing.royalties
                    );
                    ERC1155(orders[i].contractAddress).safeTransferFrom(
                        orders[i].owner,
                        msg.sender,
                        orders[i].tokenId,
                        orders[i].tokenAmount,
                        ""
                    );
                    if (listing.tokenAmount == orders[i].tokenAmount) {
                        delete saleListings[orders[i].owner][
                            orders[i].contractAddress
                        ][orders[i].tokenId];
                    } else {
                        listing.tokenAmount -= orders[i].tokenAmount;
                    }
                    break;
                }
            }
        }
    }

    function _takePayment(
        address contractAddress,
        address currency,
        uint256 amount,
        Royalties[] storage royalties
    ) internal {
        // Treasury Payment 3%
        uint256 commission = (amount * 3) / 100;
        amount = amount - commission;
        Royalties[] storage sRoyalties = secondaryRoyalties[contractAddress];

        if (currency == address(0)) {
            if (msg.value < amount) {
                revert OdysseyMarket_InsufficientFunds();
            }

            (bool success, ) = treasury.call{value: commission}("");
            if (!success) {
                revert OdysseyMarket_FailedToPayEther();
            }

            uint256 sAmount;
            for (uint256 n; n < sRoyalties.length; ++n) {
                sAmount = (amount * sRoyalties[n].percent) / 100;
                amount -= sAmount;
                (bool success, ) = sRoyalties[n].receiver.call{value: sAmount}(
                    ""
                );
                if (!success) {
                    revert OdysseyMarket_FailedToPayEther();
                }
            }

            // Sale Royalties
            for (uint256 i; i < royalties.length; ++i) {
                commission = (amount * royalties[i].percent) / 100;
                (success, ) = royalties[i].receiver.call{value: commission}("");
                if (!success) {
                    revert OdysseyMarket_FailedToPayEther();
                }
            }
        } else {
            bool result = ERC20(currency).transferFrom(
                msg.sender,
                treasury,
                commission
            );
            if (!result) {
                revert OdysseyMarket_FailedToPayERC20();
            }

            uint256 sAmount;
            for (uint256 n; n < sRoyalties.length; ++n) {
                sAmount = (amount * sRoyalties[n].percent) / 100;
                amount -= sAmount;
                result = ERC20(currency).transferFrom(
                    msg.sender,
                    sRoyalties[n].receiver,
                    sAmount
                );
                if (!result) {
                    revert OdysseyMarket_FailedToPayERC20();
                }
            }

            for (uint256 i; i < royalties.length; ++i) {
                commission = (amount * royalties[i].percent) / 100;
                result = ERC20(currency).transferFrom(
                    msg.sender,
                    royalties[i].receiver,
                    commission
                );
                if (!result) {
                    revert OdysseyMarket_FailedToPayERC20();
                }
            }
        }
    }
}
