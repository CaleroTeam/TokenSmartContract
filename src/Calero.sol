pragma solidity ^0.4.18;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    /**
    * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    function Ownable() public {
        owner = msg.sender;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

}


/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure.
 * To use this library you can add a `using SafeERC20 for ERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    function safeTransfer(ERC20Basic token, address to, uint256 value) internal {
        assert(token.transfer(to, value));
    }

    function safeTransferFrom(ERC20 token, address from, address to, uint256 value) internal {
        assert(token.transferFrom(from, to, value));
    }

    function safeApprove(ERC20 token, address spender, uint256 value) internal {
        assert(token.approve(spender, value));
    }
}


/**
 * @title TokenTimelock
 * @dev TokenTimelock is a token holder contract that will allow a
 * beneficiary to extract the tokens after a given release time
 */
contract TokenTimelock {
    using SafeERC20 for ERC20Basic;

    // CaleroToken basic token contract being held
    ERC20Basic public token;

    // beneficiary of tokens after they are released
    address public beneficiary;

    // timestamp when token release is enabled
    uint256 public releaseTime;
    
    function TokenTimelock(ERC20Basic _token, address _beneficiary, uint256 _releaseTime) public {
        require(_releaseTime > uint256(block.timestamp));
        require(_beneficiary != address(0));

        token = _token;
        beneficiary = _beneficiary;
        releaseTime = _releaseTime;
    }

    /**
     * @notice Transfers tokens held by timelock to beneficiary.
     */
    function release() public {
        require(uint256(block.timestamp) >= releaseTime);

        uint256 amount = token.balanceOf(this);
        require(amount > 0);

        token.safeTransfer(beneficiary, amount);
    }
}


/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
    function totalSupply() public view returns (uint256);
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}


/**
 * @title Basic token
 * @dev Basic version of StandardToken, with no allowances.
 */
contract BasicToken is ERC20Basic {
    using SafeMath for uint256;

    mapping(address => uint256) balances;

    uint256 totalSupply_;

    /**
    * @dev total number of tokens in existence
    */
    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    /**
    * @dev transfer token for a specified address
    * @param _to The address to transfer to.
    * @param _value The amount to be transferred.
    */
    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[msg.sender]);

        // SafeMath.sub will throw if there is not enough balance.
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(msg.sender, _to, _value);
        return true;
    }

    /**
    * @dev Gets the balance of the specified address.
    * @param _owner The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

}


/**
 * @title Burnable Token
 * @dev Token that can be irreversibly burned (destroyed).
 */
contract BurnableToken is BasicToken {

    event Burn(address indexed burner, uint256 value);

    /**
     * @dev Burns a specific amount of tokens.
     * @param _value The amount of token to be burned.
     */
    function burn(uint256 _value) public {
        require(_value <= balances[msg.sender]);
        // no need to require value <= totalSupply, since that would imply the
        // sender's balance is greater than the totalSupply, which *should* be an assertion failure

        address burner = msg.sender;
        balances[burner] = balances[burner].sub(_value);
        totalSupply_ = totalSupply_.sub(_value);
        Burn(burner, _value);
    }
}


/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) public view returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


/**
 * @title Standard ERC20 token
 *
 * @dev Implementation of the basic standard token.
 * @dev https://github.com/ethereum/EIPs/issues/20
 * @dev Based on code by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 */
contract StandardToken is ERC20, BasicToken {

    mapping (address => mapping (address => uint256)) internal allowed;

    /**
     * @dev Transfer tokens from one address to another
     * @param _from address The address which you want to send tokens from
     * @param _to address The address which you want to transfer to
     * @param _value uint256 the amount of tokens to be transferred
     */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        Transfer(_from, _to, _value);
        return true;
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     *
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
     * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param _spender The address which will spend the funds.
     * @param _value The amount of tokens to be spent.
     */
    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param _owner address The address which owns the funds.
     * @param _spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }

    /**
     * @dev Increase the amount of tokens that an owner allowed to a spender.
     *
     * approve should be called when allowed[_spender] == 0. To increment
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * @param _spender The address which will spend the funds.
     * @param _addedValue The amount of tokens to increase the allowance by.
     */
    function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
        allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
        Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner allowed to a spender.
     *
     * approve should be called when allowed[_spender] == 0. To decrement
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * @param _spender The address which will spend the funds.
     * @param _subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
        uint oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

}


