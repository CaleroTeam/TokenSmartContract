pragma solidity ^0.4.24;

import "../CaleroToken.sol";

library TokenDeployer {
    function deployTokenContract() public returns(CaleroToken token) {
        token = new CaleroToken();
    }
}