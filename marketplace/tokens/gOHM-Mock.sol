// SPDX-License-Identifier: MIT
pragma solidity >=0.8.12;

import {ERC20} from "@solmate/tokens/ERC20.sol";

contract gOHM is ERC20("gOHM", "Governance Olympus", 18) {
    constructor(address to) {
        _mint(to, 100000000000000000000000);
    }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
