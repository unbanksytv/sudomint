// SPDX-License-Identifier: MIT

pragma solidity >=0.8.12;

library OdysseyLib {
    struct Odyssey1155Info {
        uint256[] maxSupply;
        uint256[] tokenIds;
        uint256[] reserveAmounts;
    }

    struct BatchMint {
        bytes32[][] merkleProof;
        bytes32[] merkleRoot;
        uint256[] minPrice;
        uint256[] mintsPerUser;
        uint256[] tokenId;
        address[] tokenAddress;
        address[] currency;
        uint8[] v;
        bytes32[] r;
        bytes32[] s;
    }

    struct Percentage {
        uint256 numerator;
        uint256 denominator;
    }

    function compareDefaultPercentage(OdysseyLib.Percentage calldata percent)
        internal
        pure
        returns (bool result)
    {
        if (percent.numerator > percent.denominator) {
            // Can't have a percent greater than 100
            return false;
        }

        if (percent.numerator == 0 || percent.denominator == 0) {
            // Can't use 0 in percentage
            return false;
        }

        //Check cross multiplication of 3/100
        uint256 crossMultiple1 = percent.numerator * 100;
        uint256 crossMultiple2 = percent.denominator * 3;
        if (crossMultiple1 < crossMultiple2) {
            return false;
        }
        return true;
    }
}