/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is Ownable {
    event Pause();
    event Unpause();

    address public distributionContract;

    bool distributionContractAdded;
    bool public paused = false;

    /**
     * @dev Add distribution smart contract address
    */
    function addDistributionContract(address _contract) external {
        require(_contract != address(0));
        require(distributionContractAdded == false);

        distributionContract = _contract;
        distributionContractAdded = true;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        if(msg.sender != distributionContract) {
            require(!paused);
        }
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(paused);
        _;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() onlyOwner whenNotPaused public {
        paused = true;
        Pause();
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() onlyOwner whenPaused public {
        paused = false;
        Unpause();
    }
}


/**
 * @title Pausable token
 * @dev StandardToken modified with pausable transfers.
 **/
contract PausableToken is StandardToken, Pausable {

    function transfer(address _to, uint256 _value) public whenNotPaused returns (bool) {
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public whenNotPaused returns (bool) {
        return super.transferFrom(_from, _to, _value);
    }

    function approve(address _spender, uint256 _value) public whenNotPaused returns (bool) {
        return super.approve(_spender, _value);
    }

    function increaseApproval(address _spender, uint _addedValue) public whenNotPaused returns (bool success) {
        return super.increaseApproval(_spender, _addedValue);
    }

    function decreaseApproval(address _spender, uint _subtractedValue) public whenNotPaused returns (bool success) {
        return super.decreaseApproval(_spender, _subtractedValue);
    }
}


/**
 * @title FreezableToken
 */
contract FreezableToken is StandardToken, Ownable {
    mapping (address => bool) public frozenAccounts;
    event FrozenFunds(address target, bool frozen);

    function freezeAccount(address target) public onlyOwner {
        frozenAccounts[target] = true;
        FrozenFunds(target, true);
    }

    function unFreezeAccount(address target) public onlyOwner {
        frozenAccounts[target] = false;
        FrozenFunds(target, false);
    }

    function frozen(address _target) constant public returns (bool){
        return frozenAccounts[_target];
    }

    // @dev Limit token transfer if _sender is frozen.
    modifier canTransfer(address _sender) {
        require(!frozenAccounts[_sender]);
        _;
    }

    function transfer(address _to, uint256 _value) public canTransfer(msg.sender) returns (bool success) {
        // Call StandardToken.transfer()
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public canTransfer(_from) returns (bool success) {
        // Call StandardToken.transferForm()
        return super.transferFrom(_from, _to, _value);
    }
}


/**
 * @title CaleroToken
 */
contract CaleroToken is FreezableToken, PausableToken, BurnableToken {
    string public constant name = "\"Calero\" Project utility token";
    string public constant symbol = "CLO";
    uint8 public constant decimals = 18;

    uint256 public constant INITIAL_SUPPLY = 150000000 ether;

    // ETH wallet addresses
    address public teamWalletAddress = 0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C; // 20% for team
    address public contributorsWalletAddress = 0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C; // 10% for contributors
    address public reserveWalletAddress = 0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C; // 30% for reserve
    
    // Locked tokens contract addresses
    address public lockedTeamTokensAddress;
    address public lockedContributorsTokensAddress;
    
    // Lock times
    uint256 internal teamTokensLockTime = uint256(block.timestamp) + 1 years; // Lock for 1 year
    uint256 internal contributorsTokensLockTime = uint256(block.timestamp) + 60 days; // Lock for 60 days 
    
    // Tokens distribution
    uint256 internal teamTokensAmaunt; 
    uint256 internal contributorsTokensAmaunt;
    uint256 internal reserveTokensAmaunt;
    uint256 internal crowdsaleTokensAmaunt;

    event TokenTimeLockEnabled(address _contractAddress, uint256 _tokensAmaunt, uint256 _releaseTime, address _beneficiary);
        
    /**
     * @dev Constructor
     */
    function CaleroToken() public {
        totalSupply_ = INITIAL_SUPPLY;
        
        // Calculate amaunt for each wallets
        teamTokensAmaunt = (totalSupply_.mul(20)).div(100);  // 20% from total supply
        contributorsTokensAmaunt = (totalSupply_.mul(10)).div(100); // 10% from total supply
        reserveTokensAmaunt = (totalSupply_.mul(30)).div(100);  // 30% from total supply
        crowdsaleTokensAmaunt = (totalSupply_.mul(40)).div(100); // 40% from total supply
        
        // Create timelock contract for team, reserve and contributors addresses
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
        TokenTimeLockEnabled(lockedTeamTokensAddress, teamTokensAmaunt, teamTokensLockTime, teamWalletAddress); 
        TokenTimeLockEnabled(lockedContributorsTokensAddress, contributorsTokensAmaunt, contributorsTokensLockTime, contributorsWalletAddress);  
        Transfer(0x0,reserveWalletAddress, reserveTokensAmaunt);
        Transfer(0x0, msg.sender, crowdsaleTokensAmaunt);
    }
}


/**
 * @title CaleroICO
 */
contract CaleroICO is Ownable {
    using SafeMath for uint256;

    CaleroToken public token; // The token which being sold

    uint256 public stage = 0; // ICO stage (privat sale, pre sale, main sale)
    uint256 public tokensSold = 0; // Total value of sold tokens
    uint256 public buyPrice = 0.001 ether; // 1 CLE = 0.001ETH or 1 ETH ~ 1000 CLE
   
    uint256 public constant ICOdeadLine = 1538082000; // ICO finish time -  28 September 2018, 00:00:00

    uint256 public constant softcap = 1600000 ether; // Soft Cap = 1,600,000 CLE. Its constant and non-changeable number
    uint256 public constant hardcap = 50000000 ether; //  Hard Cap = 50,000,000 CLE. Its is constant and non-changeable number

    uint256 availableTokens = hardcap;

    bool public softcapReached;
    bool public hardcapReached;
    bool public refundIsAvailable;
    bool public burned;

    event SoftcapReached();
    event HardcapReached();

    event CrowdStarted(uint256 tokens, uint256 startDate, uint256 endDate, uint256 bonus);
    
    event RefundsEnabled();
    event Refunded(address indexed beneficiary, uint256 weiAmount);
    event Burned(uint256 amount);
   
    mapping(address => Contributor) public contributors;

    struct Contributor {
        uint256 eth;                // ETH on this wallet 
        bool whitelisted;           // White listed true/false
        uint256 ethHistory;         // All deposited ETH history
        uint256 tokensPurchasedDuringICO;  // Tokens puchuased during ICO
        uint256 bonusGetDuringPrivateSale;  // Bonus purchuased during private sale
    }

    struct Ico {
        uint256 tokens;    // Tokens in crowdsale
        uint256 startDate; // Date when crowsale will be starting, after its starting that property will be the 0
        uint256 endDate;   // Date when crowdsale will be stop
        uint256 bonus;  // Bonus
    }

    Ico public ICO;

    modifier afterDeadline {
        require(now > ICOdeadLine);
        _;
    }

    /**
     * @dev Constructor
     */
    function CaleroICO(address _contractAddress) Ownable() public {
        require(_contractAddress != 0x0);
        
        token = CaleroToken(_contractAddress);
        token.addDistributionContract(this);
    }

    /**
     * @dev fallback function
     */
    function () external payable {
        require(now < ICOdeadLine);
        require(ICO.startDate <= now);
        require(ICO.endDate > now);
        require(ICO.tokens != 0);

        _secureChecks(msg.sender);
    }

    /**
     * @dev token purchase
     * @param _contributor Address performing the token purchase
     */
    function _secureChecks(address _contributor) internal {
        require(_contributor != address(0));
        require(contributors[msg.sender].whitelisted);
        require(msg.value != 0);
        require(msg.value >= ( 1 ether / 100));

        _forwardFunds();
    }

    function _forwardFunds() internal {
        Contributor storage contributor = contributors[msg.sender];

        contributor.eth = contributor.eth.add(msg.value);
        contributor.ethHistory = contributor.ethHistory.add(msg.value);

        _deliverTokens(msg.sender);
    }

    function _deliverTokens(address _contributor) internal {
        Contributor storage contributor = contributors[_contributor];

        uint256 amountEth = contributor.eth;
        uint256 amountToken = _getTokenAmount(amountEth);

        if (1 == stage) {         
            contributor.bonusGetDuringPrivateSale = (contributor.bonusGetDuringPrivateSale).add( _withBonus(((amountEth * 1 ether).div(buyPrice)), ICO.bonus ));
            // Bonus tokens (for private sale buyers) will lock 2 more months after crowdsale finish
        }

        require(amountToken > 0);
        require(_confirmSell(amountToken));
        
        contributor.eth = 0;
        contributor.tokensPurchasedDuringICO = (contributor.tokensPurchasedDuringICO).add(amountToken);
        
        tokensSold = tokensSold.add(amountToken);
        availableTokens = availableTokens.sub(amountToken);
        ICO.tokens = ICO.tokens.sub(amountToken);

        // token.transfer(_contributor, amountToken); To change

        if ((tokensSold >= softcap) && !softcapReached) {
            softcapReached = true;
            SoftcapReached();
        }

        if (tokensSold == hardcap) {
            hardcapReached = true;
            HardcapReached();
        }

    }

    function _confirmSell(uint256 _amount) internal view returns(bool) {
        if (ICO.tokens < _amount) {
            return false;
        }

        return true;
    }

    /**
     * @dev the way in which ether is converted to tokens.
     * @param _weiAmount Value in wei to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _weiAmount
     */
    function _getTokenAmount(uint256 _weiAmount) internal view returns(uint256) {
        require(_weiAmount > 0);
        
        uint256 weiAmount = (_weiAmount * 1 ether).div(buyPrice);
        require(weiAmount > 0);
        
        weiAmount = weiAmount.add(_withBonus(weiAmount, ICO.bonus));
        return weiAmount;
    }

    function _withBonus(uint256 _amount, uint256 _percent) internal pure returns(uint256) {
        require(_amount > 0);

        return (_amount.mul(_percent)).div(100);
    }

    function _whitelistAddress(address _contributor) internal {
        require(_contributor != address(0));
        
        Contributor storage contributor = contributors[_contributor];
        contributor.whitelisted = true;
    }

    
    /************ Public functions for owner only ************/

    /**
     * @dev Start crowdsale state
     */
    function startCrowd(uint256 _tokens, uint256 _startDate, uint256 _endDate, uint256 _bonus) public onlyOwner {
        require(_tokens <= availableTokens);
        require(_startDate < _endDate);

        ICO = Ico(_tokens, _startDate, _endDate, _bonus); // _startDate + _endDate * 1 days
        stage = stage.add(1);

        CrowdStarted(_tokens, _startDate, _endDate, _bonus);
    }

    /**
     * @dev Change crowdsale bonus size
     */
    function changeBonus(uint256 _bonus) public onlyOwner returns(bool) {
        ICO = Ico (ICO.tokens, ICO.startDate, ICO.endDate, _bonus);
        return true;
    }

    /**
     * @dev Increase crowdsale tokens size
     */
    function increaseIcoStageTokensSize(uint256 _tokens) public onlyOwner returns(bool) {
        require(_tokens > 0);
         
        ICO = Ico ((ICO.tokens).add(_tokens), ICO.startDate, ICO.endDate, ICO.bonus);
        return true;
    }

    /**
     * @dev Decrease crowdsale bonus size
     */
    function decreaseIcoStageTokensSize(uint256 _tokens) public onlyOwner returns(bool) {
        require(_tokens > 0);
         
        ICO = Ico ((ICO.tokens).sub(_tokens), ICO.startDate, ICO.endDate, ICO.bonus);
        return true;
    }

    /**
     * @dev Change token buy size
     */ 
    function changeTokenBuyPrice(uint256 _numerator, uint256 _denominator) public onlyOwner returns(bool) {
        require(_numerator != 0);
        require(_denominator != 0);
    
        if (_numerator == 0) _numerator = 1;
        if (_denominator == 0) _denominator = 1;

        buyPrice = (_numerator * 1 ether).div(_denominator);

        return true;
    }
 
    /**
     * @dev Send tokens to contributor
     */
    function sendToken(address _address, uint256 _amountTokens) public onlyOwner returns(bool){
        require(_address != 0x0);
        require(_amountTokens != 0);

        require(token.transfer(_address, _amountTokens));

        return true;
    }

    /**
     * @dev Send tokens to many contributors
     */
    function sendTokens(address[] _addresses, uint256[] _amountTokens) public onlyOwner returns(bool) {
        require(_addresses.length > 0);
        require(_amountTokens.length > 0);
        require(_addresses.length  == _amountTokens.length);

        for (uint256 i = 0; i < _addresses.length; i++) {
            sendToken(_addresses[i], _amountTokens[i]);
        }

        return true;
    }

    /**
     * @dev Add contributor to whitelist
     */
    function whitelistAddress(address _contributor) public onlyOwner {
        _whitelistAddress(_contributor);
    }

    /**
     * @dev Add many contributors to whitelist
     */
    function whitelistAddresses(address[] _contributors) public onlyOwner {
        for (uint256 i = 0; i < _contributors.length; i++) {
            _whitelistAddress(_contributors[i]);
        }
    }

    /**
     * @dev Transfer ETH from smart contract if soft cap was reached
     */
    function transferEthFromContract(address _to, uint256 amount) public onlyOwner {
        require(softcapReached);
        
        _to.transfer(amount);
    }



    /************ Public functions for contributors ************/
    
    /**
     * @dev Burn smart contract available tokens after ICO
     */
    function burnAfterICO() public afterDeadline {
        require(!burned);
        require(!hardcapReached);

        token.burn(availableTokens);
        burned = true;

        Burned(availableTokens);
    }

    /**
     * @dev Returnstokens according to rate
     */
    function getTokenAmount(uint256 _weiAmount) public view returns(uint256) {
        return _getTokenAmount(_weiAmount);
    }
    
    /**
     * @dev Returnsavaialble tokens for current stage
     */
    function getPhaseAvailableTokens() public view returns(uint256) {
        return ICO.tokens;
    }
    
    /**
     * @dev Returnsavailable tokens for current phase for sale
     */
    function getPhaseBuyableTokens() public view returns(uint256) {
        uint256 tokensForBuy = (ICO.tokens).div(ICO.bonus + 100);
        return tokensForBuy;
    }

    /**
     * @dev Enable refund if softcap doesnt reached
     */
    function enableRefundAfterICO() public afterDeadline {
        require(!softcapReached);

        refundIsAvailable = true;

        RefundsEnabled();
    }

    /**
     * @dev Contributor call and get his ETH from contract
     */
    function getRefundAfterICO() public afterDeadline {
        require(refundIsAvailable);
        require(contributors[msg.sender].ethHistory > 0);

        Contributor storage contributor = contributors[msg.sender];

        uint256 depositedValue = contributor.ethHistory;
        contributor.ethHistory = 0;

        msg.sender.transfer(depositedValue);

        Refunded(msg.sender, depositedValue);
    }

    /**
     * @dev Get info about the contributor via address, who participated to crowdsale
     */
    function getInfoAboutContributor(address _contributor) public view returns(uint256, bool, uint256, uint256, uint256) {
        require(_contributor != address(0));

        Contributor memory contributor = contributors[_contributor];
        return(contributor.eth, contributor.whitelisted, contributor.ethHistory, contributor.tokensPurchasedDuringICO, contributor.bonusGetDuringPrivateSale);
    }

    /**
     * @dev Get crowdsale current status (string)
     */
    function crowdSaleStatus() public constant returns(string) {
        if (0 == stage) {
            return "ICO does not start yet.";
        }
        else if (1 == stage) {
            return "Private sale";
        }
        else if(2 == stage) {
            return "Pre sale";
        }
        else if (3 == stage) {
            return "ICO first stage";
        }
        else if (4 == stage) {
            return "ICO second stage";
        }
        else if (5 == stage) {
            return "ICO third stage";
        }

        return "Crowdsale finished!";
    }
    
}