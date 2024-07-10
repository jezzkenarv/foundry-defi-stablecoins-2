// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.18;

import { DecentralizedStableCoin } from "./DecentralizedStableCoin.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/*
 * @title DSCEngine
 * @author Jezz
 * 
 * This system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg
 * This stablecoin has the properties:
 * - Exogenous Collateral
 * - Dollar Pegged
 * - Algorithmic Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was only backed by WETH and WBTC 
 *
 * Our DSC system should always be "overcollateralized." At no point, should the value of all collateral <= the $ backed value of all DSC
 *
 * @notice This contract is the core of the DSC System. It handles all the logic for minting and redeeming DSC, as well as depositing and withdrawing collateral
 * @notice This contract is very loosely based on the MakerDao DSS (DAI) system  
 */

contract DSCEngine is ReentrancyGuard {
    /////////////////
    // Errors    ///
    ////////////////
    error DSCEngine__NeedsMoreThanZero();
    error DSC_Engine__TokenAddressAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__TokenNotAllowed();
    error DSCEngine__TransferFailed();
    error DSCEngine__HealthFactorBelowOne(uint256 userHealthFactor);

    ///////////////////////
    // State Variables ///
    //////////////////////

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 50% threshold, 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1; // 1 is the minimum health factor

    // this is used to get the current market price of the collateral tokens
    mapping(address token => address priceFeed) private s_priceFeeds; // tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;

    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    ///////////////////////
    // Events ////////////
    //////////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);

    /////////////////
    // Modifiers ///
    ////////////////

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__TokenNotAllowed();
        }
        _;
    }

    /////////////////
    // Functions ///
    ////////////////

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        // USD Price Feeds
        // the constructor checks that the lengths of the token and the price feed array are equal, ensuring each token has a corresponding price feed
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSC_Engine__TokenAddressAndPriceFeedAddressesMustBeSameLength();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    //////////////////////////
    // External Functions ///
    /////////////////////////

    function depositCollateralAndMintDSC() external {}

    /*
     * @notice follows CEI
     * @param tokenCollateralAddress The address of the token to be deposited as collateral
     * @param amountCollateral The amount of the token to be deposited as collateral
     */

     // all our checks are in our modifier and effects are in the function 
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForDSC() external {
        // set threshold to let's say 50%
        // if someone pays back your borrowed minted DSC, they can have all your collateral for a discount

        // $100 ETH Collateral -> $74 -> this is undercollateralized so we're going to let people liquidate their positions if they become undercollaterized under the threshold
        // I'll pay back the $50 DSC and get all your collateral
        // now previous user has $0 worth of ETH and I got $74 (I paid $50 DSC but got $74 ETH)
        // $50 DSC

        // redeem DSC
    }

    function redeemCollateral() external {}

    /*
     * @notice follows CEI
     * @param amountDscToMint The amount of decentralized stablecoin to mint
     * @notice they must have more collateral in value than the minimum threshold
     */

    // 1. Check if the collateral value > DSC amount. Price feeds, values, etc. 
    function mintDsc(uint256 amountDscToMint) external moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        // if they minted too much ($150 DSC, $100 ETH)
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    ///////////////////////////////////////////
    // Private and Internal View Functions ///
    /////////////////////////////////////////

    function _getAccountInformation() private view returns(uint256 totalDscMinted, uint256 collateralValueInUsd) {
        totalDscMinted = s_DSCMinted(user);
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /*
     * Returns how close to the liquidation user is
     * If a user goes below 1, then they can get liquidated
     */

    function _healthFactor(address user) private view returns(uint256) {
        // total DSC minted
        // total collateral VALUE
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user); 
        uint256 collateralAdjustedThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION; // 50% of the collateral value
        return (collateralAdjustedThreshold * PRECISION) / totalDscMinted; // 1000 ETH * 50 = 50,000 / 100 = 500 our true health factor

        // 1000 ETH * 50 = 50,000 / 100 = 500
        // $150 ETH / 100 DSC = 1.5
        // 150 * 50 = 7500 / 100 = (75/100) < 1
        
        // $1000 ETH / 100 DSC 
        // 1000 * 50 = 50,000 / 100 = 500 (500/100) = 5 > 1 
    }
    // 1. Check heatlh factor (do they have enough collateral?)
    // 2. Revert if they don't    
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 healthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorBelowOne(userHealthFactor);
        }


    }

    ///////////////////////////////////////////
    // Public & External View Functions //////
    /////////////////////////////////////////

    function getAccountCollateralValue(address user) public view returns(uint256) {
        // loop through each collateral token, get the amount they have deposited, and map it to the price, to get the USD value
        for(uint256 i = 0; i > s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
            // get the price feed
            // get the price of the token
            // multiply the amount by the price

        } 
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns(uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // 1 ETH = 1000 USD 
        // The returned value from Chainlink will be 1000 * 1e8
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION; // need to make this the same units of precision (1000 * 1e8 * (1e10)) * 1000 * 1e18

    }

}
