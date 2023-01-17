// SPDX-License-Identifier: MIT
pragma solidity >=0.8.12;

import {OdysseyERC721} from "../tokens/OdysseyERC721.sol";
import {OdysseyERC1155} from "../tokens/OdysseyERC1155.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";

contract OdysseyTokenFactory {
    /*///////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/
    error OdysseyTokenFactory_TokenAlreadyExists();
    /*///////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event TokenCreated(
        string indexed name,
        string indexed symbol,
        address addr,
        bool isERC721,
        uint256 length
    );

    /*///////////////////////////////////////////////////////////////
                            FACTORY STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(string => mapping(string => address)) public getToken;
    mapping(address => uint256) public tokenExists;
    address[] public allTokens;

    /*///////////////////////////////////////////////////////////////
                            FACTORY LOGIC
    //////////////////////////////////////////////////////////////*/

    function allTokensLength() external view returns (uint256) {
        return allTokens.length;
    }

    function create1155(
        address owner,
        string calldata name,
        string calldata symbol,
        string calldata baseURI
    ) external returns (address token) {
        if (getToken[name][symbol] != address(0)) {
            revert OdysseyTokenFactory_TokenAlreadyExists();
        }
        bytes memory bytecode = type(OdysseyERC1155).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(name, symbol));
        assembly {
            token := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        getToken[name][symbol] = token;
        tokenExists[token] = 1;
        // Run the proper initialize function
        OdysseyERC1155(token).initialize(
            msg.sender,
            owner,
            name,
            symbol,
            string(
                abi.encodePacked(
                    baseURI,
                    Strings.toString(block.chainid),
                    "/",
                    Strings.toHexString(uint160(token)),
                    "/"
                )
            )
        );
        emit TokenCreated(name, symbol, token, false, allTokens.length);
        return token;
    }

    function create721(
        address owner,
        string calldata name,
        string calldata symbol,
        string calldata baseURI
    ) external returns (address token) {
        if (getToken[name][symbol] != address(0)) {
            revert OdysseyTokenFactory_TokenAlreadyExists();
        }
        bytes memory bytecode = type(OdysseyERC721).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(name, symbol));
        assembly {
            token := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        getToken[name][symbol] = token;
        tokenExists[token] = 1;
        // Run the proper initialize function
        OdysseyERC721(token).initialize(
            msg.sender,
            owner,
            name,
            symbol,
            string(
                abi.encodePacked(
                    baseURI,
                    Strings.toString(block.chainid),
                    "/",
                    Strings.toHexString(uint160(token)),
                    "/"
                )
            )
        );
        emit TokenCreated(name, symbol, token, true, allTokens.length);
    }
}
