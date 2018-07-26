pragma solidity ^0.4.24;

interface CrowdsaleInterface {
    function startPhase(uint256 _tokens, uint256 _bonus, uint256 _startDate, uint256 _finishDate) external;

    function transferTokensToNonETHBuyers(address _contributor, uint256 _amount) external;

    function transferERC20(address _token, address _contributor, uint256 _amount) external;
    
    function killContract() external;
}