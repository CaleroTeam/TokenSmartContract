pragma solidity ^0.4.24;

import "../CaleroICO.sol";

library CrowdsaleDeployer {
    function deployCrowdsaleContract(address _tokenAddress) public returns(CaleroICO ico) {
        ico = new CaleroICO(_tokenAddress);
    }
}