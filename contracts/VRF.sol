// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721RoyaltyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFV2WrapperInterface.sol";

contract Genesis is Initializable, ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721RoyaltyUpgradeable, OwnableUpgradeable, AccessControlUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    /** ENUMs & STRUCTs */
    enum Mouth { Happy, Confused, Sleepy, ExtremelyHappy, Neutral, Yawning, Satisfied, Surprised }
    enum Eyes { Happy, Confused, Sleepy, Closed, HalfAwake, Suspicious, Reflective, Winking }
    enum Pattern { XmasTrees, Leaves, Fishes, Cats, Owls, GeometricShapes, Giraffes, Bears }
    enum Rarity { Common, Uncommon, Rare, Epic, Legendary }
    enum Shape { Square, Circle, Triangle }
    enum Pompom { None, Type1, Type2, Type3 }
    enum Animal { None, Cat, Dog, Bird, Panda, Zebra }

    struct Traits {
        Mouth mouth;
        Eyes eyes;
        Pattern pattern;
        Rarity rarity;
        Shape shape;
        Pompom pompom;
        Animal animal;
    }

    /** CONSTANTS */
    uint256 public constant ROYALTY_FEE_BASE = 10000;
    uint256 public constant ROYALTY_FEE_MAX = 1000;
    uint256 public constant TOTAL_TO_MINT = 330;

    // NFT Logic
    CountersUpgradeable.Counter private _tokenIdCounter;
    string public baseURI;

    // Purchasing
    uint256 public mintPrice;

    // Whitelists
    bool public whitelistOnly;
    EnumerableSetUpgradeable.AddressSet private _whitelisted;

    // Chainlink VRF
    LinkTokenInterface internal LINK;
    VRFV2WrapperInterface internal VRF_V2_WRAPPER;
    uint256 public randomnessRequestId;
    uint256 public randomWord;

    /** INITIALIZATION */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address governor_,
        uint256 mintPrice_,
        address link_,
        address vrfV2Wrapper_
    ) initializer public {
        __ERC721_init("Genesis", "GEN");
        __ERC721Enumerable_init();
        __ERC721Royalty_init();
        __AccessControl_init();
        __Ownable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, governor_);

        baseURI = "https://livethelife.tv/";
        mintPrice = mintPrice_;

        whitelistOnly = true;

        LINK = LinkTokenInterface(link_);
        VRF_V2_WRAPPER = VRFV2WrapperInterface(vrfV2Wrapper_);
    }

    /** PUBLIC / EXTERNAL GETTERS */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721RoyaltyUpgradeable, AccessControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function contractURI() external view returns (string memory) {
        return string(abi.encodePacked(_baseURI(), "contract"));
    }

    function isWhitelisted(address user_) external view returns (bool) {
        return _whitelisted.contains(user_);
    }

    function getTraits(uint256 tokenId_) external view returns (bool available, Traits memory traits) {
        traits = Traits(
            Mouth(0),
            Eyes(0),
            Pattern(0),
            Rarity(0),
            Shape(0),
            Pompom(0),
            Animal(0)
        );

        // If token doesn't exist, or there is no provided randomness, return unavailable traits
        if (!_exists(tokenId_) || randomWord == 0) {
            return (false, traits);
        }

        available = true;

        uint256 probabilityBase = 100;

        /** RARITY */
        // Rarity probability: 60%, 20%, 10%, 7%, 3%
        uint8[5] memory rarityProbability = [0, 60, 80, 90, 97];

        uint256 randomWordByTokenId = uint256(keccak256(abi.encodePacked(randomWord, tokenId_)));

        uint256 rarityRandom = randomWordByTokenId % probabilityBase;
        {
            // Default rarity: Legendary
            uint256 rarityIndex = uint256(Rarity.Legendary);
            // Check rarityRandom against probability and assign rarity index
            for (uint256 i = 0; i < rarityProbability.length - 1; i++) {
                if (rarityProbability[i] <= rarityRandom && rarityRandom < rarityProbability[i + 1]) {
                    rarityIndex = i;
                    break;
                }
            }

            traits.rarity = Rarity(rarityIndex);
        }

        /** MOUTH */
        // Offset random word
        randomWordByTokenId = randomWordByTokenId / probabilityBase;
        probabilityBase = uint8(Mouth.Surprised) + 1;
        {
            uint256 mouthIndex = randomWordByTokenId % probabilityBase;
            traits.mouth = Mouth(mouthIndex);
        }

        /** EYES */
        // Offset random word
        randomWordByTokenId = randomWordByTokenId / probabilityBase;
        probabilityBase = uint8(Eyes.Winking) + 1;
        {
            uint256 eyesIndex = randomWordByTokenId % probabilityBase;
            traits.eyes = Eyes(eyesIndex);
        }

        /** PATTERN */
        // Offset random word
        randomWordByTokenId = randomWordByTokenId / probabilityBase;
        probabilityBase = uint8(Pattern.Bears) + 1;
        {
            uint256 patternIndex = randomWordByTokenId % probabilityBase;
            traits.pattern = Pattern(patternIndex);
        }

        /** SHAPE */
        // Offset random word
        randomWordByTokenId = randomWordByTokenId / probabilityBase;
        probabilityBase = uint8(Shape.Triangle) + 1;
        {
            uint256 shapeIndex = randomWordByTokenId % probabilityBase;
            traits.shape = Shape(shapeIndex);
        }

        /** POMPOM */
        // Offset random word
        randomWordByTokenId = randomWordByTokenId / probabilityBase;
        probabilityBase = uint8(Pompom.Type3);
        if (
            traits.rarity == Rarity.Rare ||
            traits.rarity == Rarity.Epic ||
            traits.rarity == Rarity.Legendary
        ) {
            uint256 pompomIndex = randomWordByTokenId % probabilityBase;
            traits.pompom = Pompom(pompomIndex + 1);
        }

        /** ANIMAL */
        // Offset random word
        randomWordByTokenId = randomWordByTokenId / probabilityBase;
        probabilityBase = uint8(Animal.Zebra);
        if (
            traits.rarity == Rarity.Epic ||
            traits.rarity == Rarity.Legendary
        ) {
            uint256 animalIndex = randomWordByTokenId % probabilityBase;
            traits.animal = Animal(animalIndex + 1);
        }
    }

    /** PUBLIC / EXTERNAL SETTERS */
    function setMintPrice(uint256 mintPrice_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        mintPrice = mintPrice_;
    }

    function setOwner(address newOwner_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newOwner_ != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner_);
    }

    function setBaseURI(string memory baseURI_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseURI = baseURI_;
    }

    function setRoyaltyInfo(address receiver_, uint96 feeNumerator_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setDefaultRoyalty(receiver_, feeNumerator_);
    }

    function setWhitelistOnly(bool whitelistOnly_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        whitelistOnly = whitelistOnly_;
    }

    function addWhitelisted(address[] memory users_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint i = 0; i < users_.length; i++) {
            _whitelisted.add(users_[i]);
        }
    }

    function removeWhitelisted(address[] memory users_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint i = 0; i < users_.length; i++) {
            _whitelisted.remove(users_[i]);
        }
    }

    receive() external payable {}

    function mint(address receiver_, uint256 quantity_) external payable {
        uint256 totalToPay = quantity_ * mintPrice;

        require(totalSupply() + quantity_ <= TOTAL_TO_MINT, "Quantity exceeds allowed");
        require(msg.value >= totalToPay, "Not enough tokens for purchase");
        require(!whitelistOnly || _whitelisted.contains(_msgSender()), "Only whitelisted mint allowed now");

        for (uint256 index = 0; index < quantity_; index++) {
            _tokenIdCounter.increment();
            uint256 tokenId = _tokenIdCounter.current();
            _safeMint(receiver_, tokenId);
        }
    }

    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        payable(_msgSender()).transfer(balance);
    }

    function rescueFunds(address token_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20Upgradeable token = IERC20Upgradeable(token_);
        uint256 balance = token.balanceOf(address(this));
        token.transfer(_msgSender(), balance);
    }

    function requestRandomness() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(randomWord == 0, "Randomness was already persisted");
        uint32 callbackGasLimit = 100000;
        uint16 requestConfirmations = 5;
        uint32 numWords = 1;
        LINK.transferAndCall(
            address(VRF_V2_WRAPPER),
            VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit),
            abi.encode(callbackGasLimit, requestConfirmations, numWords)
        );
        randomnessRequestId = VRF_V2_WRAPPER.lastRequestId();
    }

    function rawFulfillRandomWords(uint256 requestId_, uint256[] memory randomWords_) external {
        require(_msgSender() == address(VRF_V2_WRAPPER), "Only VRF V2 wrapper can fulfill");
        require(requestId_ == randomnessRequestId, "Wrong requestId");
        randomWord = randomWords_[0];
    }

    /** PRIVATE / INTERNAL GETTERS */
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId) internal virtual override(ERC721Upgradeable, ERC721RoyaltyUpgradeable) {
        super._burn(tokenId);
    }
}