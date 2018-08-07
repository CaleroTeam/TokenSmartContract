pragma solidity ^0.4.24;

import "./FreezableToken.sol";
import "./PausableToken.sol";
import "./BurnableToken.sol";
import "./TokenTimeLock.sol";

/**
 * @title CaleroToken
 */
contract CaleroToken is FreezableToken, PausableToken, BurnableToken {
    string public constant name = "\"Calero\" Project utility token";
    string public constant symbol = "CLOR";
    uint8 public constant decimals = 18;

    uint256 public constant INITIAL_SUPPLY = 150000000 * 1 ether; // 150 million total supply

    // ETH wallet addresses
    address public teamWalletAddress = 0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C;               // 11% for team - lock up
    address public contributorsWalletAddress = 0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C;       // 10% for contributors - lock up
    address public reserveWalletAddress = 0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C;            // 20% for reserve

    // Locked tokens contract addresses
    address public lockedTeamTokensAddress;
    address public lockedContributorsTokensAddress;

    event TokenTimeLockEnabled(address _contractAddress, uint256 _tokensAmaunt, uint256 _releaseTime, address _beneficiary);

    /**
    * @dev Constructor
    */
    constructor() public {
        totalSupply_ = INITIAL_SUPPLY;

        // Calculate amaunt for each wallets
        uint256 teamTokensAmaunt = (totalSupply_.mul(11)).div(100); // 11% from total supply
        uint256 contributorsTokensAmaunt = (totalSupply_.mul(10)).div(100); // 10% from total supply
        uint256 reserveTokensAmaunt = (totalSupply_.mul(20)).div(100); // 20% from total supply
        uint256 crowdsaleTokensAmaunt = (totalSupply_.mul(59)).div(100); // 59% from total supply

        uint256 teamTokensLockTime = uint256(block.timestamp) + 365 days; // Lock for 1 year
        uint256 contributorsTokensLockTime = uint256(block.timestamp) + 60 days; // Lock for 60 days

        // Create timelock contract for team and contributors tokens
        TokenTimelock lockedTeamTokens = new TokenTimelock(this, teamWalletAddress, teamTokensLockTime);
        TokenTimelock lockedContributorsTokens = new TokenTimelock(this, contributorsWalletAddress, contributorsTokensLockTime);

        // Save addresses of timelock contracts
        lockedTeamTokensAddress = address(lockedTeamTokens);
        lockedContributorsTokensAddress = address(lockedContributorsTokens);

        // Distributing tokens
        balances[lockedTeamTokensAddress] = balances[lockedTeamTokensAddress].add(teamTokensAmaunt);
        balances[lockedContributorsTokensAddress] = balances[lockedContributorsTokensAddress].add(contributorsTokensAmaunt);
        balances[reserveWalletAddress] = balances[reserveWalletAddress].add(reserveTokensAmaunt);
        balances[msg.sender] = balances[msg.sender].add(crowdsaleTokensAmaunt);

        // Events
        emit TokenTimeLockEnabled(lockedTeamTokensAddress, teamTokensAmaunt, teamTokensLockTime, teamWalletAddress);
        emit TokenTimeLockEnabled(lockedContributorsTokensAddress, contributorsTokensAmaunt, contributorsTokensLockTime, contributorsWalletAddress);
        emit Transfer(address(0), reserveWalletAddress, reserveTokensAmaunt);
        emit Transfer(address(0), msg.sender, crowdsaleTokensAmaunt);
    }
}