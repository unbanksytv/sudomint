// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.12;

import {OdysseyLaunchPlatform} from "../OdysseyLaunchPlatform.sol";
import {OdysseyLib} from "../libraries/OdysseyLib.sol";

abstract contract OdysseyDatabase {
    // Custom Errors
    error OdysseyLaunchPlatform_TokenDoesNotExist();
    error OdysseyLaunchPlatform_AlreadyClaimed();
    error OdysseyLaunchPlatform_MaxSupplyCap();
    error OdysseyLaunchPlatform_InsufficientFunds();
    error OdysseyLaunchPlatform_TreasuryPayFailure();
    error OdysseyLaunchPlatform_FailedToPayEther();
    error OdysseyLaunchPlatform_FailedToPayERC20();
    error OdysseyLaunchPlatform_ReservedOrClaimedMax();

    // Constants
    // keccak256("whitelistMint721(bytes32 merkleRoot,uint256 minPrice,uint256 mintsPerUser,address tokenAddress,address currency)").toString('hex')
    bytes32 public constant MERKLE_TREE_ROOT_ERC721_TYPEHASH =
        0xf0f6f256599682b9387f45fc268ed696625f835d98d64b8967134239e103fc6c;
    // keccak256("whitelistMint1155(bytes32 merkleRoot,uint256 minPrice,uint256 mintsPerUser,uint256 tokenId,address tokenAddress,address currency)").toString('hex')
    bytes32 public constant MERKLE_TREE_ROOT_ERC1155_TYPEHASH =
        0x0a52f6e0133eadd055cc5703844e676242c3b461d85fb7ce7f74becd7e40edd1;

    // Def understand this before writing code:
    // https://docs.soliditylang.org/en/v0.8.12/internals/layout_in_storage.html
    //--------------------------------------------------------------------------------//
    // Slot       |  Type                  | Description                              //
    //--------------------------------------------------------------------------------//
    // 0x00       |  address               | OdysseyLaunchPlatform.sol                //
    // 0x01       |  address               | OdysseyFactory.sol                       //
    // 0x02       |  address               | Treasury Multisig                        //
    // 0x03       |  address               | Admin Address                            //
    // 0x04       |  address               | OdysseyXp.sol                            //
    //--------------------------------------------------------------------------------//
    // Slot storage
    address launchPlatform; // slot 0
    address factory; // slot 1
    address treasury; // slot 2
    address admin; //slot 3
    address xp; //slot 4

    // Common Storage
    mapping(address => bytes32) public domainSeparator;
    mapping(address => uint256) public whitelistActive;
    mapping(address => address) public ownerOf;
    mapping(address => address) public royaltyRecipient;
    mapping(address => OdysseyLib.Percentage) public treasuryCommission;
    mapping(address => uint256) public ohmFamilyCurrencies;
    // ERC721 Storage
    mapping(address => mapping(address => uint256)) public whitelistClaimed721;
    mapping(address => mapping(address => uint256)) public isReserved721;
    mapping(address => uint256) public cumulativeSupply721;
    mapping(address => uint256) public mintedSupply721;
    mapping(address => uint256) public maxSupply721;
    // ERC1155 Storage
    mapping(address => mapping(address => mapping(uint256 => uint256)))
        public whitelistClaimed1155;
    mapping(address => mapping(address => mapping(uint256 => uint256)))
        public isReserved1155;
    mapping(address => mapping(uint256 => uint256)) public cumulativeSupply1155;
    mapping(address => mapping(uint256 => uint256)) public maxSupply1155;

    function readSlotAsAddress(uint256 slot)
        public
        view
        returns (address data)
    {
        assembly {
            data := sload(slot)
        }
    }
}
