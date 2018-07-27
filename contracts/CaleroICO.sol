pragma solidity ^0.4.24;

import "./SafeMath.sol";
import "./Ownable.sol";
import './oraclize/EthPriceOraclize.sol';
import './interfaces/TokenInterface.sol';
import './deployers/OraclizeDeployer.sol';
import './deployers/VaultDeployer.sol';
import './RefundVault.sol';

/**
 * @title Calero project crowdsale smart contract
 */
contract CaleroICO is Ownable {
    using SafeMath for uint256;

    uint256 public pricePerToken = 40; // 1 CLO - 40 cents or $0.4
    uint256 public weiRaised;
    uint256 public usdRaised;
    uint256 public tokensSold;

    uint256 public softCap = 5000000; // sofcap is $5 mln 

    uint256 public stage = 0;
    uint256 public minContributionAmount = 10 ** 17; // 0.1 ETH

    bool public softCapReached = false;
    bool public hardCapReached = false;
    bool public finalizeIsAvailable = true;

    TokenInterface public token;
    EthPriceOraclize public oraclize;
    RefundVault public vault;

    event TokenPurchase(address purchaser, address beneficiary, uint256 value, uint256 amount);
    event StageStarted(uint256 tokens, uint256 bonus, uint256 startDate, uint256 finishDate);
    event StageFinished(uint256 time);
    event SoftCapReached(uint256 time);

    struct Ico {
        uint256 tokens;
        uint256 bonus;
        uint256 startDate;
        uint256 finishDate;
        bool finished;
    }
    Ico public ICO;

    modifier duringSale {
        require(now < ICO.finishDate);
        require(now > ICO.startDate);
        require(ICO.finished == false);
        _;
    }

    /**
     * @dev Constructor
     */
    constructor(address _tokenAddress) public {
        token = TokenInterface(_tokenAddress);
        vault = VaultDeployer.deployVaultContract(msg.sender, token);
        oraclize = OraclizeDeployer.deployOraclize();
    }

    /**
     * @dev fallback function
     */
    function() external payable {
        buyTokens(msg.sender);
    }

    /**
     * @dev token purchase
     * @param _beneficiary Address performing the token purchase
     */
    function buyTokens(address _beneficiary) public payable duringSale {
        _preValidatePurchase(_beneficiary, msg.value);

        uint256 usdAmount = _getUSDETHPrice(msg.value);
        uint256 tokens = _getTokenAmount(usdAmount);
        
        if(ICO.bonus != 0) {
            uint256 bonus = _getBonus(tokens);
            tokens = tokens.add(bonus);
        }

        _deliverTokens(_beneficiary, tokens);
        _updatePurchasingState(tokens, msg.value, usdAmount);

        _forwardFunds();

        _postValidatePurchase();
    }

    /**
     * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met. Use super to concatenate validations.
     * @param _beneficiary Address performing the token purchase
     * @param _weiAmount Value in wei involved in the purchase
     */
    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) internal view {
        require(_beneficiary != address(0));
        require(_weiAmount >= minContributionAmount);
    }

    /**
     * @dev Get usd price of ETH which contributor send
     * @param _weiAmount Value in wei involved in the purchase
     */
    function _getUSDETHPrice(uint256 _weiAmount) internal view returns(uint256) {
        uint256 usdAmountOfWei = _weiAmount.mul(oraclize.getEthPrice());
        return usdAmountOfWei;
    }

    /** 
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param _usdPrice Value in wei to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _usdPrice
     */
    function _getTokenAmount(uint256 _usdPrice) internal view returns(uint256) {
        uint256 tokensAmaunt = _usdPrice.mul(100).div(pricePerToken);
        return tokensAmaunt;
    }

    /**
     * @dev Calulate bonus size for each stage
     * @param _amount Amount, which we need to calculate
     */
    function _getBonus(uint256 _amount) internal view returns(uint256) {
        return _amount.mul(ICO.bonus).div(100); 
    }

    /**
     * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends its tokens.
     * @param _beneficiary Address performing the token purchase
     * @param _tokenAmount Number of tokens to be emitted
     */
    function _deliverTokens(address _beneficiary, uint256 _tokenAmount) internal {
        token.transfer(_beneficiary, _tokenAmount);
    }

    /** 
     * @dev Override for extensions that require an internal state to check for validity (current user contributions, etc.)
     * @param _tokens Tokens which are purchased
     */
    function _updatePurchasingState(uint256 _tokens, uint256 _wei, uint256 _usdAmount) internal {
        tokensSold = tokensSold.add(_tokens);
        weiRaised = weiRaised.add(_wei);
        usdRaised = usdRaised.add(_usdAmount);

        ICO.tokens = ICO.tokens.sub(_tokens);

        if (ICO.tokens == 0) {
            ICO.finished = true;
            emit StageFinished(now);
        }
    }

    /**
     * @dev Determines how ETH is stored/forwarded on purchases.
     */
    function _forwardFunds() internal {
        vault.deposit.value(msg.value)(msg.sender);
    }

    /**
     * @dev Validation of an executed purchase. Observe state and use revert statements to undo rollback when valid conditions are not met.
     */
    function _postValidatePurchase() internal {
        if (!softCapReached && usdRaised >= softCap) {
            softCapReached = true;
            
            emit SoftCapReached(now);
        }
    }

    /**
     * @dev Start crowdsale phase
     */
    function startPhase(uint256 _tokens, uint256 _bonus, uint256 _startDate, uint256 _finishDate) public onlyOwner {
        require(_tokens <= token.balanceOf(address(this)));
        require(_startDate != 0 && _finishDate != 0);
        require(_bonus < 100);

        ICO = Ico(_tokens, _bonus, _startDate, _finishDate, false);
        stage = stage.add(1);

        emit StageStarted(_tokens, _bonus, _startDate, _finishDate);
    }

    /**
     * @dev Finish the crowdsale, enable refund or send all money to owner address
     */
    function finalizeCrowdsale() external {
        require(finalizeIsAvailable);
        require(stage > 3);

        finalizeIsAvailable = false;

        if (softCapReached == true) {
            vault.close();
        } else {
            vault.enableRefunds();
        }

        token.burn(token.balanceOf(this));
    }

    function transferTokensToNonETHBuyers(address _contributor, uint256 _amount) external onlyOwner {
        require(_contributor != address(0));
        require(_amount >= 0);

        token.transfer(_contributor, _amount);
    }

    function transferERC20(address _token, address _contributor, uint256 _amount) external onlyOwner {
        require(_token != address(0));
        require(_contributor != address(0));
        require(_amount >= 0);

        ERC20(_token).transfer(_contributor, _amount);
    }

    /**
     * @dev Get crowdsale current status (string)
     */
    function crowdSaleStatus() external constant returns(string) {
        if (0 == stage) {
            return "ICO does not start yet.";
        } else if (1 == stage) {
            return "Private sale";
        } else if (2 == stage) {
            return "Pre sale";
        } else if (3 == stage) {
            return "Main sale";
        }

        return "Crowdsale finished!";
    }
    
    /** 
     * @dev selfDistruct
     */
    function killContract() external onlyOwner {
        require(!finalizeIsAvailable);
        
        selfdestruct(owner);
    }
    
}