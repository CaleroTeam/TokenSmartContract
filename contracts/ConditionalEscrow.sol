pragma solidity ^0.4.24;

import "./Escrow.sol";

/**
 * @title ConditionalEscrow
 * @dev Base abstract escrow to only allow withdrawal if a condition is met.
 */
contract ConditionalEscrow is Escrow {
  /**
  * @dev Returns whether an address is allowed to withdraw their funds. To be
  * implemented by derived contracts.
  */
  function withdrawalAllowed() public view returns (bool);

  function withdraw(address _payee) public {
    require(withdrawalAllowed());
    super.withdraw(_payee);
  }
}
