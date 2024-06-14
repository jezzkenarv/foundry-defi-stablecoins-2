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

contract DSCEngine { 

    /////////////////
    // Errors    ///
    ////////////////    
    error DSCEngine__NeedsMoreThanZero();
    error DSC_Engine__TokenAddressAndPriceFeedAddressesMustBeSameLength();

    ///////////////////////
    // State Variables ///
    //////////////////////
    mapping(address token => address priceFeed) private s_priceFeeds; // tokenToPriceFeed 


    /////////////////
    // Modifiers ///
    ////////////////

    modifier moreThanZero(uint256 amount) {
        if(amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    // modifier isAllowedToken(address token) {

    // }
    
    /////////////////
    // Functions ///
    ////////////////
    constructor(address[] memory tokenAddress, address[] memory priceFeedAddress, address dscAddress) {
        if(tokenAddress.length != priceFeedAddress.length) {
            revert error DSC_Engine__TokenAddressAndPriceFeedAddressesMustBeSameLength();
        }
        
    }

    //////////////////////////
    // External Functions ///
    /////////////////////////

    function depositCollateralAndMintDSC() external {
        
    }

    /*
     * @param tokenCollateralAddress The address of the token to be deposited as collateral
     * @param amountCollateral The amount of the token to be deposited as collateral
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral) external moreThanZero(amountCollateral) {

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

    function redeemCollateral() external {
        
    }

    function mintDsc() external {
        
    }

    function burnDsc() external {
        
    }

    function liquidate() external {
        
    }

    function getHealthFactor() external view {
       
    }
}