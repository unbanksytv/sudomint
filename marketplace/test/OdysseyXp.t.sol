// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";

import {OdysseyXpDirectory, Rewards} from "../OdysseyXpDirectory.sol";
import {OdysseyXp, OdysseyXp_Unauthorized, OdysseyXp_NonTransferable, OdysseyXp_ZeroAssets} from "../OdysseyXp.sol";
import {OdysseyERC721} from "../tokens/OdysseyERC721.sol";
import {OdysseyERC1155} from "../tokens/OdysseyERC1155.sol";
import {gOHM} from "../tokens/gOHM-Mock.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";

interface CheatCodes {
    function prank(address) external;

    function expectRevert(bytes4) external;

    function startPrank(address) external;

    function stopPrank() external;
}

contract OdysseyXpTest is DSTest {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    Utilities internal utils;
    address payable[] internal users;
    address payable alice;
    address payable bob;
    address payable jerry;
    address payable router;
    address payable exchange;
    address payable nft;
    OdysseyXpDirectory directory;
    OdysseyXp xp;
    gOHM ohm;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(6);
        alice = users[0];
        bob = users[1];
        router = users[2];
        exchange = users[3];
        nft = users[4];
        jerry = users[5];
        directory = new OdysseyXpDirectory();
        ohm = new gOHM(address(0));
        xp = new OdysseyXp(
            ohm,
            directory,
            address(router),
            address(exchange),
            address(this)
        );

        directory.setDefaultRewards(1, 2, 3, 4, 5, 1);
    }

    function testOnlyOwnerCanSetExchange() public {
        cheats.expectRevert(OdysseyXp_Unauthorized.selector);
        cheats.prank(alice);
        xp.setExchange(address(bob));

        assertEq(xp.exchange(), address(exchange));

        xp.setExchange(address(bob));

        assertEq(xp.exchange(), address(bob));
    }

    function testOnlyOwnerCanSetRouter() public {
        cheats.expectRevert(OdysseyXp_Unauthorized.selector);
        cheats.prank(alice);
        xp.setRouter(address(bob));

        assertEq(xp.router(), address(router));

        xp.setRouter(address(bob));

        assertEq(xp.router(), address(bob));
    }

    function testOnlyOwnerCanSetDirectory() public {
        cheats.expectRevert(OdysseyXp_Unauthorized.selector);
        cheats.prank(alice);
        xp.setDirectory(address(bob));

        assertEq(address(xp.directory()), address(directory));

        xp.setDirectory(address(bob));

        assertEq(address(xp.directory()), address(bob));
    }

    function testOnlyOwnerCanTransferOwnership() public {
        cheats.expectRevert(OdysseyXp_Unauthorized.selector);
        cheats.prank(alice);
        xp.transferOwnership(address(bob));

        assertEq(xp.owner(), address(address(this)));

        xp.transferOwnership(address(bob));

        assertEq(xp.owner(), address(bob));
    }

    function testOnlyExchangeGrantsSaleXP() public {
        cheats.expectRevert(OdysseyXp_Unauthorized.selector);
        xp.saleReward(bob, nft, 1);

        assertEq(xp.balanceOf(bob), 0);

        cheats.prank(exchange);
        xp.saleReward(bob, nft, 1);

        assertEq(xp.balanceOf(bob), 1);
    }

    function testOnlyExchangeGrantsPurchaseXP() public {
        cheats.expectRevert(OdysseyXp_Unauthorized.selector);
        xp.purchaseReward(bob, nft, 1);

        assertEq(xp.balanceOf(bob), 0);

        cheats.prank(exchange);
        xp.purchaseReward(bob, nft, 1);

        assertEq(xp.balanceOf(bob), 2);
    }

    function testOnlyRouterGrantsMintXP() public {
        cheats.expectRevert(OdysseyXp_Unauthorized.selector);
        cheats.prank(exchange);
        xp.mintReward(bob, nft, 1);

        assertEq(xp.balanceOf(bob), 0);

        cheats.prank(router);
        xp.mintReward(bob, nft, 1);

        assertEq(xp.balanceOf(bob), 3);
    }

    function testOnlyExchangeGrantsOhmPurchaseXP() public {
        cheats.expectRevert(OdysseyXp_Unauthorized.selector);
        xp.ohmPurchaseReward(bob, nft, 1);

        assertEq(xp.balanceOf(bob), 0);

        cheats.prank(exchange);
        xp.ohmPurchaseReward(bob, nft, 1);

        assertEq(xp.balanceOf(bob), 4);
    }

    function testOnlyRouterGrantsOhmMintXP() public {
        cheats.expectRevert(OdysseyXp_Unauthorized.selector);
        cheats.prank(exchange);
        xp.ohmMintReward(bob, nft, 1);

        assertEq(xp.balanceOf(bob), 0);

        cheats.prank(router);
        xp.ohmMintReward(bob, nft, 1);

        assertEq(xp.balanceOf(bob), 5);
    }

    function testXpTransfersAreDisabled() public {
        cheats.prank(exchange);
        xp.ohmPurchaseReward(bob, nft, 1);

        cheats.expectRevert(OdysseyXp_NonTransferable.selector);
        cheats.prank(bob);
        xp.transfer(alice, 1);

        cheats.expectRevert(OdysseyXp_NonTransferable.selector);
        cheats.prank(bob);
        xp.transferFrom(bob, alice, 1);
    }

    function testCanRedeemAllXp() public {
        cheats.prank(exchange);
        xp.saleReward(bob, nft, 1);
        ohm.mint(address(xp), 10);

        cheats.prank(bob);
        xp.redeem();
        assertEq(ohm.balanceOf(bob), 10);
    }

    function testMultipleUsersCanRedeemPortions() public {
        cheats.startPrank(exchange);
        xp.saleReward(bob, nft, 1);
        xp.ohmPurchaseReward(alice, nft, 1);
        cheats.stopPrank();

        ohm.mint(address(xp), 10);

        cheats.prank(bob);
        xp.redeem();
        assertEq(ohm.balanceOf(bob), 2);

        ohm.mint(address(xp), 11);
        cheats.prank(router);
        xp.ohmMintReward(jerry, nft, 1);
        cheats.prank(exchange);
        xp.saleReward(alice, nft, 1);

        assertEq(ohm.balanceOf(alice), 8); // alice had to redeem on XP increase

        cheats.prank(bob);
        xp.redeem();
        assertEq(ohm.balanceOf(bob), 3);

        cheats.prank(jerry);
        xp.redeem();
        assertEq(ohm.balanceOf(jerry), 8); // jerry entered the picture when the contract had 19 OHM

        assertEq(xp.previewRedeem(alice, 5), 0);
    }

    function testXpWhenEmpty() public {
        cheats.expectRevert(OdysseyXp_ZeroAssets.selector);
        cheats.prank(bob);
        xp.redeem();

        cheats.prank(exchange);
        xp.ohmPurchaseReward(bob, nft, 1);
        ohm.mint(address(xp), 10);

        cheats.prank(bob);
        xp.redeem();
        assertEq(ohm.balanceOf(bob), 10);

        cheats.expectRevert(OdysseyXp_ZeroAssets.selector);
        cheats.prank(bob);
        xp.redeem();
    }
}
