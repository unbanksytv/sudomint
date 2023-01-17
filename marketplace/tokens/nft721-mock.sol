// SPDX-License-Identifier: MIT
pragma solidity >=0.8.12;

import {ERC721} from "@solmate/tokens/ERC721.sol";
import {UInt2Str} from "../utils/UInt2Str.sol";

contract MockERC721 is ERC721("", "") {
    using UInt2Str for uint256;

    /*///////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/
    error OdysseyERC721_AlreadyInit();
    error OdysseyERC721_Unauthorized();
    error OdysseyERC721_BadAddress();

    /*///////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/
    address launcher;
    address public owner;
    bool initialized;
    string public baseURI;
    uint256 public royaltyFeeInBips; // 1% = 100
    address public royaltyReceiver;
    string public contractURI;

    /*///////////////////////////////////////////////////////////////
                              METADATA LOGIC
    //////////////////////////////////////////////////////////////*/

    function tokenURI(uint256 id)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return string(abi.encodePacked(baseURI, id.uint2str()));
    }

    function setBaseURI(string calldata _baseURI) external {
        baseURI = _baseURI;
    }

    /*///////////////////////////////////////////////////////////////
                              FACTORY LOGIC
    //////////////////////////////////////////////////////////////*/

    function initialize(
        string calldata _name,
        string calldata _symbol,
        string calldata _baseURI
    ) external {
        if (initialized) {
            revert OdysseyERC721_AlreadyInit();
        }
        initialized = true;
        name = _name;
        symbol = _symbol;
        baseURI = _baseURI;
    }

    /*///////////////////////////////////////////////////////////////
                              ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) public virtual {
        if (newOwner == address(0)) {
            revert OdysseyERC721_BadAddress();
        }
        if (msg.sender != owner) {
            revert OdysseyERC721_Unauthorized();
        }
        owner = newOwner;
    }

    function mint(address user, uint256 id) external {
        _mint(user, id);
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
            revert OdysseyERC721_BadAddress();
        }
        if (msg.sender != owner) {
            revert OdysseyERC721_Unauthorized();
        }
        royaltyReceiver = _royaltyReceiver;
        royaltyFeeInBips = _royaltyFeeInBips;
    }

    function setContractURI(string memory _uri) public {
        if (msg.sender != owner) {
            revert OdysseyERC721_Unauthorized();
        }
        contractURI = _uri;
    }

    /*///////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceID)
        public
        pure
        override(ERC721)
        returns (bool)
    {
        return
            bytes4(keccak256("royaltyInfo(uint256,uint256)")) == interfaceID ||
            super.supportsInterface(interfaceID);
    }
}
