pragma solidity ^0.4.18;

import "./SafeMath.sol";
import "./Ownable.sol";
import "./CaleroToken.sol";

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