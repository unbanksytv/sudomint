// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";

import {OdysseyXpDirectory, Rewards, OdysseyXpDirectory_Unauthorized} from "../OdysseyXpDirectory.sol";
import {OdysseyERC721} from "../tokens/OdysseyERC721.sol";
import {OdysseyERC1155} from "../tokens/OdysseyERC1155.sol";
import {Utilities} from "./utils/Utilities.sol";

interface CheatCodes {
    function prank(address) external;

    function expectRevert(bytes4) external;
}

contract OdysseyXpDirectoryTest is DSTest {
    OdysseyXpDirectory directory;
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    Utilities internal utils;
    address payable[] internal users;
    address payable alice;
    address payable bob;
    OdysseyERC721 erc721;
    OdysseyERC1155 erc1155;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);
        alice = users[0];
        bob = users[1];
        directory = new OdysseyXpDirectory();
        erc721 = new OdysseyERC721();
        erc721.initialize(
            address(this),
            address(this),
            "Odyssey",
            "ODYSSEY",
            "odyssey"
        );
        erc1155 = new OdysseyERC1155();
        erc1155.initialize(
            address(this),
            address(this),
            "Odyssey",
            "ODYSSEY",
            "odyssey"
        );

        directory.setDefaultRewards(1, 1, 1, 3, 3, 1);
    }

    function testOnlyOwnerSetsDefaultRewards() public {
        cheats.expectRevert(OdysseyXpDirectory_Unauthorized.selector);
        cheats.prank(alice);
        directory.setDefaultRewards(10, 0, 10, 10, 10, 1);

        assertRewards(
            address(bob),
            address(0), // zero address will get default
            1,
            Rewards(1, 1, 1, 3, 3, 2),
            1
        );

        // now as owner
        directory.setDefaultRewards(10, 0, 10, 10, 10, 1);

        assertRewards(
            address(bob),
            address(0), // zero address will get default
            1,
            Rewards(10, 0, 10, 10, 10, 3),
            1
        );
    }

    function testOnlyOwnerSetsCustomRewards() public {
        cheats.expectRevert(OdysseyXpDirectory_Unauthorized.selector);
        cheats.prank(alice);
        directory.setErc721CustomRewards(
            address(erc721),
            10,
            10,
            10,
            10,
            10,
            10
        );
        assertRewards(
            address(bob),
            address(erc721),
            1,
            Rewards(1, 1, 1, 3, 3, 1),
            1
        );

        cheats.expectRevert(OdysseyXpDirectory_Unauthorized.selector);
        cheats.prank(alice);
        directory.setErc1155CustomRewards(
            address(erc1155),
            1,
            10,
            10,
            10,
            10,
            10,
            10
        );
        assertRewards(
            address(bob),
            address(erc1155),
            1,
            Rewards(1, 1, 1, 3, 3, 1),
            1
        );

        // now as owner
        directory.setErc721CustomRewards(
            address(erc721),
            10,
            10,
            10,
            10,
            10,
            10
        );
        assertRewards(
            address(bob),
            address(erc721),
            1,
            Rewards(10, 10, 10, 10, 10, 10),
            1
        );

        directory.setErc1155CustomRewards(
            address(erc1155),
            1,
            10,
            10,
            10,
            10,
            10,
            10
        );
        assertRewards(
            address(bob),
            address(erc721),
            1,
            Rewards(10, 10, 10, 10, 10, 10),
            1
        );
    }

    function testRewardsUseMultiplier() public {
        directory.setErc721CustomRewards(
            address(erc721),
            10,
            10,
            10,
            10,
            10,
            2
        );
        erc721.mint(address(bob), 1);

        directory.setErc1155CustomRewards(
            address(erc1155),
            1,
            10,
            10,
            10,
            10,
            10,
            2
        );
        erc1155.mint(address(bob), 1);

        assertRewards(
            address(bob),
            address(erc721),
            1,
            Rewards(10, 10, 10, 10, 10, 10),
            4
        );
    }

    function testRewardsMultiplierDoesNotCountOne() public {
        directory.setErc721CustomRewards(
            address(erc721),
            10,
            10,
            10,
            10,
            10,
            1
        );
        // two NFTs with a multiplier of 1, total multiplier should be 1, incorrect implementation would return 2
        erc721.mint(address(bob), 1);
        erc721.mint(address(bob), 2);

        assertRewards(
            address(bob),
            address(erc721),
            1,
            Rewards(10, 10, 10, 10, 10, 10),
            1
        );

        directory.setErc1155CustomRewards(
            address(erc1155),
            1,
            10,
            10,
            10,
            10,
            10,
            1
        );
        // two NFTs with a multiplier of 1, total multiplier should be 1, incorrect implementation would return 2
        erc1155.mint(address(bob), 1);
        erc1155.mint(address(bob), 1);

        assertRewards(
            address(bob),
            address(erc721),
            1,
            Rewards(10, 10, 10, 10, 10, 10),
            1
        );
    }

    function testRewardsMultiplierMax() public {
        directory.setErc721CustomRewards(
            address(erc721),
            10,
            10,
            10,
            10,
            10,
            10
        );
        erc721.mint(address(bob), 1);
        assertRewards(
            address(bob),
            address(erc721),
            1,
            Rewards(10, 10, 10, 10, 10, 10),
            4 // max at 4
        );

        directory.setErc1155CustomRewards(
            address(erc1155),
            1,
            10,
            10,
            10,
            10,
            10,
            10
        );
        erc1155.mint(address(bob), 1);
        assertRewards(
            address(bob),
            address(erc721),
            1,
            Rewards(10, 10, 10, 10, 10, 10),
            4 // max at 4
        );
    }

    function assertRewards(
        address user,
        address contractAddress,
        uint256 tokenId,
        Rewards memory rewards,
        uint256 multiplier
    ) public {
        assertEq(
            directory.getSaleReward(user, contractAddress, tokenId),
            rewards.sale * multiplier,
            "Incorrect sale reward"
        );
        assertEq(
            directory.getPurchaseReward(user, contractAddress, tokenId),
            rewards.purchase * multiplier,
            "Incorrect purchase reward"
        );
        assertEq(
            directory.getMintReward(user, contractAddress, tokenId),
            rewards.mint * multiplier,
            "Incorrect mint reward"
        );
        assertEq(
            directory.getOhmPurchaseReward(user, contractAddress, tokenId),
            rewards.ohmPurchase * multiplier,
            "Incorrect OHM purchase reward"
        );
        assertEq(
            directory.getOhmMintReward(user, contractAddress, tokenId),
            rewards.ohmMint * multiplier,
            "Incorrect OHM mint reward"
        );
    }
}
