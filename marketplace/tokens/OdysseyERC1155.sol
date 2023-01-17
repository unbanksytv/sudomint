// SPDX-License-Identifier: MIT
pragma solidity >=0.8.12;

import {ERC1155} from "@solmate/tokens/ERC1155.sol";
import {UInt2Str} from "../utils/UInt2Str.sol";

contract OdysseyERC1155 is ERC1155 {
    using UInt2Str for uint256;

    /*///////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/
    error OdysseyERC1155_AlreadyInit();
    error OdysseyERC1155_Unauthorized();
    error OdysseyERC1155_BadAddress();

    /*///////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/
    address launcher;
    address public owner;
    string public name;
    string public symbol;
    string public baseURI;
    bool initialized;
    uint256 public royaltyFeeInBips; // 1% = 100
    address public royaltyReceiver;
    string public contractURI;

    /*///////////////////////////////////////////////////////////////
                             METADATA LOGIC
    //////////////////////////////////////////////////////////////*/

    function uri(uint256 id)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return string(abi.encodePacked(baseURI, id.uint2str()));
    }

    /*///////////////////////////////////////////////////////////////
                              FACTORY LOGIC
    //////////////////////////////////////////////////////////////*/

    function initialize(
        address _launcher,
        address _owner,
        string calldata _name,
        string calldata _symbol,
        string calldata _baseURI
    ) external {
        if (isInit()) {
            revert OdysseyERC1155_AlreadyInit();
        }
        initialized = true;
        launcher = _launcher;
        owner = _owner;
        name = _name;
        symbol = _symbol;
        baseURI = _baseURI;
    }

    function isInit() internal view returns (bool) {
        return initialized;
    }

    /*///////////////////////////////////////////////////////////////
                              ERC1155 LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) public virtual {
        if (newOwner == address(0)) {
            revert OdysseyERC1155_BadAddress();
        }
        if (msg.sender != owner) {
            revert OdysseyERC1155_Unauthorized();
        }
        owner = newOwner;
    }

    function mint(address user, uint256 id) external {
        if (msg.sender != launcher) {
            revert OdysseyERC1155_Unauthorized();
        }
        _mint(user, id, 1, "");
    }

    function mintBatch(
        address user,
        uint256 id,
        uint256 amount
    ) external {
        if (msg.sender != launcher) {
            revert OdysseyERC1155_Unauthorized();
        }
        _mint(user, id, amount, "");
    }

    /*///////////////////////////////////////////////////////////////
                              EIP2981 LOGIC
    //////////////////////////////////////////////////////////////*/

    function royaltyInfo(uint256, uint256 _salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        return (royaltyReceiver, (_salePrice / 10000) * royaltyFeeInBips);
    }

    function setRoyaltyInfo(address _royaltyReceiver, uint256 _royaltyFeeInBips)
        external
    {
        if (_royaltyReceiver == address(0)) {
            revert OdysseyERC1155_BadAddress();
        }
        if (msg.sender != owner) {
            revert OdysseyERC1155_Unauthorized();
        }
        royaltyReceiver = _royaltyReceiver;
        royaltyFeeInBips = _royaltyFeeInBips;
    }

    function setContractURI(string memory _uri) public {
        if (msg.sender != owner) {
            revert OdysseyERC1155_Unauthorized();
        }
        contractURI = _uri;
    }

    /*///////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceID)
        public
        pure
        override(ERC1155)
        returns (bool)
    {
        return
            bytes4(keccak256("royaltyInfo(uint256,uint256)")) == interfaceID ||
            super.supportsInterface(interfaceID);
    }
}
