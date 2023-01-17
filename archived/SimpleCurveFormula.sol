// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Utils.sol";
import "./interfaces/ISimpleCurveFormula.sol";
import "hardhat/console.sol";

/**
 * bancor formula by bancor
 * https://github.com/bancorprotocol/contracts
 */
contract SimpleCurveFormula is ISimpleCurveFormula, Utils {
    constructor() {}

    /**
    TODO return the change 
      @dev Calculate using quadratic formula how many tokens
          you can get based on the current supply curve
      Quadratic Formula:
      ((x + _supply) / 2) * (x - _supply) = _value
      x^2 = supply^2 + (2 * value)
      @param _supply current erc20 token supply
      @param _value value sent buy sender
      @return tokens that can be purchased
     */
    function calculateBuyReturn(uint256 _supply, uint256 _value)
        public
        pure
        override
        returns (uint256, uint256)
    {
        uint256 consts = (_supply * _supply) + (_value * 2);
        uint256 newSupply = sqrt(consts);
        uint256 newTokens = newSupply - _supply;
        uint256 cost = calculateBuyCost(_supply, newTokens);
        return (newTokens, cost);
    }

    /**
      @dev Calculate using midpoint formula how many tokens
          you can get based on the current supply curve
      
      Formula:
      ((supply + (supply - amount)) / 2) * x = cost
      @param _supply current erc20 token supply
      @param _amount token amount to sell
      @return wei amount of wei received for selling tokens
     */
    function calculateSaleReturn(uint256 _supply, uint256 _amount)
        public
        pure
        override
        returns (uint256)
    {
        uint256 midpoint = (_supply * 2) - _amount;
        if (midpoint < 2) return 1;
        midpoint = (midpoint * 10) / 2;
        uint256 reward = (midpoint * _amount) / 10;
        return reward;
    }

    /**
      @dev calculate how much wei needed to send to get the number of tokens
      Midpoint Formula:
      ((x + supply) + supply) / 2) * x = cost
      @param _supply the current erc20 supply
      @param _amount the amount of new tokens to mint
      @return cost amount wei needed to send to get the amount
     */
    function calculateBuyCost(uint256 _supply, uint256 _amount)
        public
        pure
        override
        returns (uint256)
    {
        uint256 midpoint = _amount + (_supply * 2);
        if (midpoint < 2) return 1;
        midpoint = (midpoint * 10) / 2;
        uint256 cost = (midpoint * _amount) / 10;
        return cost;
    }

    /**
      @dev Calculate using quadratic formula how many tokens
          are required to get target wei
      Quadratic Formula:
      ((_supply + x) / 2) * (_supply - x) = _value
      x^2 = supply^2 - (2 * value)
      @param _supply current erc20 token supply
      @param _value wei value sent buy sender
      @return tokens that can be purchased
     */
    function calculateSaleCost(uint256 _supply, uint256 _value)
        public
        pure
        override
        returns (uint256)
    {
        uint256 supplySqrd = _supply * _supply;
        uint256 valMul2 = _value * 2;
        require(supplySqrd > valMul2, "Not enough supply for this amount");
        uint256 constants = supplySqrd - valMul2;
        uint256 newSupply = sqrt(constants);
        uint256 tokens = _supply - newSupply;
        return tokens;
    }

    /**
      @dev square root based on babylionian method
      @param x the value to sqrt
      @return y sqrted value x
     */
    function sqrt(uint256 x) private pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}