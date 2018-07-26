pragma solidity ^0.4.24;

/**
 * @title TokenInterface
 * @dev Token functionality interface
 */
interface TokenInterface {
    function balanceOf(address _address) external constant returns(uint);

    function totalSupply() external constant returns(uint);

    function transfer(address to, uint tokens) external returns(bool success);

    function transferFrom(address from, address to, uint tokens) external returns(bool success);

    function approve(address spender, uint tokens) external returns(bool success);

    function allowance(address tokenOwner, address spender) external constant returns(uint remaining);

    function burn(uint256 _value) external;

    function pause() external;

    function unpause() external;

    function freezeAccount(address target) external;

    function unFreezeAccount(address target) external;
    event Transfer(address indexed from, address indexed to, uint256 value);
}