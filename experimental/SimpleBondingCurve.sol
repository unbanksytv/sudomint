// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./SimpleCurveFormula.sol";
import "hardhat/console.sol";

/**
 * @title Universal Bonding Curve
 * @dev Bonding curve contract based on bacor formula
 * inspired by bancor protocol and simondlr
 * https://github.com/bancorprotocol/contracts
 * https://github.com/ConsenSys/curationmarkets/blob/master/CurationMarkets.sol
 * uses bancor formula
 */
contract SimpleBondingCurve is ERC20, SimpleCurveFormula, Ownable {
    uint256 public poolBalance;

    constructor() ERC20("BondingCurve", "BC") {}

    /*
    - Front-running attacks are currently mitigated by the following mechanisms:
    TODO - minimum return argument for each conversion provides a way to define a minimum/maximum price for the transaction
    - gas price limit prevents users from having control over the order of execution
  */
    uint256 public gasPrice = 800000000 wei; // maximum gas price for bancor transactions

    /**
     * @dev receive function
     */
    receive() external payable {
        buy();
    }

    /**
     * @dev default fallback function
     *
     */
    fallback() external payable {
        buy();
    }

    /**
     * @dev buy tokens
     * gas cost 77508
     * @return {bool}
     */
    function buy() public payable validGasPrice returns (bool) {
        require(msg.value > 0, "value cannot be zero");

        uint256 tokensToMint;
        uint256 cost;
        (tokensToMint, cost) = calculateBuyReturn(totalSupply(), msg.value);

        _mint(msg.sender, tokensToMint);

        poolBalance = poolBalance + cost;
        uint256 change = msg.value - cost;
        // send back any change
        payable(msg.sender).transfer(change);
        emit LogTrade("mint", msg.value, tokensToMint);
        return true;
    }

    /**
     * @dev sell tokens
     * gase cost 86454
     * @param sellAmount amount of tokens to withdraw
     * @return {bool}
     */
    function sell(uint256 sellAmount) public validGasPrice returns (bool) {
        require(
            sellAmount > 0 && balanceOf(msg.sender) >= sellAmount,
            "Seller does not have this amount."
        );
        uint256 ethAmount = calculateSaleReturn(totalSupply(), sellAmount);
        poolBalance = poolBalance - ethAmount;
        payable(msg.sender).transfer(ethAmount);
        _burn(msg.sender, sellAmount);
        emit LogTrade("burn", ethAmount, sellAmount);
        return true;
    }

    // verifies that the gas price is lower than the universal limit
    modifier validGasPrice() {
        require(
            tx.gasprice <= gasPrice,
            string(
                bytes.concat(
                    bytes(Strings.toString(tx.gasprice)),
                    " gas price req failed"
                )
            )
        );
        _;
    }

    /**
     *  @dev allows the owner to update the gas price limit
     *  @param _gasPrice    new gas price limit
     */
    function setGasPrice(uint256 _gasPrice) public onlyOwner {
        require(_gasPrice > 0, "Gas price cannot be 0");
        gasPrice = _gasPrice;
    }

    event LogTrade(string side, uint256 weiAmt, uint256 erc20Amt);
}