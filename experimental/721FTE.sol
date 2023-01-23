// SPDX-License-Identifier: WTFPL
pragma solidity ^0.8.13;

import "./ERC721.sol";
import "./Ownable.sol";

interface ERC20 {
    function balanceOf(address _owner) external view returns (uint256 balance);
}

/// @notice ERC721FTR - an ERC721 that refuses to be traded for large sums of money (maybe)
/// @author Relyt29 - https://twitter.com/relyt29
abstract contract ERC721FTR is ERC721, Ownable {

    // Mainnet
    //ERC20 constant public WETH = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    // Rinkeby
    ERC20 constant public WETH = ERC20(0xc778417E063141139Fce010982780140Aa0cD5Ab);
    uint public THRESHOLD;

    constructor(uint t) {
        THRESHOLD = t;
    }

    function msgValue() public payable returns (uint256) {
        return msg.value;
    }

    function changeThreshold(uint t) public onlyOwner {
        THRESHOLD = t;
    }

    function mintRequires(address to) internal {
        // check the transaction doesn't have a value in the tx.value field
        // check neither the sender nor the reciever have more than THRESHOLD WETH
        // if so then a trade *probably* didn't happen... maybe
        require(msgValue() < THRESHOLD, "UNALLOWED_VALUE_TOO_HIGH");
        require(to.balance < THRESHOLD, "UNALLOWED_TOO_RICH_RECIPIENT");
        require(WETH.balanceOf(to) < THRESHOLD, "UNALLOWED_TOO_RICH_RECIPIENT_WETH");

        // Optional: msg.sender could be an intermediary contract
        // require(tx.origin.balance < THRESHOLD, "UNALLOWED_TOO_RICH_ORIGIN");
        // require(WETH.balanceOf(tx.origin) < THRESHOLD, "UNALLOWED_TOO_RICH_ORIGIN_WETH");
    }

    function transferRequires(address from, address to) internal {
        require(from.balance < THRESHOLD, "UNALLOWED_TOO_RICH_SENDER");
        require(WETH.balanceOf(from) < THRESHOLD, "UNALLOWED_TOO_RICH_SENDER");
        mintRequires(to);
    }

    function _safeMint(address to, uint256 id) internal override {
        mintRequires(to);
        ERC721._safeMint(to, id);
    }

    function _mint(address to, uint256 id) internal override {
        mintRequires(to);
        ERC721._mint(to, id);
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public override {
        transferRequires(from, to);
        ERC721.transferFrom(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public override {
        transferRequires(from, to);
        ERC721.safeTransferFrom(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) public override {
        transferRequires(from, to);
        ERC721.safeTransferFrom(from, to, id, data);
    }

}