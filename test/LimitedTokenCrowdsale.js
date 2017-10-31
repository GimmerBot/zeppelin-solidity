import {advanceBlock} from '../submodules/zeppelin-gimmer/test/helpers/advanceToBlock'
import {increaseTimeTo, duration} from '../submodules/zeppelin-gimmer/test/helpers/increaseTime'
import latestTime from '../submodules/zeppelin-gimmer/test/helpers/latestTime'
import EVMThrow from '../submodules/zeppelin-gimmer/test/helpers/EVMThrow'
const BigNumber = web3.BigNumber

const should = require('chai')
    .use(require('chai-as-promised'))
    .use(require('chai-bignumber')(BigNumber))
    .should()

var LimitedTokenCrowdsale = artifacts.require("./LimitedTokenCrowdsale.sol");

contract ('LimitedTokenCrowdsale', function (caccounts) {
    var mainAcc = caccounts[0];

  
});