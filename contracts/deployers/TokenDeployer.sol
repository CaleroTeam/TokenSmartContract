pragma solidity ^0.4.24;

import "../CaleroToken.sol";

/**
 * @title TokenDeployer
 */
library TokenDeployer {
    function deployTokenContract() public returns(CaleroToken token) {
        token = new CaleroToken();
    }
}