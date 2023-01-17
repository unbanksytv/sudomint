// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {Vm} from "forge-std/Vm.sol";
import {OdysseyXpDirectory} from "../OdysseyXpDirectory.sol";
import {OdysseyXp} from "../OdysseyXp.sol";
import {OdysseyRouter} from "../OdysseyRouter.sol";
import {OdysseyLaunchPlatform} from "../OdysseyLaunchPlatform.sol";
import {OdysseyTokenFactory} from "../factory/OdysseyTokenFactory.sol";
import {ERC721} from "@solmate/tokens/ERC721.sol";
import {ERC1155} from "@solmate/tokens/ERC1155.sol";
import {gOHM} from "@odyssey/tokens/gOHM-Mock.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import {OdysseyLib} from "@odyssey/libraries/OdysseyLib.sol";
import {console} from "./utils/Console.sol";

contract RouterTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    Utilities internal utils;
    address payable[] internal users;
    OdysseyRouter router;
    OdysseyTokenFactory factory;
    address payable alice;
    address payable bob;
    string name;
    string symbol;
    address currency;
    gOHM paymentToken;
    OdysseyXpDirectory directory;
    OdysseyXp xp;
    bytes32[] merkleProof;
    bytes32 merkleRoot;
    uint256[] maxSupplyArray = [100, 50, 100, 200];
    uint256[] updatedMaxSupply = [2, 4, 8, 90];
    uint256[] tokenIdArray = [1, 2, 3, 4];
    uint256[] reserveAmounts = [1, 2, 4, 69];
    uint256 mintsPerUser;
    uint256 key;
    uint256 keyTreasury;
    address signer;
    address treasury;
    address royaltyReceiver;
    OdysseyLib.Percentage commission;
    // bulk mint vars
    bytes32[][] proofs;
    bytes32[] roots;
    uint256[] prices;
    uint256[] mintMax;
    uint256[] ids;
    address[] addresses;
    address[] currencies;
    uint8[] vs;
    bytes32[] rs;
    bytes32[] ss;
    // keccak256("whitelistMint721(bytes32 merkleRoot,uint256 minPrice,uint256 mintsPerUser,address tokenAddress,address currency)").toString('hex')
    bytes32 public constant MERKLE_TREE_ROOT_ERC721_TYPEHASH =
        0xf0f6f256599682b9387f45fc268ed696625f835d98d64b8967134239e103fc6c;
    // keccak256("mint721(bytes32 merkleRoot,uint256 minPrice,uint256 mintsPerUser,address tokenAddress,address currency)").toString('hex')
    bytes32 public constant MIN_PRICE_ERC721_TYPEHASH =
        0xac838027194bb38e07040d9c8c0e4eb9c33f7b760687b584bb6f9566a8c9847b;
    // keccak256("whitelistMint1155(bytes32 merkleRoot,uint256 minPrice,uint256 mintsPerUser,uint256 tokenId,address tokenAddress,address currency)").toString('hex')
    bytes32 public constant MERKLE_TREE_ROOT_ERC1155_TYPEHASH =
        0x0a52f6e0133eadd055cc5703844e676242c3b461d85fb7ce7f74becd7e40edd1;
    // keccak256("mint1155(bytes32 merkleRoot,uint256 minPrice,uint256 mintsPerUser,uint256 tokenId,address tokenAddress,address currency)").toString('hex')
    bytes32 public constant MIN_PRICE_ERC1155_TYPEHASH =
        0x7c96866ce4a4fc960a9de401ed2e7687cbb3c1deabab2783dde78d5a3aa4c20c;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);
        alice = users[0];
        bob = users[1];
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        keyTreasury = 42069;
        treasury = vm.addr(keyTreasury);
        paymentToken = new gOHM(bob);
        currency = address(paymentToken);
        address[] memory ohmFamily = new address[](1);
        ohmFamily[0] = currency;
        router = new OdysseyRouter(treasury, address(0), address(0), ohmFamily);
        factory = router.Factory();
        xp = OdysseyXp(router.readSlotAsAddress(4));
        name = "ACoolToken";
        symbol = "TOKE";
        key = 69420;
        signer = vm.addr(key);

        vm.prank(bob);
        paymentToken.approve(address(router), 100);

        commission = OdysseyLib.Percentage(3, 100); // 3% base
        royaltyReceiver = signer;
        mintsPerUser = 1;
    }

    function testRouterMembers() public view {
        assert(address(router) != address(0));
        require(address(factory) != address(0));
    }

    function testOwnerMint721() public {
        address token = createToken(signer, true, 721);
        vm.prank(signer);
        router.ownerMint721(token, bob);
        assertEq(ERC721(token).balanceOf(bob), 1, "Bad balance");
    }

    function testBadOwnerMint721() public {
        address token = createToken(signer, true, 721);
        vm.prank(bob);
        bytes memory customError = abi.encodeWithSignature(
            "OdysseyRouter_Unauthorized()"
        );
        vm.expectRevert(customError);
        router.ownerMint721(token, bob);
        assertEq(ERC721(token).balanceOf(bob), 0, "Bad balance");
    }

    function testSetOwner721() public {
        address token = createToken(signer, true, 721);
        vm.startPrank(signer);
        router.ownerMint721(token, bob);
        assertEq(ERC721(token).balanceOf(bob), 1, "Bad balance");
        router.setOwnerShip(token, bob);
        vm.stopPrank();
        vm.prank(bob);
        router.ownerMint721(token, bob);
        assertEq(ERC721(token).balanceOf(bob), 2, "Bad balance");
        bytes memory customError = abi.encodeWithSignature(
            "OdysseyRouter_Unauthorized()"
        );
        vm.expectRevert(customError);
        vm.prank(signer);
        router.setOwnerShip(token, bob);
    }

    function testOwnerMint1155() public {
        address token = createToken(signer, true, 1155);
        vm.prank(signer);
        router.ownerMint1155(1, 69, token, bob);
        assertEq(ERC1155(token).balanceOf(bob, 1), 69, "Bad balance");
    }

    function testBadOwnerMint1155() public {
        address token = createToken(signer, true, 1155);
        vm.prank(bob);
        bytes memory customError = abi.encodeWithSignature(
            "OdysseyRouter_Unauthorized()"
        );
        vm.expectRevert(customError);
        router.ownerMint1155(1, 69, token, bob);
        assertEq(ERC1155(token).balanceOf(bob, 1), 0, "Bad balance");
    }

    function testSetOwner1155() public {
        address token = createToken(signer, true, 1155);
        vm.prank(signer);
        router.setOwnerShip(token, bob);
        vm.prank(bob);
        router.ownerMint1155(1, 69, token, bob);
        assertEq(ERC1155(token).balanceOf(bob, 1), 69, "Bad balance");
    }

    function testMint721() public {
        address token = createToken(signer, false, 721);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            721,
            currency
        );
        vm.prank(bob);
        router.mintERC721(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.whitelistClaimed721(token, bob), 1);
        assertEq(ERC721(token).balanceOf(bob), 1);
        assertEq(router.cumulativeSupply721(token), 2);
        assertEq(router.mintedSupply721(token), 2);
        assertEq(paymentToken.balanceOf(signer), 97);
        assertEq(paymentToken.balanceOf(treasury), 3);
        assertEq(xp.balanceOf(bob), 3);
    }

    function testMint721ETHPay() public {
        address token = createToken(signer, false, 721, 420);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            721,
            address(0)
        );
        vm.prank(bob);
        router.mintERC721{value: 100}(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            token,
            address(0), // currency address
            v,
            r,
            s
        );
        assertEq(router.whitelistClaimed721(token, bob), 1);
        assertEq(ERC721(token).balanceOf(bob), 1);
        assertEq(router.cumulativeSupply721(token), 2);
        assertEq(router.mintedSupply721(token), 2);
        assertEq(signer.balance, 97);
        assertEq(treasury.balance, 3);
        assertEq(xp.balanceOf(bob), 0);
    }

    function testMint721HigherComission() public {
        commission = OdysseyLib.Percentage(1, 3);
        address token = createToken(signer, false, 721);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            721,
            currency
        );
        vm.prank(bob);
        router.mintERC721(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.whitelistClaimed721(token, bob), 1);
        assertEq(ERC721(token).balanceOf(bob), 1);
        assertEq(router.cumulativeSupply721(token), 2);
        assertEq(router.mintedSupply721(token), 2);
        assertEq(paymentToken.balanceOf(signer), 67);
        assertEq(paymentToken.balanceOf(treasury), 33);
        assertEq(xp.balanceOf(bob), 3);
    }

    function testMint721LowComission() public {
        commission = OdysseyLib.Percentage(1, 100);
        address token = createToken(signer, false, 721);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            721,
            currency
        );
        vm.prank(bob);
        router.mintERC721(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.whitelistClaimed721(token, bob), 1);
        assertEq(ERC721(token).balanceOf(bob), 1);
        assertEq(router.cumulativeSupply721(token), 2);
        assertEq(router.mintedSupply721(token), 2);
        assertEq(paymentToken.balanceOf(signer), 97);
        assertEq(paymentToken.balanceOf(treasury), 3);
        assertEq(xp.balanceOf(bob), 3);
    }

    function testMint721NewTreasury() public {
        uint256 newkey = 69696969;
        address newTreasury = vm.addr(newkey);
        router.setTreasury(newTreasury);
        address token = createToken(signer, false, 721);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            721,
            currency
        );
        vm.prank(bob);
        router.mintERC721(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.whitelistClaimed721(token, bob), 1);
        assertEq(ERC721(token).balanceOf(bob), 1);
        assertEq(router.cumulativeSupply721(token), 2);
        assertEq(router.mintedSupply721(token), 2);
        assertEq(paymentToken.balanceOf(signer), 97);
        assertEq(paymentToken.balanceOf(newTreasury), 3);
        assertEq(paymentToken.balanceOf(treasury), 0);
        assertEq(xp.balanceOf(bob), 3);
    }

    function testMint721NewAdmin() public {
        uint256 newkey = 69696969;
        address newTreasury = vm.addr(newkey);
        uint256 newkey2 = 420420;
        address newAdmin = vm.addr(newkey2);
        router.setAdmin(newAdmin);
        vm.prank(newAdmin);
        router.setTreasury(newTreasury);
        address token = createToken(signer, false, 721);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            721,
            currency
        );
        vm.prank(bob);
        router.mintERC721(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.whitelistClaimed721(token, bob), 1);
        assertEq(ERC721(token).balanceOf(bob), 1);
        assertEq(router.cumulativeSupply721(token), 2);
        assertEq(router.mintedSupply721(token), 2);
        assertEq(paymentToken.balanceOf(signer), 97);
        assertEq(paymentToken.balanceOf(newTreasury), 3);
        assertEq(paymentToken.balanceOf(treasury), 0);
    }

    function testMint721NewRoyaltyRecipient() public {
        royaltyReceiver = alice;
        address token = createToken(signer, false, 721);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            721,
            currency
        );
        vm.prank(bob);
        router.mintERC721(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.whitelistClaimed721(token, bob), 1);
        assertEq(ERC721(token).balanceOf(bob), 1);
        assertEq(router.cumulativeSupply721(token), 2);
        assertEq(router.mintedSupply721(token), 2);
        assertEq(paymentToken.balanceOf(alice), 97);
        assertEq(paymentToken.balanceOf(signer), 0);
        assertEq(paymentToken.balanceOf(treasury), 3);
        assertEq(xp.balanceOf(bob), 3);
    }

    function testMint721OutOfBoundesComission() public {
        commission = OdysseyLib.Percentage(3, 2);
        address token = createToken(signer, false, 721);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            721,
            currency
        );
        vm.prank(bob);
        router.mintERC721(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.whitelistClaimed721(token, bob), 1);
        assertEq(ERC721(token).balanceOf(bob), 1);
        assertEq(router.cumulativeSupply721(token), 2);
        assertEq(router.mintedSupply721(token), 2);
        assertEq(paymentToken.balanceOf(signer), 97);
        assertEq(paymentToken.balanceOf(treasury), 3);
        assertEq(xp.balanceOf(bob), 3);
    }

    function testMint721MaxSupplyAsZero() public {
        address token = create721Token(alice, false, 0);
        assertEq(router.maxSupply721(token), type(uint256).max);
    }

    function testReserve721() public {
        address token = createToken(signer, false, 721);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            721,
            currency
        );
        vm.prank(bob);
        router.reserveERC721(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.isReserved721(token, bob), 1);
        assertEq(router.whitelistClaimed721(token, bob), 0);
        assertEq(ERC721(token).balanceOf(bob), 0);
        assertEq(router.cumulativeSupply721(token), 1 + reserveAmounts[0]);
        assertEq(router.mintedSupply721(token), reserveAmounts[0]);
        assertEq(paymentToken.balanceOf(signer), 97);
        assertEq(paymentToken.balanceOf(treasury), 3);
        assertEq(xp.balanceOf(bob), 3);

        vm.prank(bob);
        router.mintERC721(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            token,
            currency,
            0,
            0,
            0
        );
        assertEq(router.whitelistClaimed721(token, bob), 1);
        assertEq(ERC721(token).balanceOf(bob), 1);
        assertEq(router.cumulativeSupply721(token), 1 + reserveAmounts[0]);
        assertEq(router.mintedSupply721(token), 1 + reserveAmounts[0]);
        assertEq(xp.balanceOf(bob), 3);
    }

    function testReserve721NewRoyaltyRecipient() public {
        royaltyReceiver = alice;
        address token = createToken(signer, false, 721);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            721,
            currency
        );
        vm.prank(bob);
        router.reserveERC721(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.isReserved721(token, bob), 1);
        assertEq(router.whitelistClaimed721(token, bob), 0);
        assertEq(ERC721(token).balanceOf(bob), 0);
        assertEq(router.cumulativeSupply721(token), 1 + reserveAmounts[0]);
        assertEq(router.mintedSupply721(token), reserveAmounts[0]);
        assertEq(paymentToken.balanceOf(alice), 97);
        assertEq(paymentToken.balanceOf(signer), 0);
        assertEq(paymentToken.balanceOf(treasury), 3);
        assertEq(xp.balanceOf(bob), 3);

        vm.prank(bob);
        router.mintERC721(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            token,
            currency,
            0,
            0,
            0
        );
        assertEq(router.whitelistClaimed721(token, bob), 1);
        assertEq(ERC721(token).balanceOf(bob), 1);
        assertEq(router.cumulativeSupply721(token), 1 + reserveAmounts[0]);
        assertEq(router.mintedSupply721(token), 1 + reserveAmounts[0]);
        assertEq(xp.balanceOf(bob), 3);
    }

    function testReserve721HigherCommission() public {
        commission = OdysseyLib.Percentage(1, 3);
        address token = createToken(signer, false, 721);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            721,
            currency
        );
        vm.prank(bob);
        router.reserveERC721(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.isReserved721(token, bob), 1);
        assertEq(router.whitelistClaimed721(token, bob), 0);
        assertEq(ERC721(token).balanceOf(bob), 0);
        assertEq(router.cumulativeSupply721(token), 1 + reserveAmounts[0]);
        assertEq(router.mintedSupply721(token), reserveAmounts[0]);
        assertEq(paymentToken.balanceOf(signer), 67);
        assertEq(paymentToken.balanceOf(treasury), 33);
        assertEq(xp.balanceOf(bob), 3);

        vm.prank(bob);
        router.mintERC721(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            token,
            currency,
            0,
            0,
            0
        );
        assertEq(router.whitelistClaimed721(token, bob), 1);
        assertEq(ERC721(token).balanceOf(bob), 1);
        assertEq(router.cumulativeSupply721(token), 1 + reserveAmounts[0]);
        assertEq(router.mintedSupply721(token), 1 + reserveAmounts[0]);
        assertEq(xp.balanceOf(bob), 3);
    }

    function testReserve721LowerCommission() public {
        commission = OdysseyLib.Percentage(0, 3);
        address token = createToken(signer, false, 721);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            721,
            currency
        );
        vm.prank(bob);
        router.reserveERC721(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.isReserved721(token, bob), 1);
        assertEq(router.whitelistClaimed721(token, bob), 0);
        assertEq(ERC721(token).balanceOf(bob), 0);
        assertEq(router.cumulativeSupply721(token), 1 + reserveAmounts[0]);
        assertEq(router.mintedSupply721(token), reserveAmounts[0]);
        assertEq(paymentToken.balanceOf(signer), 97);
        assertEq(paymentToken.balanceOf(treasury), 3);
        assertEq(xp.balanceOf(bob), 3);

        vm.prank(bob);
        router.mintERC721(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            token,
            currency,
            0,
            0,
            0
        );
        assertEq(router.whitelistClaimed721(token, bob), 1);
        assertEq(ERC721(token).balanceOf(bob), 1);
        assertEq(router.cumulativeSupply721(token), 1 + reserveAmounts[0]);
        assertEq(router.mintedSupply721(token), 1 + reserveAmounts[0]);
        assertEq(xp.balanceOf(bob), 3);
    }

    function testReserve721ETHPay() public {
        address token = createToken(signer, false, 721, 420);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            721,
            address(0)
        );
        vm.prank(bob);
        router.reserveERC721{value: 100}(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            token,
            address(0),
            v,
            r,
            s
        );
        assertEq(router.isReserved721(token, bob), 1);
        assertEq(router.whitelistClaimed721(token, bob), 0);
        assertEq(ERC721(token).balanceOf(bob), 0);
        assertEq(router.cumulativeSupply721(token), 1 + reserveAmounts[0]);
        assertEq(router.mintedSupply721(token), reserveAmounts[0]);
        assertEq(signer.balance, 97);
        assertEq(treasury.balance, 3);
        assertEq(xp.balanceOf(bob), 0);

        vm.prank(bob);
        router.mintERC721(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            token,
            address(0),
            0,
            0,
            0
        );
        assertEq(router.whitelistClaimed721(token, bob), 1);
        assertEq(ERC721(token).balanceOf(bob), 1);
        assertEq(router.cumulativeSupply721(token), 1 + reserveAmounts[0]);
        assertEq(router.mintedSupply721(token), 1 + reserveAmounts[0]);
        assertEq(xp.balanceOf(bob), 0);
    }

    function testMint1155() public {
        address token = createToken(signer, false, 1155);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            1155,
            currency
        );
        vm.prank(bob);
        router.mintERC1155(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            1,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.whitelistClaimed1155(token, bob, 1), 1, "not claimed");
        assertEq(ERC1155(token).balanceOf(bob, 1), 1, "bad balance");
        assertEq(
            router.cumulativeSupply1155(token, 1),
            1 + reserveAmounts[0],
            "bad supply"
        );
        assertEq(paymentToken.balanceOf(signer), 97, "Payment is wrong");
        assertEq(paymentToken.balanceOf(treasury), 3, "Payment is wrong");
        assertEq(xp.balanceOf(bob), 3);
    }

    function testMint1155NewRoyaltyRecipient() public {
        royaltyReceiver = alice;
        address token = createToken(signer, false, 1155);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            1155,
            currency
        );
        vm.prank(bob);
        router.mintERC1155(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            1,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.whitelistClaimed1155(token, bob, 1), 1, "not claimed");
        assertEq(ERC1155(token).balanceOf(bob, 1), 1, "bad balance");
        assertEq(
            router.cumulativeSupply1155(token, 1),
            1 + reserveAmounts[0],
            "bad supply"
        );
        assertEq(paymentToken.balanceOf(alice), 97, "Payment is wrong");
        assertEq(paymentToken.balanceOf(signer), 0, "Payment is wrong");
        assertEq(paymentToken.balanceOf(treasury), 3, "Payment is wrong");
        assertEq(xp.balanceOf(bob), 3);
    }

    function testMint1155HigherCommission() public {
        commission = OdysseyLib.Percentage(1, 3);
        address token = createToken(signer, false, 1155);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            1155,
            currency
        );
        vm.prank(bob);
        router.mintERC1155(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            1,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.whitelistClaimed1155(token, bob, 1), 1, "not claimed");
        assertEq(ERC1155(token).balanceOf(bob, 1), 1, "bad balance");
        assertEq(
            router.cumulativeSupply1155(token, 1),
            1 + reserveAmounts[0],
            "bad supply"
        );
        assertEq(paymentToken.balanceOf(signer), 67, "Payment is wrong");
        assertEq(paymentToken.balanceOf(treasury), 33, "Payment is wrong");
        assertEq(xp.balanceOf(bob), 3);
    }

    function testMint1155LowerCommission() public {
        commission = OdysseyLib.Percentage(0, 0);
        address token = createToken(signer, false, 1155);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            1155,
            currency
        );
        vm.prank(bob);
        router.mintERC1155(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            1,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.whitelistClaimed1155(token, bob, 1), 1, "not claimed");
        assertEq(ERC1155(token).balanceOf(bob, 1), 1, "bad balance");
        assertEq(
            router.cumulativeSupply1155(token, 1),
            1 + reserveAmounts[0],
            "bad supply"
        );
        assertEq(paymentToken.balanceOf(signer), 97, "Payment is wrong");
        assertEq(paymentToken.balanceOf(treasury), 3, "Payment is wrong");
        assertEq(xp.balanceOf(bob), 3);
    }

    function testMint1155ETHPay() public {
        address token = createToken(signer, false, 1155, 420);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            1155,
            address(0)
        );
        vm.prank(bob);
        router.mintERC1155{value: 100}(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            1,
            token,
            address(0),
            v,
            r,
            s
        );
        assertEq(router.whitelistClaimed1155(token, bob, 1), 1, "not claimed");
        assertEq(ERC1155(token).balanceOf(bob, 1), 1, "bad balance");
        assertEq(
            router.cumulativeSupply1155(token, 1),
            1 + reserveAmounts[0],
            "bad supply"
        );
        assertEq(signer.balance, 97, "Payment is wrong");
        assertEq(treasury.balance, 3, "Payment is wrong");
        assertEq(xp.balanceOf(bob), 0);
    }

    function testReserve1155() public {
        address token = createToken(signer, false, 1155);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            1155,
            currency
        );
        vm.prank(bob);
        router.reserveERC1155(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            1,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.isReserved1155(token, bob, 1), 1);
        assertEq(router.whitelistClaimed1155(token, bob, 1), 0, "not claimed");
        assertEq(ERC1155(token).balanceOf(bob, 1), 0, "bad balance");
        assertEq(
            router.cumulativeSupply1155(token, 1),
            1 + reserveAmounts[0],
            "bad supply"
        );
        assertEq(paymentToken.balanceOf(signer), 97);
        assertEq(paymentToken.balanceOf(treasury), 3);
        assertEq(xp.balanceOf(bob), 3);

        vm.prank(bob);
        router.mintERC1155(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            1,
            token,
            currency,
            0,
            0,
            0
        );
        assertEq(router.whitelistClaimed1155(token, bob, 1), 1, "not claimed");
        assertEq(ERC1155(token).balanceOf(bob, 1), 1, "bad balance");
        assertEq(
            router.cumulativeSupply1155(token, 1),
            1 + reserveAmounts[0],
            "bad supply"
        );
        assertEq(xp.balanceOf(bob), 3);
    }

    function testReserve1155NewRoyaltyRecipient() public {
        royaltyReceiver = alice;
        address token = createToken(signer, false, 1155);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            1155,
            currency
        );
        vm.prank(bob);
        router.reserveERC1155(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            1,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.isReserved1155(token, bob, 1), 1);
        assertEq(router.whitelistClaimed1155(token, bob, 1), 0, "not claimed");
        assertEq(ERC1155(token).balanceOf(bob, 1), 0, "bad balance");
        assertEq(
            router.cumulativeSupply1155(token, 1),
            1 + reserveAmounts[0],
            "bad supply"
        );
        assertEq(paymentToken.balanceOf(alice), 97);
        assertEq(paymentToken.balanceOf(signer), 0);
        assertEq(paymentToken.balanceOf(treasury), 3);
        assertEq(xp.balanceOf(bob), 3);

        vm.prank(bob);
        router.mintERC1155(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            1,
            token,
            currency,
            0,
            0,
            0
        );
        assertEq(router.whitelistClaimed1155(token, bob, 1), 1, "not claimed");
        assertEq(ERC1155(token).balanceOf(bob, 1), 1, "bad balance");
        assertEq(
            router.cumulativeSupply1155(token, 1),
            1 + reserveAmounts[0],
            "bad supply"
        );
        assertEq(xp.balanceOf(bob), 3);
    }

    function testReserve1155HighCommission() public {
        commission = OdysseyLib.Percentage(1, 3);
        address token = createToken(signer, false, 1155);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            1155,
            currency
        );
        vm.prank(bob);
        router.reserveERC1155(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            1,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.isReserved1155(token, bob, 1), 1);
        assertEq(router.whitelistClaimed1155(token, bob, 1), 0, "not claimed");
        assertEq(ERC1155(token).balanceOf(bob, 1), 0, "bad balance");
        assertEq(
            router.cumulativeSupply1155(token, 1),
            1 + reserveAmounts[0],
            "bad supply"
        );
        assertEq(paymentToken.balanceOf(signer), 67);
        assertEq(paymentToken.balanceOf(treasury), 33);
        assertEq(xp.balanceOf(bob), 3);

        vm.prank(bob);
        router.mintERC1155(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            1,
            token,
            currency,
            0,
            0,
            0
        );
        assertEq(router.whitelistClaimed1155(token, bob, 1), 1, "not claimed");
        assertEq(ERC1155(token).balanceOf(bob, 1), 1, "bad balance");
        assertEq(
            router.cumulativeSupply1155(token, 1),
            1 + reserveAmounts[0],
            "bad supply"
        );
        assertEq(xp.balanceOf(bob), 3);
    }

    function testReserve1155LowCommission() public {
        commission = OdysseyLib.Percentage(1, 0);
        address token = createToken(signer, false, 1155);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            1155,
            currency
        );
        vm.prank(bob);
        router.reserveERC1155(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            1,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.isReserved1155(token, bob, 1), 1);
        assertEq(router.whitelistClaimed1155(token, bob, 1), 0, "not claimed");
        assertEq(ERC1155(token).balanceOf(bob, 1), 0, "bad balance");
        assertEq(
            router.cumulativeSupply1155(token, 1),
            1 + reserveAmounts[0],
            "bad supply"
        );
        assertEq(paymentToken.balanceOf(signer), 97);
        assertEq(paymentToken.balanceOf(treasury), 3);
        assertEq(xp.balanceOf(bob), 3);

        vm.prank(bob);
        router.mintERC1155(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            1,
            token,
            currency,
            0,
            0,
            0
        );
        assertEq(router.whitelistClaimed1155(token, bob, 1), 1, "not claimed");
        assertEq(ERC1155(token).balanceOf(bob, 1), 1, "bad balance");
        assertEq(
            router.cumulativeSupply1155(token, 1),
            1 + reserveAmounts[0],
            "bad supply"
        );
        assertEq(xp.balanceOf(bob), 3);
    }

    function testReserve1155ETHPay() public {
        address token = createToken(signer, false, 1155, 100);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            1155,
            address(0)
        );
        vm.prank(bob);
        router.reserveERC1155{value: 100}(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            1,
            token,
            address(0),
            v,
            r,
            s
        );
        assertEq(router.isReserved1155(token, bob, 1), 1);
        assertEq(router.whitelistClaimed1155(token, bob, 1), 0, "not claimed");
        assertEq(ERC1155(token).balanceOf(bob, 1), 0, "bad balance");
        assertEq(
            router.cumulativeSupply1155(token, 1),
            1 + reserveAmounts[0],
            "bad supply"
        );
        assertEq(signer.balance, 97);
        assertEq(treasury.balance, 3);
        assertEq(xp.balanceOf(bob), 0);

        vm.prank(bob);
        router.mintERC1155(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            1,
            token,
            currency,
            0,
            0,
            0
        );
        assertEq(router.whitelistClaimed1155(token, bob, 1), 1, "not claimed");
        assertEq(ERC1155(token).balanceOf(bob, 1), 1, "bad balance");
        assertEq(
            router.cumulativeSupply1155(token, 1),
            1 + reserveAmounts[0],
            "bad supply"
        );
        assertEq(xp.balanceOf(bob), 0);
    }

    function testMint721Authenticated() public {
        (bytes32 root, bytes32[] memory proof) = getProofAndRoot();
        address token = createToken(signer, true, 721);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            root,
            key,
            721,
            currency
        );

        vm.prank(bob);
        router.mintERC721(
            proof,
            root,
            100,
            mintsPerUser,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.whitelistClaimed721(token, bob), 1);
        assertEq(ERC721(token).balanceOf(bob), 1);
        assertEq(router.cumulativeSupply721(token), 1 + reserveAmounts[0]);
        assertEq(paymentToken.balanceOf(signer), 97);
        assertEq(paymentToken.balanceOf(treasury), 3);
        assertEq(xp.balanceOf(bob), 3);
    }

    function testBulkMint721Authenticated() public {
        mintsPerUser = 10;
        (bytes32 root, bytes32[] memory proof) = getProofAndRoot();
        address token = createToken(signer, true, 721);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            root,
            key,
            721,
            currency
        );

        for (uint256 i = 0; i < 10; i++) {
            proofs.push(proof);
            roots.push(root);
            prices.push(100);
            mintMax.push(10);
            ids.push(0);
            addresses.push(token);
            currencies.push(currency);
            vs.push(v);
            rs.push(r);
            ss.push(s);
        }
        vm.prank(bob);
        paymentToken.approve(address(router), 1000);
        OdysseyLib.BatchMint memory bulk = OdysseyLib.BatchMint(
            proofs,
            roots,
            prices,
            mintMax,
            ids,
            addresses,
            currencies,
            vs,
            rs,
            ss
        );
        vm.prank(bob);
        router.batchMintERC721(bulk);
        assertEq(router.whitelistClaimed721(token, bob), 10);
        assertEq(ERC721(token).balanceOf(bob), 10);
        assertEq(router.cumulativeSupply721(token), 10 + reserveAmounts[0]);
        assertEq(paymentToken.balanceOf(signer), 970);
        assertEq(paymentToken.balanceOf(treasury), 30);
        assertEq(xp.balanceOf(bob), 30);
    }

    function testMint721AuthenticatedETHPay() public {
        (bytes32 root, bytes32[] memory proof) = getProofAndRoot();
        address token = createToken(signer, true, 721, 69);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            root,
            key,
            721,
            address(0)
        );

        vm.prank(bob);
        router.mintERC721{value: 100}(
            proof,
            root,
            100,
            mintsPerUser,
            token,
            address(0),
            v,
            r,
            s
        );
        assertEq(router.whitelistClaimed721(token, bob), 1);
        assertEq(ERC721(token).balanceOf(bob), 1);
        assertEq(router.cumulativeSupply721(token), 1 + reserveAmounts[0]);
        assertEq(signer.balance, 97);
        assertEq(treasury.balance, 3);
        assertEq(xp.balanceOf(bob), 0);
    }

    function testReserve721Authenticated() public {
        (bytes32 root, bytes32[] memory proof) = getProofAndRoot();
        address token = createToken(signer, true, 721);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            root,
            key,
            721,
            currency
        );

        vm.prank(bob);
        router.reserveERC721(
            proof,
            root,
            100,
            mintsPerUser,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.isReserved721(token, bob), 1);
        assertEq(router.whitelistClaimed721(token, bob), 0);
        assertEq(ERC721(token).balanceOf(bob), 0);
        assertEq(router.cumulativeSupply721(token), 1 + reserveAmounts[0]);
        assertEq(router.mintedSupply721(token), 0 + reserveAmounts[0]);
        assertEq(paymentToken.balanceOf(signer), 97);
        assertEq(paymentToken.balanceOf(treasury), 3);
        assertEq(xp.balanceOf(bob), 3);

        vm.prank(bob);
        router.mintERC721(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            token,
            currency,
            0,
            0,
            0
        );
        assertEq(router.whitelistClaimed721(token, bob), 1);
        assertEq(ERC721(token).balanceOf(bob), 1);
        assertEq(router.cumulativeSupply721(token), 1 + reserveAmounts[0]);
        assertEq(router.mintedSupply721(token), 1 + reserveAmounts[0]);
        assertEq(xp.balanceOf(bob), 3);
    }

    function testBulkReserve721Authenticated() public {
        mintsPerUser = 10;
        (bytes32 root, bytes32[] memory proof) = getProofAndRoot();
        address token = createToken(signer, true, 721);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            root,
            key,
            721,
            currency
        );

        for (uint256 i = 0; i < 10; i++) {
            proofs.push(proof);
            roots.push(root);
            prices.push(100);
            mintMax.push(10);
            ids.push(0);
            addresses.push(token);
            currencies.push(currency);
            vs.push(v);
            rs.push(r);
            ss.push(s);
        }
        vm.prank(bob);
        paymentToken.approve(address(router), 1000);
        OdysseyLib.BatchMint memory bulk = OdysseyLib.BatchMint(
            proofs,
            roots,
            prices,
            mintMax,
            ids,
            addresses,
            currencies,
            vs,
            rs,
            ss
        );
        vm.prank(bob);
        router.batchReserveERC721(bulk);
        assertEq(router.whitelistClaimed721(token, bob), 0);
        assertEq(ERC721(token).balanceOf(bob), 0);
        assertEq(router.cumulativeSupply721(token), 10 + reserveAmounts[0]);
        assertEq(paymentToken.balanceOf(signer), 970);
        assertEq(paymentToken.balanceOf(treasury), 30);
        assertEq(xp.balanceOf(bob), 30);
    }

    function testReserve721AuthenticatedETHPay() public {
        (bytes32 root, bytes32[] memory proof) = getProofAndRoot();
        address token = createToken(signer, true, 721, 69);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            root,
            key,
            721,
            address(0)
        );

        vm.prank(bob);
        router.reserveERC721{value: 100}(
            proof,
            root,
            100,
            mintsPerUser,
            token,
            address(0),
            v,
            r,
            s
        );
        assertEq(router.isReserved721(token, bob), 1);
        assertEq(router.whitelistClaimed721(token, bob), 0);
        assertEq(ERC721(token).balanceOf(bob), 0);
        assertEq(router.cumulativeSupply721(token), 1 + reserveAmounts[0]);
        assertEq(router.mintedSupply721(token), 0 + reserveAmounts[0]);
        assertEq(signer.balance, 97);
        assertEq(treasury.balance, 3);
        assertEq(xp.balanceOf(bob), 0);

        vm.prank(bob);
        router.mintERC721(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            token,
            address(0),
            0,
            0,
            0
        );
        assertEq(router.whitelistClaimed721(token, bob), 1);
        assertEq(ERC721(token).balanceOf(bob), 1);
        assertEq(router.cumulativeSupply721(token), 1 + reserveAmounts[0]);
        assertEq(router.mintedSupply721(token), 1 + reserveAmounts[0]);
        assertEq(xp.balanceOf(bob), 0);
    }

    function testMint1155Authenticated() public {
        (bytes32 root, bytes32[] memory proof) = getProofAndRoot();
        address token = createToken(signer, true, 1155);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            root,
            key,
            1155,
            currency
        );

        vm.prank(bob);
        router.mintERC1155(
            proof,
            root,
            100,
            mintsPerUser,
            1,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.whitelistClaimed1155(token, bob, 1), 1, "not claimed");
        assertEq(ERC1155(token).balanceOf(bob, 1), 1, "bad balance");
        assertEq(
            router.cumulativeSupply1155(token, 1),
            1 + reserveAmounts[0],
            "bad supply"
        );
        assertEq(paymentToken.balanceOf(signer), 97);
        assertEq(paymentToken.balanceOf(treasury), 3);
        assertEq(xp.balanceOf(bob), 3);
    }

    function testBulkMint1155Authenticated() public {
        (bytes32 root, bytes32[] memory proof) = getProofAndRoot();
        address token = createToken(signer, true, 1155);
        for (uint256 i = 0; i < tokenIdArray.length; i++) {
            (uint8 v, bytes32 r, bytes32 s) = getSignatureWithTokenId(
                token,
                tokenIdArray[i],
                root,
                key,
                1155,
                currency
            );
            proofs.push(proof);
            roots.push(root);
            prices.push(100);
            mintMax.push(1);
            ids.push(tokenIdArray[i]);
            addresses.push(token);
            currencies.push(currency);
            vs.push(v);
            rs.push(r);
            ss.push(s);
        }
        vm.prank(bob);
        paymentToken.approve(address(router), 1000);
        OdysseyLib.BatchMint memory bulk = OdysseyLib.BatchMint(
            proofs,
            roots,
            prices,
            mintMax,
            ids,
            addresses,
            currencies,
            vs,
            rs,
            ss
        );
        vm.prank(bob);
        router.batchMintERC1155(bulk);
        for (uint256 i = 0; i < tokenIdArray.length; i++) {
            assertEq(
                router.whitelistClaimed1155(token, bob, tokenIdArray[i]),
                1,
                "not claimed"
            );
            assertEq(
                ERC1155(token).balanceOf(bob, tokenIdArray[i]),
                1,
                "bad balance"
            );
            assertEq(
                router.cumulativeSupply1155(token, tokenIdArray[i]),
                1 + reserveAmounts[i],
                "bad supply"
            );
        }
        assertEq(paymentToken.balanceOf(signer), 97 * tokenIdArray.length);
        assertEq(paymentToken.balanceOf(treasury), 3 * tokenIdArray.length);
        assertEq(xp.balanceOf(bob), 3 * tokenIdArray.length);
    }

    function testBulkReserve1155Authenticated() public {
        (bytes32 root, bytes32[] memory proof) = getProofAndRoot();
        address token = createToken(signer, true, 1155);
        for (uint256 i = 0; i < tokenIdArray.length; i++) {
            (uint8 v, bytes32 r, bytes32 s) = getSignatureWithTokenId(
                token,
                tokenIdArray[i],
                root,
                key,
                1155,
                currency
            );
            proofs.push(proof);
            roots.push(root);
            prices.push(100);
            mintMax.push(1);
            ids.push(tokenIdArray[i]);
            addresses.push(token);
            currencies.push(currency);
            vs.push(v);
            rs.push(r);
            ss.push(s);
        }
        vm.prank(bob);
        paymentToken.approve(address(router), 1000);
        OdysseyLib.BatchMint memory bulk = OdysseyLib.BatchMint(
            proofs,
            roots,
            prices,
            mintMax,
            ids,
            addresses,
            currencies,
            vs,
            rs,
            ss
        );
        vm.prank(bob);
        router.batchReserveERC1155(bulk);
        for (uint256 i = 0; i < tokenIdArray.length; i++) {
            assertEq(
                router.whitelistClaimed1155(token, bob, tokenIdArray[i]),
                0,
                "not claimed"
            );
            assertEq(
                ERC1155(token).balanceOf(bob, tokenIdArray[i]),
                0,
                "bad balance"
            );
            assertEq(
                router.cumulativeSupply1155(token, tokenIdArray[i]),
                1 + reserveAmounts[i],
                "bad supply"
            );
        }
        assertEq(paymentToken.balanceOf(signer), 97 * tokenIdArray.length);
        assertEq(paymentToken.balanceOf(treasury), 3 * tokenIdArray.length);
        assertEq(xp.balanceOf(bob), 3 * tokenIdArray.length);
    }

    function testMint1155AuthenticatedETHPay() public {
        (bytes32 root, bytes32[] memory proof) = getProofAndRoot();
        address token = createToken(signer, true, 1155, 69);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            root,
            key,
            1155,
            address(0)
        );

        vm.prank(bob);
        router.mintERC1155{value: 100}(
            proof,
            root,
            100,
            mintsPerUser,
            1,
            token,
            address(0),
            v,
            r,
            s
        );
        assertEq(router.whitelistClaimed1155(token, bob, 1), 1, "not claimed");
        assertEq(ERC1155(token).balanceOf(bob, 1), 1, "bad balance");
        assertEq(
            router.cumulativeSupply1155(token, 1),
            1 + reserveAmounts[0],
            "bad supply"
        );
        assertEq(signer.balance, 97);
        assertEq(treasury.balance, 3);
        assertEq(xp.balanceOf(bob), 0);
    }

    function testReserve1155Authenticated() public {
        (bytes32 root, bytes32[] memory proof) = getProofAndRoot();
        address token = createToken(signer, true, 1155);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            root,
            key,
            1155,
            currency
        );

        vm.prank(bob);
        router.reserveERC1155(
            proof,
            root,
            100,
            mintsPerUser,
            1,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.isReserved1155(token, bob, 1), 1);
        assertEq(router.whitelistClaimed1155(token, bob, 1), 0, "not claimed");
        assertEq(ERC1155(token).balanceOf(bob, 1), 0, "bad balance");
        assertEq(
            router.cumulativeSupply1155(token, 1),
            1 + reserveAmounts[0],
            "bad supply"
        );
        assertEq(paymentToken.balanceOf(signer), 97);
        assertEq(paymentToken.balanceOf(treasury), 3);
        assertEq(xp.balanceOf(bob), 3);

        vm.prank(bob);
        router.mintERC1155(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            1,
            token,
            currency,
            0,
            0,
            0
        );
        assertEq(router.whitelistClaimed1155(token, bob, 1), 1, "not claimed");
        assertEq(ERC1155(token).balanceOf(bob, 1), 1, "bad balance");
        assertEq(
            router.cumulativeSupply1155(token, 1),
            1 + reserveAmounts[0],
            "bad supply"
        );
        assertEq(xp.balanceOf(bob), 3);
    }

    function testReserve1155AuthenticatedETHPay() public {
        (bytes32 root, bytes32[] memory proof) = getProofAndRoot();
        address token = createToken(signer, true, 1155, 69);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            root,
            key,
            1155,
            address(0)
        );

        vm.prank(bob);
        router.reserveERC1155{value: 100}(
            proof,
            root,
            100,
            mintsPerUser,
            1,
            token,
            address(0),
            v,
            r,
            s
        );
        assertEq(router.isReserved1155(token, bob, 1), 1);
        assertEq(router.whitelistClaimed1155(token, bob, 1), 0, "not claimed");
        assertEq(ERC1155(token).balanceOf(bob, 1), 0, "bad balance");
        assertEq(
            router.cumulativeSupply1155(token, 1),
            1 + reserveAmounts[0],
            "bad supply"
        );
        assertEq(signer.balance, 97);
        assertEq(treasury.balance, 3);
        assertEq(xp.balanceOf(bob), 0);

        vm.prank(bob);
        router.mintERC1155(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            1,
            token,
            currency,
            0,
            0,
            0
        );
        assertEq(router.whitelistClaimed1155(token, bob, 1), 1, "not claimed");
        assertEq(ERC1155(token).balanceOf(bob, 1), 1, "bad balance");
        assertEq(
            router.cumulativeSupply1155(token, 1),
            1 + reserveAmounts[0],
            "bad supply"
        );
        assertEq(xp.balanceOf(bob), 0);
    }

    function testSetRoyaltyRecipient() public {
        address token = createToken(signer, false, 721);
        (uint8 v, bytes32 r, bytes32 s) = getSignature(
            token,
            merkleRoot,
            key,
            721,
            currency
        );
        vm.prank(signer);
        router.setRoyaltyRecipient(token, alice);
        vm.prank(bob);
        router.mintERC721(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            token,
            currency,
            v,
            r,
            s
        );
        assertEq(router.whitelistClaimed721(token, bob), 1);
        assertEq(ERC721(token).balanceOf(bob), 1);
        assertEq(router.cumulativeSupply721(token), 2);
        assertEq(router.mintedSupply721(token), 2);
        assertEq(paymentToken.balanceOf(alice), 97);
        assertEq(paymentToken.balanceOf(signer), 0);
        assertEq(paymentToken.balanceOf(treasury), 3);
        assertEq(xp.balanceOf(bob), 3);
    }

    function testMultiMint721(uint8 x) public {
        mintsPerUser = (x == 0) ? 1 : uint256(x);
        (address token, uint8 v, bytes32 r, bytes32 s) = createWithSig(
            mintsPerUser
        );
        vm.startPrank(bob);
        for (uint256 i = 0; i < mintsPerUser; i++) {
            paymentToken.approve(address(router), 100);
            router.mintERC721(
                merkleProof,
                merkleRoot,
                100,
                mintsPerUser,
                token,
                currency,
                v,
                r,
                s
            );
        }
        vm.stopPrank();
        check721Mints(mintsPerUser, token);
    }

    function testMint721UpdatedMaxSupplyCap(uint8 x) public {
        mintsPerUser = (x < 2) ? 2 : uint256(x);
        (address token, uint8 v, bytes32 r, bytes32 s) = createWithSig(
            mintsPerUser
        );
        vm.prank(signer);
        router.setMaxSupply721(token, mintsPerUser - 1);

        vm.startPrank(bob);
        for (uint256 i = 0; i < mintsPerUser - 2; i++) {
            paymentToken.approve(address(router), 100);
            router.mintERC721(
                merkleProof,
                merkleRoot,
                100,
                mintsPerUser,
                token,
                currency,
                v,
                r,
                s
            );
        }
        bytes memory customError = abi.encodeWithSignature(
            "OdysseyLaunchPlatform_MaxSupplyCap()"
        );
        paymentToken.approve(address(router), 100);
        vm.expectRevert(customError);
        router.mintERC721(
            merkleProof,
            merkleRoot,
            100,
            mintsPerUser,
            token,
            currency,
            v,
            r,
            s
        );
        vm.stopPrank();
        check721Mints(mintsPerUser - 2, token);
    }

    function testMultiReserve721(uint8 x) public {
        mintsPerUser = (x == 0) ? 1 : uint256(x);
        (address token, uint8 v, bytes32 r, bytes32 s) = createWithSig(
            mintsPerUser
        );
        vm.startPrank(bob);
        paymentToken.approve(address(router), 100 * mintsPerUser);
        for (uint256 i = 0; i < mintsPerUser; i++) {
            router.reserveERC721(
                merkleProof,
                merkleRoot,
                100,
                mintsPerUser,
                token,
                currency,
                v,
                r,
                s
            );
        }
        vm.stopPrank();
        check721Reserves(mintsPerUser, token);

        vm.startPrank(bob);
        for (uint256 i = 0; i < mintsPerUser; i++) {
            router.mintERC721(
                merkleProof,
                merkleRoot,
                100,
                mintsPerUser,
                token,
                currency,
                0,
                0,
                0
            );
        }
        vm.stopPrank();
        check721Mints(mintsPerUser, token);
    }

    function testMultiReserve721InOrder(uint8 x) public {
        mintsPerUser = (x == 0) ? 1 : uint256(x);
        (address token, uint8 v, bytes32 r, bytes32 s) = createWithSig(
            mintsPerUser
        );
        vm.startPrank(bob);
        paymentToken.approve(address(router), 100 * mintsPerUser);
        for (uint256 i = 0; i < mintsPerUser; i++) {
            router.reserveERC721(
                merkleProof,
                merkleRoot,
                100,
                mintsPerUser,
                token,
                currency,
                v,
                r,
                s
            );
            check721Reserves(i + 1, token);
        }
        for (uint256 i = 0; i < mintsPerUser; i++) {
            router.mintERC721(
                merkleProof,
                merkleRoot,
                100,
                mintsPerUser,
                token,
                currency,
                0,
                0,
                0
            );
        }
        vm.stopPrank();
        check721Mints(mintsPerUser, token);
    }

    function testMint1155UpdatedMaxsupply() public {
        mintsPerUser = 100;
        address token = createToken(signer, false, 1155);

        vm.prank(signer);
        router.setMaxSupply1155(token, tokenIdArray, updatedMaxSupply);
        bytes memory customError = abi.encodeWithSignature(
            "OdysseyLaunchPlatform_MaxSupplyCap()"
        );
        uint256 totalMinted = 0;
        vm.startPrank(bob);
        for (uint256 i = 0; i < tokenIdArray.length; i++) {
            (uint8 v, bytes32 r, bytes32 s) = getSignatureWithTokenId(
                token,
                tokenIdArray[i],
                merkleRoot,
                key,
                1155,
                currency
            );
            for (
                uint256 j = 0;
                j < updatedMaxSupply[i] - reserveAmounts[i];
                j++
            ) {
                paymentToken.approve(address(router), 100);
                router.mintERC1155(
                    merkleProof,
                    merkleRoot,
                    100,
                    mintsPerUser,
                    tokenIdArray[i],
                    token,
                    currency,
                    v,
                    r,
                    s
                );
                totalMinted += 1;
                assertEq(
                    router.whitelistClaimed1155(token, bob, tokenIdArray[i]),
                    j + 1,
                    "not claimed"
                );
                assertEq(
                    ERC1155(token).balanceOf(bob, tokenIdArray[i]),
                    j + 1,
                    "bad balance"
                );
                assertEq(
                    router.cumulativeSupply1155(token, tokenIdArray[i]),
                    (j + 1) + reserveAmounts[i],
                    "bad supply"
                );
                assertEq(
                    paymentToken.balanceOf(signer),
                    97 * totalMinted,
                    "Payment is wrong"
                );
                assertEq(
                    paymentToken.balanceOf(treasury),
                    3 * totalMinted,
                    "Payment is wrong"
                );
                assertEq(xp.balanceOf(bob), 3 * totalMinted);
            }
            paymentToken.approve(address(router), 100);
            vm.expectRevert(customError);
            router.mintERC1155(
                merkleProof,
                merkleRoot,
                100,
                mintsPerUser,
                tokenIdArray[i],
                token,
                currency,
                v,
                r,
                s
            );
        }
        vm.stopPrank();
    }

    // Internal methods

    function createWithSig(uint256 _mintsPerUser)
        internal
        returns (
            address token,
            uint8 v,
            bytes32 r,
            bytes32 s
        )
    {
        token = createToken(signer, false, 721, _mintsPerUser + 1);
        (v, r, s) = getSignature(token, merkleRoot, key, 721, currency);
    }

    function check721Mints(uint256 balance721, address token) internal {
        assertEq(router.whitelistClaimed721(token, bob), balance721);
        assertEq(ERC721(token).balanceOf(bob), balance721);
        assertEq(router.cumulativeSupply721(token), balance721 + 1);
        assertEq(router.mintedSupply721(token), balance721 + 1);
        assertEq(paymentToken.balanceOf(signer), 97 * balance721);
        assertEq(paymentToken.balanceOf(treasury), 3 * balance721);
        assertEq(router.isReserved721(token, bob), 0);
        assertEq(xp.balanceOf(bob), 3 * balance721);
    }

    function check721Reserves(uint256 balance721, address token) internal {
        assertEq(router.isReserved721(token, bob), balance721);
        assertEq(router.whitelistClaimed721(token, bob), 0);
        assertEq(ERC721(token).balanceOf(bob), 0);
        assertEq(
            router.cumulativeSupply721(token),
            balance721 + reserveAmounts[0]
        );
        assertEq(router.mintedSupply721(token), reserveAmounts[0]);
        assertEq(paymentToken.balanceOf(signer), 97 * balance721);
        assertEq(paymentToken.balanceOf(treasury), 3 * balance721);
        assertEq(xp.balanceOf(bob), 3 * balance721);
    }

    function createToken(
        address deployer,
        bool whitelist,
        uint256 tokenType
    ) internal returns (address) {
        return createToken(deployer, whitelist, tokenType, 69);
    }

    function create721Token(
        address deployer,
        bool whitelist,
        uint256 maxSupply721
    ) internal returns (address) {
        return createToken(deployer, whitelist, 721, maxSupply721);
    }

    function createToken(
        address _deployer,
        bool _whitelist,
        uint256 _tokenType,
        uint256 _maxSupply721
    ) internal returns (address) {
        vm.prank(_deployer);
        address token;
        if (_tokenType == 721) {
            token = router.create721(
                name,
                symbol,
                "ipfs://69/",
                _maxSupply721,
                reserveAmounts[0],
                commission,
                royaltyReceiver,
                _whitelist
            );
            assertEq(
                ERC721(token).balanceOf(_deployer),
                reserveAmounts[0],
                "Deployer reserve amount is wrong"
            );
            assertEq(
                ERC721(token).tokenURI(0),
                string(
                    abi.encodePacked(
                        "ipfs://69/",
                        Strings.toString(block.chainid),
                        "/",
                        Strings.toHexString(uint160(token)),
                        "/0"
                    )
                )
            );
        } else if (_tokenType == 1155) {
            token = router.create1155(
                name,
                symbol,
                "ipfs://69/",
                OdysseyLib.Odyssey1155Info(
                    maxSupplyArray,
                    tokenIdArray,
                    reserveAmounts
                ),
                commission,
                royaltyReceiver,
                _whitelist
            );
            uint256 i;
            for (; i < tokenIdArray.length; ++i) {
                assertEq(
                    ERC1155(token).balanceOf(_deployer, tokenIdArray[i]),
                    reserveAmounts[i],
                    "Deployer reserve amount is wrong"
                );
            }
            assertEq(
                ERC1155(token).uri(0),
                string(
                    abi.encodePacked(
                        "ipfs://69/",
                        Strings.toString(block.chainid),
                        "/",
                        Strings.toHexString(uint160(token)),
                        "/0"
                    )
                ),
                "URI is wrong"
            );
        }
        require(token != address(0), "Token is 0 address");
        assertEq(_deployer, router.ownerOf(token), "Deployer is not the owner");
        return token;
    }

    function getSignature(
        address token,
        bytes32 root,
        uint256 _key,
        uint256 tokenType,
        address _currency
    )
        internal
        returns (
            uint8,
            bytes32,
            bytes32
        )
    {
        return
            getSignatureWithTokenId(token, 1, root, _key, tokenType, _currency);
    }

    function getSignatureWithTokenId(
        address token,
        uint256 _tokenId,
        bytes32 root,
        uint256 _key,
        uint256 tokenType,
        address _currency
    )
        internal
        returns (
            uint8,
            bytes32,
            bytes32
        )
    {
        bytes32 domain = getDomain(token);
        assertEq(router.domainSeparator(token), domain, "domain mismatch");
        bytes32 hashStruct; //= hashTxn(root, 100);
        if (tokenType == 721) {
            hashStruct = hash721WhiteList(
                root,
                100,
                mintsPerUser,
                token,
                _currency
            );
        } else {
            hashStruct = hash1155WhiteList(
                root,
                100,
                mintsPerUser,
                _tokenId,
                token,
                _currency
            );
        }
        bytes32 digest = typedDataHash(domain, hashStruct);
        return vm.sign(_key, digest);
    }

    function getDomain(address token) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    // keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')
                    0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                    keccak256(
                        bytes(Strings.toHexString(uint160(address(token))))
                    ),
                    0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6, // keccak256(bytes("1"))
                    block.chainid,
                    address(token)
                )
            );
    }

    function getProofAndRoot()
        internal
        pure
        returns (bytes32, bytes32[] memory)
    {
        // precalculated using bobs address
        // https://github.com/miguelmota/merkletreejs-solidity
        bytes32 root = 0x3a15323d81912209a41cb864fb85b681091644fc0f98903b39326873e0f16341;
        bytes32[] memory proof = new bytes32[](4);
        proof[
            0
        ] = 0xafe7c546eb582218cf94b848c36f3b058e2518876240ae6100c4ef23d38f3e07;
        proof[
            1
        ] = 0x702d0f86c1baf15ac2b8aae489113b59d27419b751fbf7da0ef0bae4688abc7a;
        proof[
            2
        ] = 0xb159efe4c3ee94e91cc5740b9dbb26fc5ef48a14b53ad84d591d0eb3d65891ab;
        proof[
            3
        ] = 0x070e8db97b197cc0e4a1790c5e6c3667bab32d733db7f815fbe84f5824c7168d;
        return (root, proof);
    }

    function typedDataHash(bytes32 domain, bytes32 structHash)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("\x19\x01", domain, structHash));
    }

    function hash721WhiteList(
        bytes32 root,
        uint256 minPrice,
        uint256 _mintsPerUser,
        address tokenAddress,
        address _currency
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    MERKLE_TREE_ROOT_ERC721_TYPEHASH,
                    root,
                    minPrice,
                    _mintsPerUser,
                    tokenAddress,
                    _currency
                )
            );
    }

    function hash721Mint(
        uint256 minPrice,
        uint256 _mintsPerUser,
        address tokenAddress,
        address _currency
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    MIN_PRICE_ERC721_TYPEHASH,
                    minPrice,
                    _mintsPerUser,
                    tokenAddress,
                    _currency
                )
            );
    }

    function hash1155WhiteList(
        bytes32 root,
        uint256 minPrice,
        uint256 _mintsPerUser,
        uint256 tokenId,
        address tokenAddress,
        address _currency
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    MERKLE_TREE_ROOT_ERC1155_TYPEHASH,
                    root,
                    minPrice,
                    _mintsPerUser,
                    tokenId,
                    tokenAddress,
                    _currency
                )
            );
    }

    function hash1155Mint(
        uint256 minPrice,
        uint256 _mintsPerUser,
        uint256 tokenId,
        address tokenAddress,
        address _currency
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    MIN_PRICE_ERC1155_TYPEHASH,
                    minPrice,
                    _mintsPerUser,
                    tokenId,
                    tokenAddress,
                    _currency
                )
            );
    }
}
