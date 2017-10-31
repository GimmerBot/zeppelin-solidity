/**
* @file
* @section DESCRIPTION
*
* Contract for a Limited Token Crowdsale where eventually
* after the crowdsale ends (user set) we become a basically a store
* where the tokens the contract has left are sold directly to the end user,
* without the use of withdrawing logic.
*/
pragma solidity ^0.4.17;

import '../crowdsale/LimitedTokenCrowdsale.sol';
import '../math/SafeMath.sol';

/**
* @title Limited Token Direct Crowdsale
*/
contract LimitedTokenDirectCrowdsale is LimitedTokenCrowdSale {
    function LimitedTokenDirectCrowdsale(address _tokenAddress, uint256 _minTokenTransaction, 
        uint256 _weiSaleLimitWithoutKYC, address _wallet)
            LimitedTokenCrowdSale(_tokenAddress, _minTokenTransaction, 
                _weiSaleLimitWithoutKYC, _wallet) public {
    }

    /**
    * @dev The current price of the Token for this contract
    * Override to return the token priced used 
    * @return An uint256 representing the current token price.
    */
    function getDirectTokenPrice() public constant returns (uint256);

    /**
    * @dev Buys tokens and sends them directly to the end user
    */
    function internalBuyTokenDirect(uint256 weiAmount, address sender) internal {
        require(sender != 0x0);
        require(weiAmount != 0);

        // give a chance to an inheriting contract to have
        // its own options for token pricing
        uint256 price = getDirectTokenPrice();

        // calculate token amount to be given to user
        // (Solidity always truncates on division)
        uint256 tokens = weiAmount / price;

        // must have more tokens than min transaction..
        require(tokens > minTokenTransaction);
        // ..and the contract must have tokens to sell
        require(token.balanceOf(this) > tokens);

        // add to the balance of the user, to be paid later
        Supporter storage sup = supportersMap[sender];
        if (!sup.hasKYC && tokens > weiSaleLimitWithoutKYC) {
            revert(); // no KYC + too much Wei at after sale = no tokens
        }

        // add to the balance of the user, to be paid later
        if (token.transfer(sender, tokens)) {
            sup.tokensBought = sup.tokensBought.add(tokens);

            // update how much Wei we have raised
            weiRaised = weiAmount.add(weiRaised);
            // update the total amount of tokens we have sold
            // (this value never goes down)
            tokensSold = tokensSold.add(tokens);
            // send an event for a Token Purchase
            TokenPurchase(sender, weiAmount, tokens, price);
        }
    }
}