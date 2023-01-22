
// -> Cookbook is a free smart contract marketplace. Find, deploy and contribute audited smart contracts.
// -> Follow Cookbook on Twitter: https://twitter.com/cookbook_dev
// -> Join Cookbook on Discord:https://discord.gg/WzsfPcfHrk

// -> Find this contract on Cookbook: https://www.cookbook.dev/contracts/mint-kudos-nft?utm=code



// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./ERC1155NonTransferableBurnableUpgradeable.sol";

contract KudosV7 is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ERC1155NonTransferableBurnableUpgradeable
{
    ////////////////////////////////// CONSTANTS //////////////////////////////////
    /// @notice The name of this contract
    string public constant CONTRACT_NAME = "Kudos";

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 private constant DOMAIN_TYPE_HASH =
        keccak256(
            "EIP712Domain(string name,uint256 chainId,address verifyingContract)"
        );

    /// @notice The EIP-712 typehash for the Kudos input struct used by the contract
    bytes32 public constant KUDOS_TYPE_HASH =
        keccak256(
            "Kudos(string headline,string description,uint256 startDateTimestamp,uint256 endDateTimestamp,string[] links,string communityUniqId,bool isSignatureRequired,bool isAllowlistRequired,int256 totalClaimCount,uint256 expirationTimestamp)"
        );

    /// @notice The EIP-712 typehash for the claiming flow by the contract
    bytes32 public constant CLAIM_TYPE_HASH =
        keccak256("Claim(uint256 tokenId)");

    /// @notice The EIP-712 typehash for adding new allowlisted addresses to an existing Kudos token
    bytes32 public constant ADD_ALLOWLISTED_ADDRESSES_TYPE_HASH =
        keccak256("AllowlistedAddress(uint256 tokenId)");

    /// @notice The EIP-712 typehash for burning
    bytes32 public constant BURN_TYPE_HASH = keccak256("Burn(uint256 tokenId)");

    /// @notice The EIP-712 typehash for the admin to trigger an airdrop
    bytes32 public constant COMMUNITY_ADMIN_AIRDROP_TYPE_HASH =
        keccak256("CommunityAdminAirdrop(uint256 tokenId)");

    /// @notice The EIP-712 typehash for receiver to consent to an admin airdropping the token
    bytes32 public constant COMMUNITY_ADMIN_AIRDROP_RECEIVER_CONSENT_TYPE_HASH =
        keccak256("CommunityAdminAirdropReceiverConsent(uint256 tokenId)");

    ////////////////////////////////// STRUCTS //////////////////////////////////
    /// @dev Struct used to contain the Kudos metadata input
    ///      Also, note that using structs in mappings should be safe:
    ///      https://forum.openzeppelin.com/t/how-to-use-a-struct-in-an-upgradable-contract/832/4
    struct KudosInputContainer {
        string headline;
        string description;
        uint256 startDateTimestamp;
        uint256 endDateTimestamp;
        string[] links;
        string communityUniqId;
        string customAttributes;
        KudosContributorsInputContainer contributorMerkleRoots;
        KudosClaimabilityAttributesInputContainer claimabilityAttributes;
    }

    /// @dev Struct used to contain the full Kudos metadata at the time of mint
    ///      Order of these variables should not be changed
    struct KudosContainer {
        string headline;
        string description;
        uint256 startDateTimestamp;
        uint256 endDateTimestamp;
        string[] links;
        string DEPRECATED_communityDiscordId; // don't use this value anymore
        string DEPRECATED_communityName; // don't use this value anymore
        address creator;
        uint256 registeredTimestamp;
        string communityUniqId;
        KudosClaimabilityAttributesContainer claimabilityAttributes;
        string customAttributes; // stringified JSON value that stores any other custom attributes
    }

    struct KudosClaimabilityAttributesInputContainer {
        bool isSignatureRequired;
        bool isAllowlistRequired;
        int256 totalClaimCount; // -1 indicates infinite
        uint256 expirationTimestamp; // 0 indicates no expiration
    }

    struct KudosClaimabilityAttributesContainer {
        bool isSignatureRequired;
        bool isAllowlistRequired;
        int256 totalClaimCount; // -1 indicates infinite
        uint256 remainingClaimCount; // if totalClaimCount = -1 then irrelevant
        uint256 expirationTimestamp; // 0 indicates no expiration
    }

    /// @dev Struct used to contain string and address Kudos contributors
    struct KudosContributorsInputContainer {
        bytes32 stringContributorsMerkleRoot;
        bytes32 addressContributorsMerkleRoot;
    }

    /// @dev Struct used to contain merkle tree roots of string and address contributors.
    ///      Note that the actual list of contributors is left DEPRECATED in order to not change the
    ///      existing data when upgrading.
    struct KudosContributorsContainer {
        string[] DEPRECATED_stringContributors;
        address[] DEPRECATED_addressContributors;
        bytes32 stringContributorsMerkleRoot;
        bytes32 addressContributorsMerkleRoot;
    }

    /// @dev Struct used by community admins to airdrop Kudos
    struct CommunityAdminAirdropInputContainer {
        address adminAddress;
        uint8 admin_v;
        bytes32 admin_r;
        bytes32 admin_s;
    }

    struct CommunityAdminAirdropConsentInputContainer {
        address receivingAddress;
        uint8 receiver_v;
        bytes32 receiver_r;
        bytes32 receiver_s;
    }

    /// @dev This event is solely so that we can easily track which creator registered
    ///      which Kudos tokens without having to store the mapping on-chain.
    event RegisteredKudos(address creator, uint256 tokenId);

    ////////////////////////////////// VARIABLES //////////////////////////////////
    /// @dev This has been deprecated to allow for mapping tokens to both string and address contributors.
    mapping(uint256 => address[]) public DEPRECATED_tokenIdToContributors;

    mapping(uint256 => KudosContainer) public tokenIdToKudosContainer;

    /// @notice This value signifies the largest tokenId value that has not been used yet.
    /// Whenever we register a new token, we increment this value by one, so essentially the tokenID
    /// signifies the total number of types of tokens registered through this contract.
    uint256 public latestUnusedTokenId;

    /// @notice the address pointing to the community registry
    address public communityRegistryAddress;

    /// @dev Mapping from tokens to string and address Kudos contributors
    mapping(uint256 => KudosContributorsContainer)
        private tokenIdToContributors;

    ////////////////////////////////// CODE //////////////////////////////////
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(uint256 _latestUnusedTokenId) public initializer {
        __ERC1155_init("https://api.mintkudos.xyz/metadata/{id}");
        __Ownable_init();
        __Pausable_init();
        __ERC1155Supply_init();

        // We start with some passed-in latest unused token ID
        if (_latestUnusedTokenId > 0) {
            latestUnusedTokenId = _latestUnusedTokenId;
        } else {
            latestUnusedTokenId = 1;
        }

        // Start off the contract as paused
        _pause();
    }

    /// @notice Allows owner to set new URI that contains token metadata
    /// @param newuri               The Kudos creator's address
    function setURI(string memory newuri) public onlyOwner whenNotPaused {
        _setURI(newuri);
    }

    /// @notice Setting the latest unused token ID value so we can start the next token mint from a different ID.
    /// @param _latestUnusedTokenId  The latest unused token ID that should be set in the contract
    function setLatestUnusedTokenId(uint256 _latestUnusedTokenId)
        public
        onlyOwner
        whenPaused
    {
        latestUnusedTokenId = _latestUnusedTokenId;
    }

    /// @notice Setting the contract address of the community registry
    /// @param _communityRegistryAddress The community registry address
    function setCommunityRegistryAddress(address _communityRegistryAddress)
        public
        onlyOwner
    {
        communityRegistryAddress = _communityRegistryAddress;
    }

    /// @notice Register new Kudos token type for contributors to claim AND airdrop that token to an initial address
    /// @dev Note that because we are using signed messages, if the Kudos input data is not the same as what it was at the time of user signing, the
    ///      function call with fail. This ensures that whatever the user signs is what will get minted, and that we as the admins cannot tamper with
    ///      the content of a Kudos.
    /// @param creator              The Kudos creator's address
    /// @param receiver             The Kudos receiver's address for airdrop
    /// @param metadata             Metadata of the Kudos token
    /// @param v                    Part of the creator's signature (v)
    /// @param r                    Part of the creator's signature (r)
    /// @param s                    Part of the creator's signature (s)
    function registerBySigAndAirdrop(
        address creator,
        address receiver,
        KudosInputContainer memory metadata,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public onlyOwner whenNotPaused {
        uint256 newTokenId = latestUnusedTokenId;
        registerBySig(creator, metadata, v, r, s);
        _claim(newTokenId, receiver);
    }

    /// @notice Register new Kudos token type for contributors to claim.
    /// @dev This just allowlists the tokens that are able to claim this particular token type, but it does not necessarily mint the token until later.
    ///      Note that because we are using signed messages, if the Kudos input data is not the same as what it was at the time of user signing, the
    ///      function call with fail. This ensures that whatever the user signs is what will get minted, and that we as the admins cannot tamper with
    ///      the content of a Kudos.
    /// @param creator              The Kudos creator's address
    /// @param metadata             Metadata of the Kudos token
    /// @param v                    Part of the creator's signature (v)
    /// @param r                    Part of the creator's signature (r)
    /// @param s                    Part of the creator's signature (s)
    function registerBySig(
        address creator,
        KudosInputContainer memory metadata,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public onlyOwner whenNotPaused {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPE_HASH,
                keccak256(bytes(CONTRACT_NAME)),
                block.chainid,
                address(this)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(
                KUDOS_TYPE_HASH,
                keccak256(bytes(metadata.headline)),
                keccak256(bytes(metadata.description)),
                metadata.startDateTimestamp,
                metadata.endDateTimestamp,
                convertStringArraytoByte32(metadata.links),
                keccak256(bytes(metadata.communityUniqId)),
                metadata.claimabilityAttributes.isSignatureRequired,
                metadata.claimabilityAttributes.isAllowlistRequired,
                metadata.claimabilityAttributes.totalClaimCount,
                metadata.claimabilityAttributes.expirationTimestamp
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        address signatory = ecrecover(digest, v, r, s);
        require(signatory == creator, "invalid signature");

        _register(signatory, metadata);
    }

    function _register(address creator, KudosInputContainer memory metadata)
        internal
    {
        // Note that we currently don't have an easy way to de-duplicate Kudos tokens.
        // Because we are the only ones that can mint Kudos for now (since we're covering the cost),
        // we will gate duplicated tokens in the caller side.
        // However, once we open this up to the public (if the public wants to pay for their own Kudos at some point),
        // we may need to come up with some validation routine here to prevent the "same" Kudos from being minted.

        // Translate the Kudos input container to the actual container
        require(
            ICommunityRegistry(communityRegistryAddress).doesCommunityExist(
                metadata.communityUniqId
            ),
            "uniqId does not exist in registry"
        );

        KudosContainer memory kc;
        kc.creator = creator;
        kc.headline = metadata.headline;
        kc.description = metadata.description;
        kc.startDateTimestamp = metadata.startDateTimestamp;
        kc.endDateTimestamp = metadata.endDateTimestamp;
        kc.links = metadata.links;
        kc.communityUniqId = metadata.communityUniqId;
        kc.customAttributes = metadata.customAttributes;
        kc.registeredTimestamp = block.timestamp;

        kc.claimabilityAttributes.isSignatureRequired = metadata
            .claimabilityAttributes
            .isSignatureRequired;
        kc.claimabilityAttributes.isAllowlistRequired = metadata
            .claimabilityAttributes
            .isAllowlistRequired;

        // Register the contributor merkle roots for the allowlist
        // This is used later in the claim flow to see if an address can actually claim the token or not.
        if (kc.claimabilityAttributes.isAllowlistRequired) {
            tokenIdToContributors[latestUnusedTokenId]
                .addressContributorsMerkleRoot = metadata
                .contributorMerkleRoots
                .addressContributorsMerkleRoot;
            tokenIdToContributors[latestUnusedTokenId]
                .stringContributorsMerkleRoot = metadata
                .contributorMerkleRoots
                .stringContributorsMerkleRoot;

            require(
                metadata.claimabilityAttributes.totalClaimCount == 0,
                "Total claim count should not be set if allowlist is required"
            );
        }

        kc.claimabilityAttributes.totalClaimCount = metadata
            .claimabilityAttributes
            .totalClaimCount;
        if (kc.claimabilityAttributes.totalClaimCount > 0) {
            kc.claimabilityAttributes.remainingClaimCount = uint256(
                kc.claimabilityAttributes.totalClaimCount
            );
        }
        kc.claimabilityAttributes.expirationTimestamp = metadata
            .claimabilityAttributes
            .expirationTimestamp;

        // Store the metadata into a mapping for viewing later
        tokenIdToKudosContainer[latestUnusedTokenId] = kc;

        emit RegisteredKudos(creator, latestUnusedTokenId);

        // increment the latest unused TokenId because we now have an additionally registered
        // token.
        latestUnusedTokenId++;
    }

    /// @notice Only for community admins - Mints a Kudos to any consenting address
    /// @dev    It's important to note here that this endpoint is potentially vulnerable --
    ///         because the admin signature's content is only the token ID, one can look on-chain
    ///         and obtain the admin signature for a particular token, and then call this endpoint
    ///         with their own "consenting" signature to maliciously obtain a token.
    ///         This is only the case if the function is open to anyone and not locked down by role,
    ///         so for the time being we don't need to worry about it. However, it's worth noting
    ///         as we make the contract more accessible outside of going through our API.
    /// @param id                                Token ID
    /// @param adminInput                        Container with the admin's consent info
    /// @param consentInput                      Container with the receiver's consent info
    /// @param updateContributorMerkleRoots      Flag to determine whether we should update the contributor merkle roots
    /// @param contributorMerkleRoots            New contributor merkle roots
    /// @param merkleProof                       Merkle proof for the particular claiming address
    function communityAdminAirdrop(
        uint256 id,
        CommunityAdminAirdropInputContainer memory adminInput,
        CommunityAdminAirdropConsentInputContainer memory consentInput,
        bool updateContributorMerkleRoots,
        KudosContributorsInputContainer memory contributorMerkleRoots,
        bytes32[] calldata merkleProof
    ) public onlyOwner whenNotPaused {
        _validateCommunityAdminAirdropAdminSig(
            id,
            adminInput.adminAddress,
            adminInput.admin_v,
            adminInput.admin_r,
            adminInput.admin_s
        );

        _validateCommunityAdminAirdropReceiverSig(
            id,
            consentInput.receivingAddress,
            consentInput.receiver_v,
            consentInput.receiver_r,
            consentInput.receiver_s
        );

        _claimCommunityAdminAirdrop(
            id,
            consentInput.receivingAddress,
            updateContributorMerkleRoots,
            contributorMerkleRoots,
            merkleProof
        );
    }

    /// @notice Only for community admins - Mints a Kudos to ANY address
    /// @dev    All the concerns of the above communityAdminAirdrop function apply, with
    ///         the additional issue that this function does not require a signature from
    ///         the recipient address - community admins can use this function to mint a
    ///         Kudos to ANY address. This is intended for special cases where the regular
    ///         communityAdminAirdrop function won't work - migrations, situations where
    ///         the end user can't/won't collect consent signatures for recipients, etc.
    /// @param id                                Token ID
    /// @param adminInput                        Container with the admin's consent info
    /// @param receivingAddress                  Address to mint the Kudos to
    /// @param updateContributorMerkleRoots      Flag to determine whether we should update the contributor merkle roots
    /// @param contributorMerkleRoots            New contributor merkle roots
    /// @param merkleProof                       Merkle proof for the particular claiming address
    function communityAdminAirdropWithoutConsentSig(
        uint256 id,
        CommunityAdminAirdropInputContainer memory adminInput,
        address receivingAddress,
        bool updateContributorMerkleRoots,
        KudosContributorsInputContainer memory contributorMerkleRoots,
        bytes32[] calldata merkleProof
    ) public onlyOwner whenNotPaused {
        _validateCommunityAdminAirdropAdminSig(
            id,
            adminInput.adminAddress,
            adminInput.admin_v,
            adminInput.admin_r,
            adminInput.admin_s
        );

        _claimCommunityAdminAirdrop(
            id,
            receivingAddress,
            updateContributorMerkleRoots,
            contributorMerkleRoots,
            merkleProof
        );
    }

    /// @notice Burns ALL of an assigned token for the specified address
    /// @param id                  ID of the Token
    /// @param burningAddress      Burning address
    /// @param v                   Part of the burnee's signature (v)
    /// @param r                   Part of the burnee's signature (r)
    /// @param s                   Part of the burnee's signature (s)
    function burn(
        uint256 id,
        address burningAddress,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public onlyOwner whenNotPaused {
        uint256 balance;
        balance = balanceOf(burningAddress, id);

        require(
            tokenIdToKudosContainer[id].creator != address(0),
            "token does not exist"
        );
        require(balance > 0, "cannot burn unowned token");

        bytes32 burnHash = keccak256(abi.encode(BURN_TYPE_HASH, id));
        _validateSignature(burnHash, burningAddress, v, r, s);

        _burn(burningAddress, id, balance);
    }

    /// @notice Mints a token for the specified address if allowlisted
    /// @param id                  ID of the Token
    /// @param claimingAddress     Claiming address
    /// @param v                   Part of the claimee's signature (v)
    /// @param r                   Part of the claimee's signature (r)
    /// @param s                   Part of the claimee's signature (s)
    /// @param merkleProof         Merkle proof for the particular claiming address
    function claim(
        uint256 id,
        address claimingAddress,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bytes32[] calldata merkleProof
    ) public onlyOwner whenNotPaused {
        _validateClaimability(id, claimingAddress, v, r, s);

        if (
            tokenIdToKudosContainer[id]
                .claimabilityAttributes
                .isAllowlistRequired
        ) {
            require(
                MerkleProofUpgradeable.verify(
                    merkleProof,
                    tokenIdToContributors[id].addressContributorsMerkleRoot,
                    generateAddressMerkleLeaf(claimingAddress)
                ),
                "address not allowlisted"
            );
        }

        _claim(id, claimingAddress);
    }

    /// @notice Mints a token for the specified address if allowlisted without signature
    ///         verification that the string contributor is owned by the claimee address.
    ///         The integrity will be checked off-chain.
    /// @param id                  ID of the Token
    /// @param claimingAddress     Claiming address
    /// @param v                   Part of the claimee's signature (v)
    /// @param r                   Part of the claimee's signature (r)
    /// @param s                   Part of the claimee's signature (s)
    /// @param contributor         String ID of the contributor that should claim this token
    /// @param merkleProof         Merkle proof for the particular claiming address
    function unsafeClaim(
        uint256 id,
        address claimingAddress,
        uint8 v,
        bytes32 r,
        bytes32 s,
        string memory contributor,
        bytes32[] calldata merkleProof
    ) public onlyOwner whenNotPaused {
        _validateClaimability(id, claimingAddress, v, r, s);

        if (
            tokenIdToKudosContainer[id]
                .claimabilityAttributes
                .isAllowlistRequired
        ) {
            require(
                MerkleProofUpgradeable.verify(
                    merkleProof,
                    tokenIdToContributors[id].stringContributorsMerkleRoot,
                    generateStringMerkleLeaf(contributor)
                ),
                "contributor not allowlisted"
            );
        }

        _claim(id, claimingAddress);
    }

    function _claim(uint256 id, address dst) internal {
        // Address dst should not already have the token
        require(balanceOf(dst, id) == 0, "address should not own token");

        // If everything is allowed, then mint the token for dst
        _mint(dst, id, 1, "");

        // Decrement counter if necessary
        bool hasFiniteCount = tokenIdToKudosContainer[id]
            .claimabilityAttributes
            .totalClaimCount > 0;
        if (hasFiniteCount) {
            tokenIdToKudosContainer[id]
                .claimabilityAttributes
                .remainingClaimCount--;
        }
    }

    function _validateCommunityAdminAirdropAdminSig(
        uint256 id,
        address adminAddress,
        uint8 admin_v,
        bytes32 admin_r,
        bytes32 admin_s
    ) internal view {
        _tokenClaimChecks(id);

        // verify admin address & signature
        string memory communityUniqId = tokenIdToKudosContainer[id]
            .communityUniqId;
        uint256 adminIndex = ICommunityRegistry(communityRegistryAddress)
            .communityIdToAdminOneIndexIndices(communityUniqId, adminAddress);
        require(adminIndex != 0, "not admin of community");

        bytes32 communityAdminAirdropHash = keccak256(
            abi.encode(COMMUNITY_ADMIN_AIRDROP_TYPE_HASH, id)
        );
        _validateSignature(
            communityAdminAirdropHash,
            adminAddress,
            admin_v,
            admin_r,
            admin_s,
            "invalid admin airdrop signature"
        );
    }

    function _validateCommunityAdminAirdropReceiverSig(
        uint256 id,
        address receivingAddress,
        uint8 receiver_v,
        bytes32 receiver_r,
        bytes32 receiver_s
    ) internal view {
        bytes32 communityAdminAirdropReceiverConsentHash = keccak256(
            abi.encode(COMMUNITY_ADMIN_AIRDROP_RECEIVER_CONSENT_TYPE_HASH, id)
        );
        _validateSignature(
            communityAdminAirdropReceiverConsentHash,
            receivingAddress,
            receiver_v,
            receiver_r,
            receiver_s,
            "invalid admin airdrop receiver consent signature"
        );
    }

    function _claimCommunityAdminAirdrop(
        uint256 id,
        address receivingAddress,
        bool updateContributorMerkleRoots,
        KudosContributorsInputContainer memory contributorMerkleRoots,
        bytes32[] calldata merkleProof
    ) internal {
        if (
            tokenIdToKudosContainer[id]
                .claimabilityAttributes
                .isAllowlistRequired
        ) {
            if (updateContributorMerkleRoots) {
                _addAllowlistedContributorRoots(id, contributorMerkleRoots);
            }

            require(
                MerkleProofUpgradeable.verify(
                    merkleProof,
                    tokenIdToContributors[id].addressContributorsMerkleRoot,
                    generateAddressMerkleLeaf(receivingAddress)
                ),
                "address not allowlisted"
            );
        }

        _claim(id, receivingAddress);
    }

    function _tokenClaimChecks(uint256 id) internal view {
        require(
            tokenIdToKudosContainer[id].creator != address(0),
            "token does not exist"
        );

        bool hasExpirationSet = tokenIdToKudosContainer[id]
            .claimabilityAttributes
            .expirationTimestamp != 0;
        require(
            !hasExpirationSet ||
                (hasExpirationSet &&
                    tokenIdToKudosContainer[id]
                        .claimabilityAttributes
                        .expirationTimestamp >
                    block.timestamp),
            "token claim expired"
        );

        // if not allowlist flow, then check to make sure there are enough tokens to claim
        bool isAllowlistRequired = tokenIdToKudosContainer[id]
            .claimabilityAttributes
            .isAllowlistRequired;
        bool hasClaimCountLimit = tokenIdToKudosContainer[id]
            .claimabilityAttributes
            .totalClaimCount >= 0;
        uint256 remainingCount = tokenIdToKudosContainer[id]
            .claimabilityAttributes
            .remainingClaimCount;
        require(
            isAllowlistRequired ||
                (!isAllowlistRequired &&
                    (!hasClaimCountLimit ||
                        (hasClaimCountLimit && remainingCount > 0))),
            "no more tokens"
        );
    }

    function _validateClaimability(
        uint256 id,
        address claimee,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view {
        _tokenClaimChecks(id);

        if (
            tokenIdToKudosContainer[id]
                .claimabilityAttributes
                .isSignatureRequired
        ) {
            bytes32 claimHash = keccak256(abi.encode(CLAIM_TYPE_HASH, id));
            _validateSignature(claimHash, claimee, v, r, s);
        }
    }

    /// @dev The signature validation logic is always the same - we hash together the domainSeparator
    ///      and the encodeType & encodeData, all according to EIP-712. The only thing that changes per
    ///      signature type is the encodeType & encodeData.
    ///      This function takes in the encoded & hashed encodeType & encodeData, and verifies whether the
    ///      supposed signer actually signed the content of the signature.
    /// @param signatureContentHash          Hashed value of the signature's content
    /// @param signer                        Supposed signer of the signature
    /// @param v                             Part of the provided signature (v)
    /// @param r                             Part of the provided signature (r)
    /// @param s                             Part of the provided signature (s)
    function _validateSignature(
        bytes32 signatureContentHash,
        address signer,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view {
        _validateSignature(
            signatureContentHash,
            signer,
            v,
            r,
            s,
            "invalid signature"
        );
    }

    /// @dev The signature validation logic is always the same - we hash together the domainSeparator
    ///      and the encodeType & encodeData, all according to EIP-712. The only thing that changes per
    ///      signature type is the encodeType & encodeData.
    ///      This function takes in the encoded & hashed encodeType & encodeData, and verifies whether the
    ///      supposed signer actually signed the content of the signature.
    /// @param signatureContentHash          Hashed value of the signature's content
    /// @param signer                        Supposed signer of the signature
    /// @param v                             Part of the provided signature (v)
    /// @param r                             Part of the provided signature (r)
    /// @param s                             Part of the provided signature (s)
    function _validateSignature(
        bytes32 signatureContentHash,
        address signer,
        uint8 v,
        bytes32 r,
        bytes32 s,
        string memory errorMsg
    ) internal view {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPE_HASH,
                keccak256(bytes(CONTRACT_NAME)),
                block.chainid,
                address(this)
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, signatureContentHash)
        );
        address recoveredSigner = ecrecover(digest, v, r, s);
        require(signer == recoveredSigner, errorMsg);
    }

    function modifyKudosClaimAttributes(
        uint256 id,
        int256 totalClaimCount, // -1 indicates infinite
        uint256 expirationTimestamp, // 0 indicates no expiration
        bool isSignatureRequired,
        bool isAllowlistRequired
    ) public onlyOwner whenNotPaused {
        require(
            tokenIdToKudosContainer[id].creator != address(0),
            "token does not exist"
        );

        int256 diff;
        if (
            tokenIdToKudosContainer[id]
                .claimabilityAttributes
                .totalClaimCount == -1
        ) {
            // when it was infinite claim before, we impose a fresh new limit
            diff = totalClaimCount;
        } else {
            // otherwise we decrease the remaining claim count
            diff =
                totalClaimCount -
                tokenIdToKudosContainer[id]
                    .claimabilityAttributes
                    .totalClaimCount;
        }
        if (
            diff < 0 &&
            int256(
                tokenIdToKudosContainer[id]
                    .claimabilityAttributes
                    .remainingClaimCount
            ) <
            -diff
        ) {
            tokenIdToKudosContainer[id]
                .claimabilityAttributes
                .remainingClaimCount = 0;
        } else {
            tokenIdToKudosContainer[id]
                .claimabilityAttributes
                .remainingClaimCount = uint256(
                int256(
                    tokenIdToKudosContainer[id]
                        .claimabilityAttributes
                        .remainingClaimCount
                ) + diff
            );
        }

        tokenIdToKudosContainer[id]
            .claimabilityAttributes
            .totalClaimCount = totalClaimCount;
        tokenIdToKudosContainer[id]
            .claimabilityAttributes
            .expirationTimestamp = expirationTimestamp;
        tokenIdToKudosContainer[id]
            .claimabilityAttributes
            .isSignatureRequired = isSignatureRequired;
        tokenIdToKudosContainer[id]
            .claimabilityAttributes
            .isAllowlistRequired = isAllowlistRequired;
    }

    /// @notice Adds allowlisted addresses to an existing Kudos token. Note that this function is actually
    ///         unsafe in that there is no signature verification. We must trust the owner of the contract
    ///         to correctly verify off-chain that the operation is valid. This is added as a way for the team
    ///         to enable API integrations where partners want to add contributors to an existing Kudos token
    ///         programmatically.
    /// @param id                            ID of the Token
    /// @param allowlistedContributorRoots   Merkle roots of allowlisted contributors
    /// @param v                             Part of the creator's signature (v)
    /// @param r                             Part of the creator's signature (r)
    /// @param s                             Part of the creator's signature (s)
    function addAllowlistedAddressesBySig(
        uint256 id,
        KudosContributorsInputContainer memory allowlistedContributorRoots,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public onlyOwner whenNotPaused {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPE_HASH,
                keccak256(bytes(CONTRACT_NAME)),
                block.chainid,
                address(this)
            )
        );
        // Note: not verifying the content of allowlisted addresses for now
        bytes32 addAllowlistedAddressesHash = keccak256(
            abi.encode(ADD_ALLOWLISTED_ADDRESSES_TYPE_HASH, id)
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                addAllowlistedAddressesHash
            )
        );
        address signatory = ecrecover(digest, v, r, s);

        // Check if token created by this creator
        require(
            tokenIdToKudosContainer[id].creator == signatory,
            "only creator can add allowlisted addresses"
        );

        _addAllowlistedContributorRoots(id, allowlistedContributorRoots);
    }

    /// @notice Adds allowlisted addresses to an existing Kudos token. Note that this function is actually
    ///         unsafe in that there is no signature verification. We must trust the owner of the contract
    ///         to correctly verify off-chain that the operation is valid. This is added as a way for the team
    ///         to enable API integrations where partners want to add contributors to an existing Kudos token
    ///         programmatically.
    ///
    ///         In the future, we expect to push partners to use the addAllowlistedAddressesBySig function so at least
    ///         we can validate to a degree that the operation is at least user-signed.
    /// @param id                            ID of the Token
    /// @param allowlistedContributorRoots   Merkle roots of allowlisted contributors
    function unsafeAddAllowlistedContributors(
        uint256 id,
        KudosContributorsInputContainer memory allowlistedContributorRoots
    ) public onlyOwner whenNotPaused {
        require(
            tokenIdToKudosContainer[id].creator != address(0),
            "token should already exist"
        );

        _addAllowlistedContributorRoots(id, allowlistedContributorRoots);
    }

    function _addAllowlistedContributorRoots(
        uint256 id,
        KudosContributorsInputContainer memory newAllowlistedContributorRoots
    ) internal {
        tokenIdToContributors[id]
            .addressContributorsMerkleRoot = newAllowlistedContributorRoots
            .addressContributorsMerkleRoot;
        tokenIdToContributors[id]
            .stringContributorsMerkleRoot = newAllowlistedContributorRoots
            .stringContributorsMerkleRoot;
    }

    /// @notice We add a temporary backdoor function to update the contents of the toeknIdToContributors map.
    ///         Previously, we were storing the raw contributor list, but because this is extremely inefficient,
    ///         we only want to store the merkle roots instead. This backdoor function allows us to update the
    ///         existing Kudos tokens' contributor data.
    /// @param id                            ID of the Token
    /// @param allowlistedContributorRoots   Merkle roots of allowlisted contributors
    function backdoorUpdateContributors(
        uint256 id,
        KudosContributorsInputContainer memory allowlistedContributorRoots
    ) public onlyOwner whenPaused {
        require(
            tokenIdToKudosContainer[id].creator != address(0),
            "token should already exist"
        );

        // clear allowlist to free up space
        delete tokenIdToContributors[id];

        tokenIdToContributors[id]
            .addressContributorsMerkleRoot = allowlistedContributorRoots
            .addressContributorsMerkleRoot;
        tokenIdToContributors[id]
            .stringContributorsMerkleRoot = allowlistedContributorRoots
            .stringContributorsMerkleRoot;
    }

    /// @notice Returns the allowlisted contributors as an array.
    /// @dev The solidity compiler automatically returns the getter for mappings with arrays
    ///      as map(key, idx), which prevents us from getting the entire array back for a given key.
    /// @param tokenId     ID of the token
    function getAllowlistedContributors(uint256 tokenId)
        public
        view
        returns (KudosContributorsContainer memory)
    {
        return tokenIdToContributors[tokenId];
    }

    /// @notice Returns the Kudos metadata for a given token ID
    /// @dev Getters generated by the compiler for a public storage variable
    ///      silently skips mappings and arrays inside structs.
    //       This is why we need our own getter function to return the entirety of the struct.
    ///      https://ethereum.stackexchange.com/questions/107027/how-to-return-an-array-of-structs-that-has-mappings-nested-within-them/107124
    /// @param tokenId     ID of the token
    function getKudosMetadata(uint256 tokenId)
        public
        view
        returns (KudosContainer memory)
    {
        return tokenIdToKudosContainer[tokenId];
    }

    /// @notice Owner can pause the contract
    function pause() public onlyOwner {
        _pause();
    }

    /// @notice Owner can unpause the contract
    function unpause() public onlyOwner {
        _unpause();
    }

    /// @dev A way to convert an array of strings into a hashed byte32 value.
    ///      We append using encodePacked, which is the equivalent of hexlifying each
    ///      hashed string and concatenating them.
    function convertStringArraytoByte32(string[] memory inputArray)
        internal
        pure
        returns (bytes32)
    {
        bytes memory packedBytes;
        for (uint256 i = 0; i < inputArray.length; i++) {
            packedBytes = abi.encodePacked(
                packedBytes,
                keccak256(bytes(inputArray[i]))
            );
        }
        return keccak256(packedBytes);
    }

    function compareStringsbyBytes(string memory s1, string memory s2)
        private
        pure
        returns (bool)
    {
        return
            keccak256(abi.encodePacked(s1)) == keccak256(abi.encodePacked(s2));
    }

    function generateAddressMerkleLeaf(address account)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(account));
    }

    function generateStringMerkleLeaf(string memory account)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(account));
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";


interface ICommunityRegistry {
    function doesCommunityExist(string memory uniqId)
        external
        view
        returns (bool);

    function communityIdToAdminOneIndexIndices(
        string memory uniqId,
        address admin
    ) external view returns (uint256);
}

contract ERC1155NonTransferableBurnableUpgradeable is
    ERC1155Upgradeable,
    ERC1155SupplyUpgradeable
{
    /// @dev Override of the token transfer hook that blocks all transfers BUT mints and burns.
    ///        This is a precursor to non-transferable tokens.
    ///        We may adopt something like ERC1238 in the future.
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155Upgradeable, ERC1155SupplyUpgradeable) {
        require(
            (from == address(0) || to == address(0)),
            "Only mint and burn transfers are allowed"
        );
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
