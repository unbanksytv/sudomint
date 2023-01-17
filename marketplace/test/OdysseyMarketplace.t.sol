// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {Vm} from "forge-std/Vm.sol";
import {ERC721} from "@solmate/tokens/ERC721.sol";
import {ERC1155} from "@solmate/tokens/ERC1155.sol";
import {OdysseyERC721} from "@odyssey/tokens/OdysseyERC721.sol";
import {OdysseyERC1155} from "@odyssey/tokens/OdysseyERC1155.sol";
import {gOHM} from "@odyssey/tokens/gOHM-Mock.sol";
//import {console} from "./utils/Console.sol";
import {Marketplace} from "@odyssey/OdysseyMarketplace.sol";

contract MarketPlaceTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    Utilities internal utils;
    address payable[] internal users;
    Marketplace marketplace;
    address payable alice;
    address payable bob;
    address payable cat;

    uint256 treasuryKey;
    address treasury;
    gOHM gohm;
    OdysseyERC721 nft;
    OdysseyERC1155 erc1155;
    OdysseyERC721 accessPass721;
    OdysseyERC1155 accessPass1155;
    Marketplace.AccessPass pass;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);
        alice = users[0];
        bob = users[1];
        cat = users[2];

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(cat, "Cat");

        treasuryKey = 42069;
        treasury = vm.addr(treasuryKey);

        gohm = new gOHM(bob);
        
        marketplace = new Marketplace(
            treasury,
            address(0),
            address(0),
            address(gohm)
        );
        
        nft = new OdysseyERC721();
        nft.initialize(
            address(this),
            address(this),
            "ACoolNFT",
            "NFT",
            "ipfs://"
        );
        nft.mint(alice, 1);
        nft.mint(alice, 2);

        vm.prank(alice);
        nft.setApprovalForAll(address(marketplace), true);

        erc1155 = new OdysseyERC1155();
        erc1155.initialize(
            address(this),
            address(this),
            "A Cool 1155",
            "NFT1155",
            "ipfs://"
        );
        erc1155.mintBatch(alice, 0, 100);
        erc1155.mintBatch(alice, 1, 100);
        erc1155.mintBatch(alice, 2, 200);

        erc1155.mintBatch(cat, 1, 10);

        vm.prank(alice);
        erc1155.setApprovalForAll(address(marketplace), true);

        vm.prank(cat);
        erc1155.setApprovalForAll(address(marketplace), true);

        accessPass1155 = new OdysseyERC1155();
        accessPass1155.initialize(
            address(this),
            address(this),
            "AcessPass 1155",
            "ACCESS",
            "ipfs://"
        );
        accessPass1155.mintBatch(bob, 2, 1);

        pass.contractAddress = address(accessPass1155);
        pass.tokenIds.push(0);
        pass.tokenIds.push(1);
        pass.tokenIds.push(2);
        pass.isERC1155 = true;

        marketplace.setGlobalAccessPass(pass);

        /*vm.startPrank(alice);
        marketplace.setAccessPass(pass, address(nft));
        marketplace.setAccessPass(pass, address(erc1155));
        vm.stopPrank();*/

        /*
        accessPass721 = new OdysseyERC721();
        accessPass721.initialize(address(this), address(this), "AcessPass 1155", "ACCESS", "ipfs://");
        accessPass721.mint(bob, 1);

        pass.contractAddress = address(accessPass721);
        pass.isERC1155 = false;
        vm.startPrank(alice);
        marketplace.setAccessPass(pass, address(nft));
        marketplace.setAccessPass(pass, address(erc1155));
        vm.stopPrank();
        */
    }

    function testList721Collection() public {
        // list
        uint256 beginAliceBalance = alice.balance;
        uint256 beginBobBalance = bob.balance;

        Marketplace.PaymentInfo memory payment = Marketplace.PaymentInfo(
            100,
            address(0)
        );
        Marketplace.PaymentInfo[]
            memory payments = new Marketplace.PaymentInfo[](1);
        payments[0] = payment;

        Marketplace.Royalties memory royalty = Marketplace.Royalties(
            address(alice),
            100
        );
        Marketplace.Royalties[] memory royalties = new Marketplace.Royalties[](
            1
        );
        royalties[0] = royalty;

        Marketplace.NewCollection memory collection = Marketplace.NewCollection(
            address(nft),
            2,
            payments,
            royalties
        );

        vm.prank(alice);
        marketplace.listERC721Collection(collection);

        // buy
        Marketplace.BuyOrder memory buy = Marketplace.BuyOrder(
            address(alice),
            address(nft),
            1,
            1,
            address(0)
        );
        Marketplace.BuyOrder[] memory buys = new Marketplace.BuyOrder[](1);
        buys[0] = buy;

        vm.prank(bob);
        marketplace.buyERC721{value: 100}(buys);

        assertEq(ERC721(address(nft)).balanceOf(bob), 1);
        assertEq(ERC721(address(nft)).balanceOf(alice), 1);
        assertEq(treasury.balance, 3);
        assertEq(alice.balance, beginAliceBalance + 97);
        assertEq(bob.balance, beginBobBalance - 100);
    }

    function testList721() public {
        // list
        uint256 beginAliceBalance = alice.balance;
        uint256 beginBobBalance = bob.balance;

        Marketplace.PaymentInfo memory payment = Marketplace.PaymentInfo(
            100,
            address(0)
        );
        Marketplace.PaymentInfo[]
            memory payments = new Marketplace.PaymentInfo[](1);
        payments[0] = payment;

        Marketplace.Royalties memory royalty = Marketplace.Royalties(
            address(alice),
            100
        );
        Marketplace.Royalties[] memory royalties = new Marketplace.Royalties[](
            1
        );
        royalties[0] = royalty;

        Marketplace.NewListing memory listing = Marketplace.NewListing(
            address(nft),
            1,
            1,
            payments,
            royalties,
            false
        );
        Marketplace.NewListing[] memory listings = new Marketplace.NewListing[](
            1
        );
        listings[0] = listing;

        vm.prank(alice);
        marketplace.listERC721(listings);

        // buy
        Marketplace.BuyOrder memory buy = Marketplace.BuyOrder(
            address(alice),
            address(nft),
            1,
            1,
            address(0)
        );
        Marketplace.BuyOrder[] memory buys = new Marketplace.BuyOrder[](1);
        buys[0] = buy;

        vm.prank(bob);
        marketplace.buyERC721{value: 100}(buys);

        assertEq(ERC721(address(nft)).balanceOf(bob), 1);
        assertEq(ERC721(address(nft)).balanceOf(alice), 1);
        assertEq(treasury.balance, 3);
        assertEq(alice.balance, beginAliceBalance + 97);
        assertEq(bob.balance, beginBobBalance - 100);
    }

    function _listERC721_2Payments() internal {
        Marketplace.PaymentInfo memory payment = Marketplace.PaymentInfo(
            100,
            address(0)
        );
        Marketplace.PaymentInfo memory paymentERC20 = Marketplace.PaymentInfo(
            1000,
            address(gohm)
        );
        Marketplace.PaymentInfo[]
            memory payments = new Marketplace.PaymentInfo[](2);
        payments[0] = payment;
        payments[1] = paymentERC20;

        Marketplace.Royalties memory royalty = Marketplace.Royalties(
            address(alice),
            100
        );
        Marketplace.Royalties[] memory royalties = new Marketplace.Royalties[](
            1
        );
        royalties[0] = royalty;

        Marketplace.NewListing memory listing = Marketplace.NewListing(
            address(nft),
            1,
            1,
            payments,
            royalties,
            false
        );
        Marketplace.NewListing[] memory listings = new Marketplace.NewListing[](
            1
        );
        listings[0] = listing;

        vm.prank(alice);
        marketplace.listERC721(listings);
    }

    function testList721PayERC20() public {
        // list
        uint256 beginAliceBalance = gohm.balanceOf(alice);
        uint256 beginBobBalance = gohm.balanceOf(bob);

        _listERC721_2Payments();

        // buy
        Marketplace.BuyOrder memory buy = Marketplace.BuyOrder(
            address(alice),
            address(nft),
            1,
            1,
            address(gohm)
        );
        Marketplace.BuyOrder[] memory buys = new Marketplace.BuyOrder[](1);
        buys[0] = buy;

        vm.startPrank(bob);
        gohm.approve(address(marketplace), 1000);
        marketplace.buyERC721(buys);
        vm.stopPrank();

        assertEq(ERC721(address(nft)).balanceOf(bob), 1);
        assertEq(ERC721(address(nft)).balanceOf(alice), 1);
        assertEq(gohm.balanceOf(treasury), 30);
        assertEq(gohm.balanceOf(alice), beginAliceBalance + 970);
        assertEq(gohm.balanceOf(bob), beginBobBalance - 1000);
    }

    function testList1155() public {
        uint256 beginAliceBalance = alice.balance;
        uint256 beginBobBalance = bob.balance;

        Marketplace.PaymentInfo memory payment = Marketplace.PaymentInfo(
            100,
            address(0)
        );
        Marketplace.PaymentInfo[]
            memory payments = new Marketplace.PaymentInfo[](1);
        payments[0] = payment;

        Marketplace.Royalties memory royalty = Marketplace.Royalties(
            address(alice),
            100
        );
        Marketplace.Royalties[] memory royalties = new Marketplace.Royalties[](
            1
        );
        royalties[0] = royalty;

        Marketplace.NewListing memory listing = Marketplace.NewListing(
            address(erc1155),
            0,
            5,
            payments,
            royalties,
            true
        );
        Marketplace.NewListing[] memory listings = new Marketplace.NewListing[](
            1
        );
        listings[0] = listing;

        vm.prank(alice);
        marketplace.listERC1155(listings);
        // buy
        Marketplace.BuyOrder memory buy = Marketplace.BuyOrder(
            address(alice),
            address(erc1155),
            0,
            5,
            address(0)
        );
        Marketplace.BuyOrder[] memory buys = new Marketplace.BuyOrder[](1);
        buys[0] = buy;

        vm.prank(bob);
        marketplace.buyERC1155{value: 100*5}(buys);

        assertEq(ERC1155(address(erc1155)).balanceOf(bob, 0), 5);
        assertEq(ERC1155(address(erc1155)).balanceOf(alice, 0), 95);
        assertEq(treasury.balance, 3*5);
        assertEq(alice.balance, beginAliceBalance + 97*5);
        assertEq(bob.balance, beginBobBalance - 100*5);
    }

    function testList1155PayERC20() public {
        uint256 beginAliceBalance = gohm.balanceOf(alice);
        uint256 beginBobBalance = gohm.balanceOf(bob);

        Marketplace.PaymentInfo memory payment = Marketplace.PaymentInfo(
            100,
            address(0)
        );
        Marketplace.PaymentInfo memory paymentERC20 = Marketplace.PaymentInfo(
            2000,
            address(gohm)
        );
        Marketplace.PaymentInfo[]
            memory payments = new Marketplace.PaymentInfo[](2);
        payments[0] = payment;
        payments[1] = paymentERC20;

        Marketplace.Royalties memory royalty = Marketplace.Royalties(
            address(alice),
            100
        );
        Marketplace.Royalties[] memory royalties = new Marketplace.Royalties[](
            1
        );
        royalties[0] = royalty;

        Marketplace.NewListing memory listing = Marketplace.NewListing(
            address(erc1155),
            0,
            5,
            payments,
            royalties,
            true
        );
        Marketplace.NewListing[] memory listings = new Marketplace.NewListing[](
            1
        );
        listings[0] = listing;

        vm.prank(alice);
        marketplace.listERC1155(listings);
        // buy
        Marketplace.BuyOrder memory buy = Marketplace.BuyOrder(
            address(alice),
            address(erc1155),
            0,
            5,
            address(gohm)
        );
        Marketplace.BuyOrder[] memory buys = new Marketplace.BuyOrder[](1);
        buys[0] = buy;

        vm.startPrank(bob);
        gohm.approve(address(marketplace), 2000*5);
        marketplace.buyERC1155(buys);
        vm.stopPrank();

        assertEq(ERC1155(address(erc1155)).balanceOf(bob, 0), 5);
        assertEq(ERC1155(address(erc1155)).balanceOf(alice, 0), 95);
        assertEq(gohm.balanceOf(treasury), 60*5);
        assertEq(gohm.balanceOf(alice), beginAliceBalance + 1940*5);
        assertEq(gohm.balanceOf(bob), beginBobBalance - 2000*5);
    }

    function _list1155s(address owner, uint256 id, uint256 paymentAmount1, uint256 paymentAmount2) public {
        Marketplace.PaymentInfo memory payment = Marketplace.PaymentInfo(
            paymentAmount1,
            address(0)
        );
        Marketplace.PaymentInfo memory paymentERC20 = Marketplace.PaymentInfo(
            paymentAmount2,
            address(gohm)
        );
        Marketplace.PaymentInfo[]
            memory payments = new Marketplace.PaymentInfo[](2);
        payments[0] = payment;
        payments[1] = paymentERC20;

        Marketplace.Royalties memory royalty = Marketplace.Royalties(
            address(owner),
            100
        );
        Marketplace.Royalties[] memory royalties = new Marketplace.Royalties[](
            1
        );
        royalties[0] = royalty;

        Marketplace.NewListing memory listing = Marketplace.NewListing(
            address(erc1155),
            id,
            5,
            payments,
            royalties,
            true
        );
        Marketplace.NewListing[] memory listings = new Marketplace.NewListing[](
            1
        );
        listings[0] = listing;

        vm.prank(owner);
        marketplace.listERC1155(listings);
    }


    function test2OwnerList1155PayERC20() public {
        uint256 beginAliceBalance = gohm.balanceOf(alice);
        uint256 beginBobBalance = gohm.balanceOf(bob);
        uint256 id = 1;
        _list1155s(alice, id, 100, 2000);
        _list1155s(cat, id, 50, 1000);

        // buy
        Marketplace.BuyOrder memory buy = Marketplace.BuyOrder(
            address(alice),
            address(erc1155),
            id,
            5,
            address(gohm)
        );
        Marketplace.BuyOrder[] memory buys = new Marketplace.BuyOrder[](1);
        buys[0] = buy;

        vm.startPrank(bob);
        gohm.approve(address(marketplace), 2000*5);
        marketplace.buyERC1155(buys);
        vm.stopPrank();

        assertEq(ERC1155(address(erc1155)).balanceOf(bob, id), 5);
        assertEq(ERC1155(address(erc1155)).balanceOf(alice, id), 95);
        assertEq(gohm.balanceOf(treasury), 60*5);
        assertEq(gohm.balanceOf(alice), beginAliceBalance + 1940*5);
        assertEq(gohm.balanceOf(bob), beginBobBalance - 2000*5);
    }

    function test2OwnerList1155PayCatERC20() public {
        uint256 beginAliceBalance = gohm.balanceOf(alice);
        uint256 beginBobBalance = gohm.balanceOf(bob);
        uint256 id = 1;
        _list1155s(alice, id, 100, 2000);
        _list1155s(cat, id, 50, 1000);

        // buy
        Marketplace.BuyOrder memory buy = Marketplace.BuyOrder(
            address(cat),
            address(erc1155),
            id,
            3,
            address(gohm)
        );
        Marketplace.BuyOrder[] memory buys = new Marketplace.BuyOrder[](1);
        buys[0] = buy;

        vm.startPrank(bob);
        gohm.approve(address(marketplace), 1000*5);
        marketplace.buyERC1155(buys);

        buy = Marketplace.BuyOrder(
            address(cat),
            address(erc1155),
            id,
            2,
            address(gohm)
        );
        buys[0] = buy;
        gohm.approve(address(marketplace), 1000*5);

        marketplace.buyERC1155(buys);
        vm.stopPrank();

        assertEq(ERC1155(address(erc1155)).balanceOf(bob, id), 5);
        assertEq(ERC1155(address(erc1155)).balanceOf(alice, id), 100);
        assertEq(ERC1155(address(erc1155)).balanceOf(cat, id), 5);
        assertEq(gohm.balanceOf(treasury), 30*5);
        assertEq(gohm.balanceOf(cat), 970*5);
        assertEq(gohm.balanceOf(bob), beginBobBalance - 1000*5);
    }

    function testList721CollectionAndSingle() public {
        // list collection
        uint256 beginAliceBalance = gohm.balanceOf(alice);
        uint256 beginBobBalance = gohm.balanceOf(bob);

        Marketplace.PaymentInfo memory payment = Marketplace.PaymentInfo(
            100,
            address(0)
        );
        Marketplace.PaymentInfo[]
            memory payments = new Marketplace.PaymentInfo[](1);
        payments[0] = payment;

        Marketplace.Royalties memory royalty = Marketplace.Royalties(
            address(alice),
            100
        );
        Marketplace.Royalties[] memory royalties = new Marketplace.Royalties[](
            1
        );
        royalties[0] = royalty;

        Marketplace.NewCollection memory collection = Marketplace.NewCollection(
            address(nft),
            2,
            payments,
            royalties
        );

        vm.prank(alice);
        marketplace.listERC721Collection(collection);

        // list single
        _listERC721_2Payments();
        // buy single
        Marketplace.BuyOrder memory buy = Marketplace.BuyOrder(
            address(alice),
            address(nft),
            1,
            1,
            address(gohm)
        );
        Marketplace.BuyOrder[] memory buys = new Marketplace.BuyOrder[](1);
        buys[0] = buy;

        vm.startPrank(bob);
        gohm.approve(address(marketplace), 1000);
        marketplace.buyERC721(buys);
        vm.stopPrank();

        assertEq(ERC721(address(nft)).balanceOf(bob), 1);
        assertEq(ERC721(address(nft)).balanceOf(alice), 1);
        assertEq(gohm.balanceOf(treasury), 30);
        assertEq(gohm.balanceOf(alice), beginAliceBalance + 970);
        assertEq(gohm.balanceOf(bob), beginBobBalance - 1000);
    }
}
