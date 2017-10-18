pragma solidity ^0.4.15;

import '../token/StandardToken.sol';
import '../math/SafeMath.sol';

// Contract for a Limited Token Crowdsale: at it's core, it's an exchange of tokens
// Uses StandardToken instead of MintTokens
// Provides functionality for delaying the start of the sale, withdrawal system for tokens,
//    ETH withdrawal to a wallet provided at construction - but at the base version the Crowdsale is not limited.
// Override it on your running version and add modifiers to control contract usage on the network.
// (Example: withdrawTokens can be overwritten and controlled to only allow users to withdraw their tokens after the campaign is over)
contract LimitedTokenCrowdSale {
    // use safemath for the .add, .mul used everywhere that deals with tokens/eth
    using SafeMath for uint256;

    // the token being sold
    StandardToken public token;

    // address where tokens balances are stored (for user withdrawal)
    mapping(address => uint256) public tokenBalance;

    // address where funds are collected
    address public wallet;

    // how many token units a buyer gets per wei at the start of the contract
    uint256 public initialTokenRate;

    // amount of raised money in wei
    uint256 public weiRaised;

    // amount of total tokens sold
    uint256 public tokensSold;

    // amount of tokens that have already been paid for, but not withdrawn
    uint256 public tokensToWithdraw;

    // the minimum amount of tokens a user is allowed to buy
    uint256 public minTokenTransaction;

    // the start date of the campaign
    uint256 public saleStartDate;

    /**
    * event for token purchase logging
    * @param purchaser who paid for the tokens
    * @param beneficiary who got the tokens
    * @param value weis paid for purchase
    * @param amount amount of tokens purchased
    */
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

  function LimitedTokenCrowdSale(uint256 _rate, uint256 _saleStartDate, 
                                  address _tokenAddress, uint256 _minTokenTransaction, 
                                  address _wallet) {
      require(_rate > 0);
      require(_saleStartDate != 0);
      require(_tokenAddress != 0x0);
      require(_minTokenTransaction >= 0);
      require(_wallet != 0x0);

      initialTokenRate = _rate;
      token = StandardToken(_tokenAddress);
      wallet = _wallet;
      minTokenTransaction = _minTokenTransaction;
      saleStartDate = _saleStartDate;
  }

  // Receive ETH
  function () payable {
    // block the transaction if the sale hasn't started yet
    require(now > saleStartDate);

    buyToken();
  }

  /**
  * @dev The current price of the Token for this contract
  * This method is constant and should never change the state of a contract
  * @return An uint256 representing the current token price.
  */
  function getCurrentTokenPrice() public constant returns (uint256) {
    return initialTokenRate;
  }

  // Saves how much the user bought in tokens
  function buyToken() payable {
    uint256 weiAmount = msg.value;
    address sender = msg.sender;

    require(sender != 0x0);
    require(weiAmount != 0);

    // give a chance to an inheriting contract to have
    // its own options for token pricing
    uint256 price = getCurrentTokenPrice();
    // calculate token amount to be given to user
    // (Solidity always truncates on division)
    uint256 tokens = weiAmount / price;

    // must have more tokens than min transaction..
    require(tokens > minTokenTransaction);
    // ..and the contract must have tokens to sell
    require(token.balanceOf(this) > tokens);

    // add to the balance of the user, to be paid later
    tokenBalance[sender] = tokenBalance[sender].add(tokens);

    // update how much Wei we have raised
    weiRaised = weiAmount.add(weiRaised);
    // update the total amount of tokens we have sold
    // (this value never goes down)
    tokensSold = tokensSold.add(tokens);
    // updates the total amount of tokens we have to still withdraw,
    // this will be subtracted each time an user withdraws
    tokensToWithdraw = tokensToWithdraw.add(tokens);

    // send an event for a Token Purchase
    TokenPurchase(sender, sender, weiAmount, tokens);
  }

  // Withdraws the tokens that the sender owns
  function withdrawTokens() public {
    address to = msg.sender;
    uint256 balance = tokenBalance[to];
    require(balance > 0);

    tokenBalance[to] = 0;
    if (token.transfer(to, balance)) {
      // only remove from the amount to withdraw if transfer returned true
      tokensToWithdraw = tokensToWithdraw.sub(balance);
    } else {
      // transfer failed, balance is stuck
      tokenBalance[to] = balance;
    }
  }  

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function tokenBalanceOf(address _owner) public constant returns (uint256 balance) {
    return tokenBalance[_owner];
  }

  /** 
  * @dev Send all the funds currently in the wallet to 
  * the organization wallet provided at the contract creation
  * Override this to control who is able to call this function, or else users
  * could potentially cash out for you (ETH still ends on your wallet, but not on your terms).
  */
  function withdrawFunds() public {
    require(this.balance > 0);
    wallet.transfer(this.balance);
  }
}