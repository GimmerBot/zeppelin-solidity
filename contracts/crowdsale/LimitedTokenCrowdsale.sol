/**
* @file
* @section DESCRIPTION
*
* Contract for a Limited Token Crowdsale: at it's core, it's an exchange of tokens.
* Uses StandardToken instead of MintTokens.
* Provides functionality for tracking how much each supporter helped with, 
* who has permissiong to buy higher values and uses withdrawal logic for the payment system.
*
* Wei withdrawal by default is to the wallet provided at construction.
* Inherit from this contract and override the payment and pricing functions to deploy a valid contract
*/
pragma solidity ^0.4.17;

import '../token/StandardToken.sol';
import '../math/SafeMath.sol';

/**
* @title Limited Token Crowdsale
*/
contract LimitedTokenCrowdSale {
    // Use safemath for the .add, .mul used everywhere that deals with tokens/eth
    using SafeMath for uint256;

    // The token being sold
    StandardToken public token;

    // Supporter structure, which allows us to track
    // how much the user has bought so far, if he's allowed to buy more
    // than the max limit for no KYC, or if he has any money frozen

    /**
    * Supporter structure, which allows us to track
    * how much the user has bought so far, if he's allowed to buy more
    * than the max limit for no KYC, or if he has any money frozen
    */
    struct Supporter {
        // the current amount this user has left to withdraw
        uint256 tokenBalance;
        // the total amount of tokens this user has bought from this contract
        uint256 tokensBought;
        // the total amount of Wei that is currently frozen in the system 
        // because the user has not yet provided KYC (know-your-customer, money laundering protection)
        // (this happens when the user buys more tokens than he is allowed without KYC - so neither the user nor
        // the owner of the contract can withdraw the Wei/Tokens until approveUserKYC(user) is called by the owner.)
        uint256 weiFrozen;
        // if the user has KYC flagged
        bool hasKYC;
    }

    // Mapping with all the campaign supporters
    mapping(address => Supporter) public supportersMap;

    // Address where funds are collected
    address public wallet;

    // Amount of total wei raised
    uint256 public weiRaised;

    // Amount of wei that is currently frozen and cannot be withdrawn by the owner
    uint256 public weiFrozen;

    // Amount of total tokens sold
    uint256 public tokensSold;

    // Amount of tokens that have already been paid for, but not withdrawn
    uint256 public tokensToWithdraw;

    // The minimum amount of tokens a user is allowed to buy
    uint256 public minTokenTransaction;

    // The limit of Wei that someone can spend on this contract before needing KYC approval
    uint256 public weiSaleLimitWithoutKYC;

    /**
    * Event for token purchase logging
    * @param purchaser Who paid for the tokens
    * @param value Weis paid for purchase
    * @param amount Amount of tokens purchased
    * @param price Price user paid for tokens
    */
    event TokenPurchase(address indexed purchaser, uint256 value, uint256 amount, uint256 price);

    /**
    * Event for user that purchased more than the contract allows
    * for users with no KYC approval
    * @param purchaser Who paid for the tokens
    * @param value Weis paid for purchases
    * @param amount Amount of tokens purchased
    */
    event KYCPending(address indexed purchaser, uint256 value, uint256 amount);

    function LimitedTokenCrowdSale(address _tokenAddress, uint256 _minTokenTransaction, 
                                    uint256 _weiSaleLimitWithoutKYC, address _wallet) public {
        require(_tokenAddress != address(0));
        require(_minTokenTransaction >= 0);
        require(_weiSaleLimitWithoutKYC != 0);
        require(_wallet != address(0));

        token = StandardToken(_tokenAddress);
        minTokenTransaction = _minTokenTransaction;
        weiSaleLimitWithoutKYC = _weiSaleLimitWithoutKYC;
        wallet = _wallet;
    }

    /** 
    * @dev Send all the funds currently in the wallet to 
    * the organization wallet provided at the contract creation.   
    */
    function internalWithdrawFunds() internal {
        require(this.balance > 0);

        // only withdraw money that is not frozen
        uint256 available = this.balance.sub(weiFrozen);
        require(available > 0);

        wallet.transfer(available);
    }

    /**
    * @dev Approves an User's KYC, unfreezing any wei/tokens
    * to be withdrawn
    */
    function internalApproveUserKYC(address user) internal {
        Supporter storage sup = supportersMap[user];
        weiFrozen = weiFrozen.sub(sup.weiFrozen);
        sup.weiFrozen = 0;
        sup.hasKYC = true;
    }

    /**
    * @dev Payment function: explicitly reverts as this class needs to be inherited and
    * shouldn't receive Wei without handling it
    */
    function () public payable {
        revert();
    }

    /**
    * @dev Override to return the token priced used 
    */
    function getTokenPrice() public constant returns (uint256);

    /**
    * @dev Saves how much the user bought in tokens for later withdrawal
    */
    function internalBuyToken(uint256 weiAmount, address sender) internal {
        require(sender != 0x0);
        require(weiAmount != 0);

        // give a chance to an inheriting contract to have
        // its own options for token pricing
        uint256 price = getTokenPrice();

        // calculate token amount to be given to user
        // (Solidity always truncates on division)
        uint256 tokens = weiAmount / price;

        // must have more tokens than min transaction..
        require(tokens > minTokenTransaction);
        // ..and the contract must have tokens available to sell
        require(token.balanceOf(this).sub(tokensToWithdraw) > tokens);

        // add to the balance of the user, to be paid later
        Supporter storage sup = supportersMap[sender];
        uint256 totalBought = sup.tokensBought.add(tokens);
        if (!sup.hasKYC && totalBought > weiSaleLimitWithoutKYC) {
            // money is frozen as user has no KYC,
            // and bought in total more than is allowed
            weiFrozen = weiFrozen.add(weiAmount); 
            sup.weiFrozen = sup.weiFrozen.add(weiAmount);

            KYCPending(sender, weiAmount, tokens);
        }
        // add to the total to be withdrawn
        sup.tokenBalance = sup.tokenBalance.add(tokens);

        // update the total amount of tokens bought
        sup.tokensBought = totalBought;
        // updates the total amount of tokens we have to still withdraw,
        // this will be subtracted each time an user withdraws
        tokensToWithdraw = tokensToWithdraw.add(tokens);

        // update how much Wei we have raised
        weiRaised = weiAmount.add(weiRaised);
        // update the total amount of tokens we have sold
        tokensSold = tokensSold.add(tokens);
        // send an event for a Token Purchase
        TokenPurchase(sender, weiAmount, tokens, price);
    }    
    
    /**
    * @dev Returns if an users has KYC approval or not
    * @return A boolean representing the user's KYC status
    */
    function userHasKYC(address user) public constant returns (bool) {
        return supportersMap[user].hasKYC;
    }

    /**
    * @dev Returns the total amount an user has bought from this contract
    * @return An uint256 representing the total amount of tokens the user bought
    */
    function userTotalBought(address user) public constant returns (uint256) {
        return supportersMap[user].tokensBought;
    }

    /**
    * @dev Gets the balance left to withdraw of the specified address.
    * @param _owner The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function tokenBalanceOf(address _owner) public constant returns (uint256) {
        return supportersMap[_owner].tokenBalance;
    }

    /**
    * @dev Withdraws the tokens that the sender owns
    */
    function withdrawTokens() public {
        address to = msg.sender;
        Supporter storage sup = supportersMap[to];
        uint256 balance = sup.tokenBalance;
        require(balance > 0);
        require(sup.weiFrozen == 0);

        if (token.transfer(to, balance)) {
            // only remove from the amount to withdraw if transfer returned true
            sup.tokenBalance = 0;
            tokensToWithdraw = tokensToWithdraw.sub(balance);
        } else {
            // transfer failed, balance is stuck
            revert();
        }
    }  
}