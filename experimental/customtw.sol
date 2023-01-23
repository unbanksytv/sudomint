// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@thirdweb-dev/contracts/base/ERC721Base.sol";
import "@thirdweb-dev/contracts/base/ERC721SignatureMint.sol";


contract CustomTW is ERC721Base {

      constructor(
        string memory _name,
        string memory _symbol,
        address _royaltyRecipient,
        uint128 _royaltyBps
    )
        ERC721Base(
            _name,
            _symbol,
            _royaltyRecipient,
            _royaltyBps
        )
    {}

    //maximum amount of tokens available for sale, won't be the maximum after airdrops
    // and burning
    uint public constant MAX_TOKENS_FOR_SALE = 1810;

    // Only 3 nfts can be purchased per transaction during public sale.
    uint public constant maxNumPurchase = 3;

    // address of the wallet that will sign transactions for the burning mechanism
    address public constant signerAddress = 0x7d1c1c1Fb80897fa9e08703faedBF8A6A25582f8;

    /**
     * The state of the sale:
     * 0 = closed
     * 1 = presale
     * 2 = public sale
     */
    uint public saleState = 0;
        
    //prices
    uint256 public priceWei = 0.1 ether;

    uint256 public pricePublicWei = 0.125 ether;

    //this variable keeps track of the next tokenID to mint
    uint public numMinted = 0;  

    //helper func to check the payment during early access
    function checkPayment(uint256 numToMint) internal {
        uint256 amountRequired = priceWei * numToMint;
        require(msg.value >= amountRequired, "Not enough funds sent");
    }

    function checkPaymentPublic(uint256 numToMint) internal {
        uint256 amountRequired = pricePublicWei * numToMint;
        require(msg.value >= amountRequired, "Not enough funds sent");
    }
    
    using ECDSA for bytes32;

    function mint(uint num, bytes memory signature) public payable {
        require(saleState > 0, "Sale is not open");

        uint newTotal = num + numMinted;
        require(newTotal <= MAX_TOKENS_FOR_SALE, "Minting would exceed max supply.");

        if (saleState == 1) {

        checkPayment(num);

        bytes32 inputHash = keccak256(
            abi.encodePacked(
            msg.sender,
            num
            )
        );


        bytes32 ethSignedMessageHash = inputHash.toEthSignedMessageHash();
        address recoveredAddress = ethSignedMessageHash.recover(signature);
        require(recoveredAddress == signerAddress, 'Bad signature for eaarly access');
        } else if (saleState == 2 && num > maxNumPurchase) {
        revert("Trying to purchase too many NFTs in one transaction");
        } else {
        checkPaymentPublic(num);
        }

        _mintTo(msg.sender, num);
    }

    function _mintTo(address to, uint num) internal {
    

}