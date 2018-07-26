pragma solidity ^0.4.24;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./ERC20.sol";

contract RefundVault is Ownable {
    using SafeMath
    for uint256;

    enum State {
        Active,
        Refunding,
        Closed
    }

    mapping(address => uint256) public deposited;
    address public wallet;
    State public state;

    ERC20 public token;

    event Closed();
    event RefundsEnabled();
    event Refunded(address indexed beneficiary, uint256 weiAmount, uint256 tokenAmount);

    /**
     * @param _wallet Vault address
     */
    constructor(address _wallet, address _token) public {
        require(_wallet != address(0));

        wallet = _wallet;
        state = State.Active;
        token = ERC20(_token);
    }

    /**
     * @param investor Investor address
     */
    function deposit(address investor) onlyOwner public payable {
        require(state == State.Active);

        deposited[investor] = deposited[investor].add(msg.value);
    }

    function close() onlyOwner public {
        require(state == State.Active);

        state = State.Closed;
        emit Closed();
        wallet.transfer(address(this).balance);
    }

    function enableRefunds() onlyOwner public {
        require(state == State.Active);

        state = State.Refunding;
        emit RefundsEnabled();
    }

    /**
     * @param investor Investor address
     */
    function refund(address investor) public {
        require(state == State.Refunding);

        uint256 depositedValue = deposited[investor];
        require(depositedValue > 0);

        deposited[investor] = 0;

        uint256 investorTokenBalance = token.balanceOf(investor);

        investor.transfer(depositedValue);
        emit Refunded(investor, depositedValue, investorTokenBalance);
    }

}