
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @notice Thrown when completing the transaction results in overallocation of Pixelmon.
error MintedOut();
/// @notice Thrown when the dutch auction phase has not yet started, or has already ended.
error AuctionNotStarted();
/// @notice Thrown when the user has already minted two Pixelmon in the dutch auction.
error MintingTooMany();
/// @notice Thrown when the value of the transaction is not enough for the current dutch auction or mintlist price.
error ValueTooLow();
/// @notice Thrown when the user is not on the mintlist.
error NotMintlisted();
/// @notice Thrown when the caller is not the EvolutionSerum contract, and is trying to evolve a Pixelmon.
error UnauthorizedEvolution();
/// @notice Thrown when an invalid evolution is given by the EvolutionSerum contract.
error UnknownEvolution();


//  ______   __     __  __     ______     __         __    __     ______     __   __    
// /\  == \ /\ \   /\_\_\_\   /\  ___\   /\ \       /\ "-./  \   /\  __ \   /\ "-.\ \   
// \ \  _-/ \ \ \  \/_/\_\/_  \ \  __\   \ \ \____  \ \ \-./\ \  \ \ \/\ \  \ \ \-.  \  
//  \ \_\    \ \_\   /\_\/\_\  \ \_____\  \ \_____\  \ \_\ \ \_\  \ \_____\  \ \_\\"\_\ 
//   \/_/     \/_/   \/_/\/_/   \/_____/   \/_____/   \/_/  \/_/   \/_____/   \/_/ \/_/ 
//
/// @title Generation 1 Pixelmon NFTs
/// @author delta devs (https://www.twitter.com/deltadevelopers)
contract Pixelmon is ERC721, Ownable {
    using Strings for uint256;

    /*///////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Determines the order of the species for each tokenId, mechanism for choosing starting index explained post mint, explanation hash: acb427e920bde46de95103f14b8e57798a603abcf87ff9d4163e5f61c6a56881.
    uint constant public provenanceHash = 0x9912e067bd3802c3b007ce40b6c125160d2ccb5352d199e20c092fdc17af8057;

    /// @dev Sole receiver of collected contract funds, and receiver of 330 Pixelmon in the constructor.
    address constant gnosisSafeAddress = 0xF6BD9Fc094F7aB74a846E5d82a822540EE6c6971;

    /// @dev 7750, plus 330 for the Pixelmon Gnosis Safe
    uint constant auctionSupply = 7750 + 330;

    /// @dev The offsets are the tokenIds that the corresponding evolution stage will begin minting at.
    uint constant secondEvolutionOffset = 10005;
    uint constant thirdEvolutionOffset = secondEvolutionOffset + 4013;
    uint constant fourthEvolutionOffset = thirdEvolutionOffset + 1206;

    /*///////////////////////////////////////////////////////////////
                        EVOLUTIONARY STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev The next tokenID to be minted for each of the evolution stages
    uint secondEvolutionSupply = 0;
    uint thirdEvolutionSupply = 0;
    uint fourthEvolutionSupply = 0;

    /// @notice The address of the contract permitted to mint evolved Pixelmon.
    address public serumContract;

    /// @notice Returns true if the user is on the mintlist, if they have not already minted.
    mapping(address => bool) public mintlisted;

    /*///////////////////////////////////////////////////////////////
                            AUCTION STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Starting price of the auction.
    uint256 constant public auctionStartPrice = 3 ether;

    /// @notice Unix Timestamp of the start of the auction.
    /// @dev Monday, February 7th 2022, 13:00:00 converted to 1644256800 (GMT -5)
    uint256 constant public auctionStartTime = 1644256800;

    /// @notice Current mintlist price, which will be updated after the end of the auction phase.
    /// @dev We started with signatures, then merkle tree, but landed on mapping to reduce USER gas fees.
    uint256 public mintlistPrice = 0.75 ether;

    /*///////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public baseURI;

    /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys the contract, minting 330 Pixelmon to the Gnosis Safe and setting the initial metadata URI.
    constructor(string memory _baseURI) ERC721("Pixelmon", "PXLMN") {
        baseURI = _baseURI;
        unchecked {
            balanceOf[gnosisSafeAddress] += 330;
            totalSupply += 330;
            for (uint256 i = 0; i < 330; i++) {
                ownerOf[i] = gnosisSafeAddress;
                emit Transfer(address(0), gnosisSafeAddress, i);
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                            METADATA LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Allows the contract deployer to set the metadata URI.
    /// @param _baseURI The new metadata URI.
    function setBaseURI(string memory _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, id.toString()));
    }

    /*///////////////////////////////////////////////////////////////
                        DUTCH AUCTION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculates the auction price with the accumulated rate deduction since the auction's begin
    /// @return The auction price at the current time, or 0 if the deductions are greater than the auction's start price.
    function validCalculatedTokenPrice() private view returns (uint) {
        uint priceReduction = ((block.timestamp - auctionStartTime) / 10 minutes) * 0.1 ether;
        return auctionStartPrice >= priceReduction ? (auctionStartPrice - priceReduction) : 0;
    }

    /// @notice Calculates the current dutch auction price, given accumulated rate deductions and a minimum price.
    /// @return The current dutch auction price
    function getCurrentTokenPrice() public view returns (uint256) {
        return max(validCalculatedTokenPrice(), 0.2 ether);
    }

    /// @notice Purchases a Pixelmon NFT in the dutch auction
    /// @param mintingTwo True if the user is minting two Pixelmon, otherwise false.
    /// @dev balanceOf is fine, team is aware and accepts that transferring out and repurchasing can be done, even by contracts. 
    function auction(bool mintingTwo) public payable {
        if(block.timestamp < auctionStartTime || block.timestamp > auctionStartTime + 1 days) revert AuctionNotStarted();

        uint count = mintingTwo ? 2 : 1;
        uint price = getCurrentTokenPrice();

        if(totalSupply + count > auctionSupply) revert MintedOut();
        if(balanceOf[msg.sender] + count > 2) revert MintingTooMany();
        if(msg.value < price * count) revert ValueTooLow();

        mintingTwo ? _mintTwo(msg.sender) : _mint(msg.sender, totalSupply);
    }
    
    /// @notice Mints two Pixelmons to an address
    /// @param to Receiver of the two newly minted NFTs
    /// @dev errors taken from super._mint
    function _mintTwo(address to) internal {
        require(to != address(0), "INVALID_RECIPIENT");
        require(ownerOf[totalSupply] == address(0), "ALREADY_MINTED");
        uint currentId = totalSupply;

        /// @dev unchecked because no arithmetic can overflow
        unchecked {
            totalSupply += 2;
            balanceOf[to] += 2;
            ownerOf[currentId] = to;
            ownerOf[currentId + 1] = to;
            emit Transfer(address(0), to, currentId);
            emit Transfer(address(0), to, currentId + 1);
        }
    }


    /*///////////////////////////////////////////////////////////////
                        MINTLIST MINT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Allows the contract deployer to set the price of the mintlist. To be called before uploading the mintlist.
    /// @param price The price in wei of a Pixelmon NFT to be purchased from the mintlist supply.
    function setMintlistPrice(uint256 price) public onlyOwner {
        mintlistPrice = price;
    }

    /// @notice Allows the contract deployer to add a single address to the mintlist.
    /// @param user Address to be added to the mintlist.
    function mintlistUser(address user) public onlyOwner {
        mintlisted[user] = true;
    }

    /// @notice Allows the contract deployer to add a list of addresses to the mintlist.
    /// @param users Addresses to be added to the mintlist.
    function mintlistUsers(address[] calldata users) public onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
           mintlisted[users[i]] = true; 
        }
    }

    /// @notice Purchases a Pixelmon NFT from the mintlist supply
    /// @dev We do not check if auction is over because the mintlist will be uploaded after the auction. 
    function mintlistMint() public payable {
        if(totalSupply >= secondEvolutionOffset) revert MintedOut();
        if(!mintlisted[msg.sender]) revert NotMintlisted();
        if(msg.value < mintlistPrice) revert ValueTooLow();

        mintlisted[msg.sender] = false;
        _mint(msg.sender, totalSupply);
    }

    /// @notice Withdraws collected funds to the Gnosis Safe address
    function withdraw() public onlyOwner {
        (bool success, ) = gnosisSafeAddress.call{value: address(this).balance}("");
        require(success);
    }

    /*///////////////////////////////////////////////////////////////
                            ROLL OVER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Allows the contract deployer to airdrop Pixelmon to a list of addresses, in case the auction doesn't mint out
    /// @param addresses Array of addresses to receive Pixelmon
    function rollOverPixelmons(address[] calldata addresses) public onlyOwner {
        if(totalSupply + addresses.length > secondEvolutionOffset) revert MintedOut();

        for (uint256 i = 0; i < addresses.length; i++) {
            _mint(msg.sender, totalSupply);
        }
    }

    /*///////////////////////////////////////////////////////////////
                        EVOLUTIONARY LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the address of the contract permitted to call mintEvolvedPixelmon
    /// @param _serumContract The address of the EvolutionSerum contract
    function setSerumContract(address _serumContract) public onlyOwner {
        serumContract = _serumContract; 
    }

    /// @notice Mints an evolved Pixelmon
    /// @param receiver Receiver of the evolved Pixelmon
    /// @param evolutionStage The evolution (2-4) that the Pixelmon is undergoing
    function mintEvolvedPixelmon(address receiver, uint evolutionStage) public payable {
        if(msg.sender != serumContract) revert UnauthorizedEvolution();

        if (evolutionStage == 2) {
            if(secondEvolutionSupply >= 4013) revert MintedOut();
            _mint(receiver, secondEvolutionOffset + secondEvolutionSupply);
            unchecked {
                secondEvolutionSupply++;
            }
        } else if (evolutionStage == 3) {
            if(thirdEvolutionSupply >= 1206) revert MintedOut();
            _mint(receiver, thirdEvolutionOffset + thirdEvolutionSupply);
            unchecked {
                thirdEvolutionSupply++;
            }
        } else if (evolutionStage == 4) {
            if(fourthEvolutionSupply >= 33) revert MintedOut();
            _mint(receiver, fourthEvolutionOffset + fourthEvolutionSupply);
            unchecked {
                fourthEvolutionSupply++;
            }
        } else  {
            revert UnknownEvolution();
        }
    }


    /*///////////////////////////////////////////////////////////////
                                UTILS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the greater of two numbers.
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

}
// File @openzeppelin/contracts/token/ERC721/ERC721.sol@v4.3.0

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract Pixelmons is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(operator != _msgSender(), "ERC721: approve to caller");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is whiteed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}
// File @openzeppelin/contracts/access/Ownable.sol@v4.3.0

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}