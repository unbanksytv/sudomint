// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.12;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "./utils/FixedPointMathLib.sol";
import {OdysseyXpDirectory} from "./OdysseyXpDirectory.sol";

error OdysseyXp_Unauthorized();
error OdysseyXp_NonTransferable();
error OdysseyXp_ZeroAssets();

contract OdysseyXp is ERC20 {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    struct UserHistory {
        uint256 balanceAtLastRedeem;
        uint256 globallyWithdrawnAtLastRedeem;
    }

    /*///////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Mint(address indexed owner, uint256 assets, uint256 xp);

    event Redeem(address indexed owner, uint256 assets, uint256 xp);

    /*///////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public router;
    address public exchange;
    address public owner;
    uint256 public globallyWithdrawn;
    ERC20 public immutable asset;
    OdysseyXpDirectory public directory;
    mapping(address => UserHistory) public userHistories;

    constructor(
        ERC20 _asset,
        OdysseyXpDirectory _directory,
        address _router,
        address _exchange,
        address _owner
    ) ERC20("Odyssey XP", "XP", 0) {
        asset = _asset;
        directory = _directory;
        router = _router;
        exchange = _exchange;
        owner = _owner;
    }

    /*///////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    function notOwner() internal view returns (bool) {
        return msg.sender != owner;
    }

    function notRouter() internal view returns (bool) {
        return msg.sender != router;
    }

    function notExchange() internal view returns (bool) {
        return msg.sender != exchange;
    }

    /*///////////////////////////////////////////////////////////////
                        RESTRICTED SETTERS
    //////////////////////////////////////////////////////////////*/

    function setExchange(address _exchange) external {
        if (notOwner()) revert OdysseyXp_Unauthorized();
        exchange = _exchange;
    }

    function setRouter(address _router) external {
        if (notOwner()) revert OdysseyXp_Unauthorized();
        router = _router;
    }

    function setDirectory(address _directory) external {
        if (notOwner()) revert OdysseyXp_Unauthorized();
        directory = OdysseyXpDirectory(_directory);
    }

    function transferOwnership(address _newOwner) external {
        if (notOwner()) revert OdysseyXp_Unauthorized();
        owner = _newOwner;
    }

    /*///////////////////////////////////////////////////////////////
                        XP Granting Methods
    //////////////////////////////////////////////////////////////*/

    function saleReward(
        address seller,
        address contractAddress,
        uint256 tokenId
    ) external {
        if (notExchange()) revert OdysseyXp_Unauthorized();
        _grantXP(
            seller,
            directory.getSaleReward(seller, contractAddress, tokenId)
        );
    }

    function purchaseReward(
        address buyer,
        address contractAddress,
        uint256 tokenId
    ) external {
        if (notExchange()) revert OdysseyXp_Unauthorized();
        _grantXP(
            buyer,
            directory.getPurchaseReward(buyer, contractAddress, tokenId)
        );
    }

    function mintReward(
        address buyer,
        address contractAddress,
        uint256 tokenId
    ) external {
        if (notRouter()) revert OdysseyXp_Unauthorized();
        _grantXP(
            buyer,
            directory.getMintReward(buyer, contractAddress, tokenId)
        );
    }

    function ohmPurchaseReward(
        address buyer,
        address contractAddress,
        uint256 tokenId
    ) external {
        if (notExchange()) revert OdysseyXp_Unauthorized();
        _grantXP(
            buyer,
            directory.getOhmPurchaseReward(buyer, contractAddress, tokenId)
        );
    }

    function ohmMintReward(
        address buyer,
        address contractAddress,
        uint256 tokenId
    ) external {
        if (notRouter()) revert OdysseyXp_Unauthorized();
        _grantXP(
            buyer,
            directory.getOhmMintReward(buyer, contractAddress, tokenId)
        );
    }

    /*///////////////////////////////////////////////////////////////
                            MINT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Grants the receiver the given amount of XP
    /// @dev Forces the receiver to redeem if they have rewards available
    /// @param receiver The address to grant XP to
    /// @param xp The amount of XP to grant
    function _grantXP(address receiver, uint256 xp)
        internal
        returns (uint256 assets)
    {
        uint256 currentXp = balanceOf[receiver];
        if ((assets = previewRedeem(receiver, currentXp)) > 0)
            _redeem(receiver, assets, currentXp); // force redeeming to keep portions in line
        else if (currentXp == 0)
            userHistories[receiver]
                .globallyWithdrawnAtLastRedeem = globallyWithdrawn; // if a new user, adjust their history to calculate withdrawn at their first redeem
        _mint(receiver, xp);

        emit Mint(msg.sender, assets, xp);

        afterMint(assets, xp);
    }

    /*///////////////////////////////////////////////////////////////
                        REDEEM LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice external redeem method
    /// @dev will revert if there is nothing to redeem
    function redeem() public returns (uint256 assets) {
        uint256 xp = balanceOf[msg.sender];
        if ((assets = previewRedeem(msg.sender, xp)) == 0)
            revert OdysseyXp_ZeroAssets();
        _redeem(msg.sender, assets, xp);
    }

    /// @notice Internal logic for redeeming rewards
    /// @param receiver The receiver of rewards
    /// @param assets The amount of assets to grant
    /// @param xp The amount of XP the user is redeeming with
    function _redeem(
        address receiver,
        uint256 assets,
        uint256 xp
    ) internal virtual {
        beforeRedeem(assets, xp);

        userHistories[receiver].balanceAtLastRedeem =
            asset.balanceOf(address(this)) -
            assets;
        userHistories[receiver].globallyWithdrawnAtLastRedeem =
            globallyWithdrawn +
            assets;
        globallyWithdrawn += assets;

        asset.safeTransfer(receiver, assets);

        emit Redeem(receiver, assets, xp);
    }

    /*///////////////////////////////////////////////////////////////
                           ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Preview the result of a redeem for the given user with the given XP amount
    /// @param recipient The user to check potential rewards for
    /// @param xp The amount of XP the user is previewing a redeem for
    function previewRedeem(address recipient, uint256 xp)
        public
        view
        virtual
        returns (uint256)
    {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return
            supply == 0 || xp == 0
                ? 0
                : xp.mulDivDown(totalAssets(recipient), supply);
    }

    /// @notice The total amount of available assets for the user, adjusted based on their history
    /// @param user The user to check assets for
    function totalAssets(address user) internal view returns (uint256) {
        uint256 balance = asset.balanceOf(address(this)); // Saves an extra SLOAD if balance is non-zero.
        return
            balance +
            (globallyWithdrawn -
                userHistories[user].globallyWithdrawnAtLastRedeem) -
            userHistories[user].balanceAtLastRedeem;
    }

    /*///////////////////////////////////////////////////////////////
                       OVERRIDE TRANSFERABILITY
    //////////////////////////////////////////////////////////////*/

    function transfer(address to, uint256 amount)
        public
        override
        returns (bool)
    {
        revert OdysseyXp_NonTransferable();
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        revert OdysseyXp_NonTransferable();
    }

    /*///////////////////////////////////////////////////////////////
                         INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

    function beforeRedeem(uint256 assets, uint256 xp) internal virtual {}

    function afterMint(uint256 assets, uint256 xp) internal virtual {}
}
