pragma solidity ^0.4.24;

import "../RefundVault.sol";

library VaultDeployer {
    function deployVaultContract(address _wallet, address _token) public returns(RefundVault vault) {
        vault = new RefundVault(_wallet, _token);
    }
}