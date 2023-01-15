//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC20/IERC20.sol";

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import "solmate/utils/FixedPointMathLib.sol";

contract Forwarder is Ownable {
    /* ========== DEPENDENCIES ========== */
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;

    /* ====== CONSTANTS ====== */
    address constant ETH_ADDRESS = address(0);

    address payable private ADDR1;
    address payable private ADDR2;

    bool private _forward = true;
    bool private _split = false;

    constructor(address addr1_, address addr2_) {
        ADDR1 = payable(addr1_);
        ADDR2 = payable(addr2_);
    }

    receive() payable external {
        if (_forward) {
            if (_split) {
                uint256 bal_ = msg.value.mulDivDown(8, 10);

                bool success_;
                (success_,) = ADDR1.call{value : bal_}("");
                require(success_);

                (success_,) = ADDR2.call{value : msg.value - bal_}("");
                require(success_);
            } else {
                (bool success_,) = ADDR1.call{value : msg.value}("");
                require(success_);
            }
        }
    }

    function withdraw(address asset_) public {
        uint256 assetBalance_;
        if (asset_ == ETH_ADDRESS) {
            assetBalance_ = address(this).balance;
            (bool success,) = ADDR1.call{value : assetBalance_}("");
            require(success);
        } else {
            assetBalance_ = IERC20(asset_).balanceOf(address(this));
            IERC20(asset_).safeTransfer(ADDR1, assetBalance_);
        }
    }

    function setADDR1(address addr_, uint8 account_) external onlyOwner {
        if (account_ == 1) ADDR1 = payable(addr_);
        if (account_ == 2) ADDR2 = payable(addr_);
    }

    function setAutoForwarding(bool forward_) external onlyOwner {
        _forward = forward_;
    }

    function setSplit(bool split_) external onlyOwner {
        _split = split_;
    }
}
