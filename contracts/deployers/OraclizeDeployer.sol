pragma solidity ^0.4.24;

import "../oraclize/EthPriceOraclize.sol";

library OraclizeDeployer {
    function deployOraclize() public returns(EthPriceOraclize oraclize) {
        oraclize = new EthPriceOraclize();
    }
}