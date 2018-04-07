pragma solidity ^0.4.18;

import "./Ownable.sol";
import "./PausableToken.sol";
import "./BurnableToken.sol";
import "./FreezableToken.sol";
import "./TokenTimeLock.sol";

/**
 * @title CaleroToken
 */
contract CaleroToken is FreezableToken, PausableToken, BurnableToken {
    string public constant name = "Calero Token";
    string public constant symbol = "CLO";
    uint8 public constant decimals = 18;

    uint256 public constant INITIAL_SUPPLY = 100000000 ether;

    // ETH wallet addresses
    address public teamWalletAddress = 0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C;
    address public reserveWalletAddress = 0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C;
    address public contributorsWalletAddress = 0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C;
    
    // Locked tokens contract addresses
    address public lockedTeamTokensAddress;
    address public lockedReserveTokensAddress;
    address public lockedContributorsTokensAddress;
    
    // Lock times
    uint256 internal teamTokensLockTime = uint256(block.timestamp) + 1 years; // Lock for 1 year
    uint256 internal reserveTokensLockTime = uint256(block.timestamp) + 1 years; // Lock for 1 year
    uint256 internal contributorsTokensLockTime = uint256(block.timestamp) + 60 days; // Lock for 60 days / 2 months
    
    // Tokens distribution
    uint256 internal teamTokensAmaunt; 
    uint256 internal reserveTokensAmaunt;
    uint256 internal contributorsTokensAmaunt;
    uint256 internal crowdsaleTokensAmaunt;

    event TokenTimeLockEnabled(uint256 _tokensAmaunt, uint256 _releaseTime, address _beneficiary);
        
    /**
     * @dev Constructor
     */
    function CaleroToken() public {
        totalSupply_ = INITIAL_SUPPLY;
        
        // Calculate amaunt for each wallets
        teamTokensAmaunt = (totalSupply_.mul(20)).div(100);  // 20% from total supply
        reserveTokensAmaunt = (totalSupply_.mul(20)).div(100); // 20% from total supply
        contributorsTokensAmaunt = (totalSupply_.mul(10)).div(100); // 10% from total supply
        crowdsaleTokensAmaunt = (totalSupply_.mul(50)).div(100); // 50% from total supply
        
        // Create timelock contract for team, reserve and contributors addresses
        TokenTimelock lockedTeamTokens = new TokenTimelock(this, teamWalletAddress, teamTokensLockTime);
        TokenTimelock lockedReserveTokens = new TokenTimelock(this, reserveWalletAddress, reserveTokensLockTime);
        TokenTimelock lockedContributorsTokens = new TokenTimelock(this, contributorsWalletAddress, contributorsTokensLockTime);
        
        // Save addresses of timelock contracts
        lockedTeamTokensAddress = address(lockedTeamTokens);
        lockedReserveTokensAddress = address(lockedReserveTokens);
        lockedContributorsTokensAddress = address(lockedContributorsTokens);
          
        // Distributing tokens 
        balances[lockedTeamTokensAddress] = balances[lockedTeamTokensAddress].add(teamTokensAmaunt);
        balances[lockedReserveTokensAddress] = balances[lockedReserveTokensAddress].add(reserveTokensAmaunt);
        balances[lockedContributorsTokensAddress] = balances[lockedContributorsTokensAddress].add(contributorsTokensAmaunt);
        balances[msg.sender] = balances[msg.sender].add(crowdsaleTokensAmaunt);
        
        // Events
        TokenTimeLockEnabled(teamTokensAmaunt, teamTokensLockTime, teamWalletAddress); 
        TokenTimeLockEnabled(reserveTokensAmaunt, reserveTokensLockTime, reserveWalletAddress);  
        TokenTimeLockEnabled(contributorsTokensAmaunt, contributorsTokensLockTime, contributorsWalletAddress);  
        Transfer(0x0, msg.sender, crowdsaleTokensAmaunt);
    }
}