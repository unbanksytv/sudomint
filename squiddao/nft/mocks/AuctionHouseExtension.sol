pragma solidity ^0.8.0;

import "../AuctionHouse.sol";

contract AuctionHouseExtension is AuctionHouse {
    function test() public pure returns (string memory) {
        return "test";
    }
}
