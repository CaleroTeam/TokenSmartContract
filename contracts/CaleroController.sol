pragma solidity ^0.4.24;

import './Multiownable.sol';
import './interfaces/TokenInterface.sol';
import './interfaces/CrowdsaleInterface.sol';
import './deployers/TokenDeployer.sol';
import './deployers/CrowdsaleDeployer.sol';

/**
 * @title CaleroController
 */
contract CaleroController is Multiownable {
    TokenInterface public token;
    CrowdsaleInterface public ico;

    /**
     * @dev Constructor
     */
    constructor() public {
        address _token = TokenDeployer.deployTokenContract();
        token = TokenInterface(_token);
    }

    function() external payable {
        // ETH claimed
    }

    function initCrowdsale() external onlyManyOwners {
        address _ico = CrowdsaleDeployer.deployCrowdsaleContract(address(token));
        ico = CrowdsaleInterface(_ico);

        token.transfer(_ico, token.balanceOf(this));  // Transfer all crowdsale tokens from controller to crowdsale contract
    }

    function startPhase(uint256 _tokens, uint256 _bonus, uint256 _startDate, uint256 _finishDate) external onlyManyOwners {
        ico.startPhase(_tokens, _bonus, _startDate, _finishDate);
    }

    function transferEther(address _contributor, uint256 _amount) external onlyManyOwners {
        require(_contributor != address(0));
        require(_amount >= 0);

        _contributor.transfer(_amount);
    }

    function transferTokensToNonETHBuyers(address _contributor, uint256 _amount) external onlyManyOwners {
        ico.transferTokensToNonETHBuyers(_contributor, _amount * 1 ether);
    }

    function transferERC20(address _token, address _contributor, uint256 _amount) external onlyManyOwners {
        ico.transferERC20(_token, _contributor, _amount);
    }

    function airdrop(address[] dests, uint256[] amounts) external onlyManyOwners {
        require(dests.length != 0);
        require(amounts.length != 0);
        require(dests.length == amounts.length);

        for (uint i = 0; i < dests.length; i++) {
            token.transfer(dests[i], amounts[i]);
        }
    }

    function freezeAccount(address _target) external onlyAnyOwner {
        require(_target != address(0), "freezeAccount: the target address is not correct");

        token.freezeAccount(_target);
    }

    function unFreezeAccount(address _target) external onlyAnyOwner {
        require(_target != address(0), "unFreezeAccount: the target address is not correct");

        token.unFreezeAccount(_target);
    }

    function pause() external onlyAnyOwner {
        token.pause();
    }

    function resume() external onlyAnyOwner {
        token.unpause();
    }

    function killICOContract() external onlyManyOwners {
        ico.killContract();
    }
}