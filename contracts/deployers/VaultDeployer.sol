pragma solidity ^0.4.24;

import "../RefundEscrow.sol";

/**
 * @title VaultDeployer
 */
library VaultDeployer {
    function deployVaultContract(address _wallet) public returns(RefundEscrow vault) {
        vault = new RefundEscrow(_wallet);
    }
}