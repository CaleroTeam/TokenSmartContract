pragma solidity ^0.4.18;

import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";

/**
 * @title EthPriceOraclize
 * @dev Using oraclize for getting ETH price from coinmarketcap
 */
contract EthPriceOraclize is usingOraclize {
    uint256 public delay = 43200; // 12 hours
    uint256 public ETHUSD;

    event OraclizeCreated(address _oraclize);
    event LogInfo(string description);
    event LogPriceUpdate(uint256 price);

    function() external payable {
        update(1);
    }

    function EthPriceOraclize() public {
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);

        OraclizeCreated(this);
        update(1);
    }

    function __callback(bytes32 id, string result, bytes proof) public {
        require(msg.sender == oraclize_cbAddress());

        ETHUSD = parseInt(result,2);
        LogPriceUpdate(ETHUSD);

        update(delay);
    }

    function update(uint256 _delay) payable public {
        if (oraclize_getPrice("URL") > address(this).balance) {
            LogInfo("Oraclize query was NOT sent, please add some ETH to cover for the query fee!");
        } else {
            LogInfo("Oraclize query was sent, standing by for the answer ...");
            oraclize_query(_delay, "URL", "json(https://api.coinmarketcap.com/v1/ticker/ethereum/).0.price_usd");
        }
    }

    function getEthPrice() external view returns(uint256) {
        return ETHUSD;
    }
}

pragma solidity ^0.4.24;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

    /**
     * @dev Multiplies two numbers, throws on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns(uint256 c) {
        // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        c = a * b;
        assert(c / a == b);
        return c;
    }

    /**
     * @dev Integer division of two numbers, truncating the quotient.
     */
    function div(uint256 a, uint256 b) internal pure returns(uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return a / b;
    }

    /**
     * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns(uint256) {
        assert(b <= a);
        return a - b;
    }

    /**
     * @dev Adds two numbers, throws on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns(uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure.
 * To use this library you can add a `using SafeERC20 for ERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    function safeTransfer( IERC20 _token, address _to, uint256 _value ) internal {
        require(_token.transfer(_to, _value));
    }
}


// Deployers

/**
 * @title CrowdsaleDeployer
 */
library CrowdsaleDeployer {
    function deployCrowdsaleContract(address _tokenAddress) public returns(CaleroICO ico) {
        ico = new CaleroICO(_tokenAddress);
    }
}

/**
 * @title TokenDeployer
 */
library TokenDeployer {
    function deployTokenContract() public returns(CaleroToken token) {
        token = new CaleroToken();
    }
}

/**
 * @title OraclizeDeployer
 */
library OraclizeDeployer {
    function deployOraclize() public returns(EthPriceOraclize oraclize) {
        oraclize = new EthPriceOraclize();
    }
}

/**
 * @title VaultDeployer
 */
library VaultDeployer {
    function deployVaultContract(address _wallet) public returns(RefundEscrow vault) {
        vault = new RefundEscrow(_wallet);
    }
}


// Ownerships

/**
 * @title Multiownable
 */
contract Multiownable {

    // VARIABLES

    uint256 public ownersGeneration;
    uint256 public howManyOwnersDecide;
    address[] public owners;
    bytes32[] public allOperations;
    address internal insideCallSender;
    uint256 internal insideCallCount;

    // Reverse lookup tables for owners and allOperations
    mapping(address => uint) public ownersIndices; // Starts from 1
    mapping(bytes32 => uint) public allOperationsIndicies;

    // Owners voting mask per operations
    mapping(bytes32 => uint256) public votesMaskByOperation;
    mapping(bytes32 => uint256) public votesCountByOperation;

    // EVENTS

    event OwnershipTransferred(address[] previousOwners, uint howManyOwnersDecide, address[] newOwners, uint newHowManyOwnersDecide);
    event OperationCreated(bytes32 operation, uint howMany, uint ownersCount, address proposer);
    event OperationUpvoted(bytes32 operation, uint votes, uint howMany, uint ownersCount, address upvoter);
    event OperationPerformed(bytes32 operation, uint howMany, uint ownersCount, address performer);
    event OperationDownvoted(bytes32 operation, uint votes, uint ownersCount,  address downvoter);
    event OperationCancelled(bytes32 operation, address lastCanceller);

    // ACCESSORS

    function isOwner(address wallet) public constant returns(bool) {
        return ownersIndices[wallet] > 0;
    }

    function ownersCount() public constant returns(uint) {
        return owners.length;
    }

    function allOperationsCount() public constant returns(uint) {
        return allOperations.length;
    }

    // MODIFIERS

    /**
    * @dev Allows to perform method by any of the owners
    */
    modifier onlyAnyOwner {
        if (checkHowManyOwners(1)) {
            bool update = (insideCallSender == address(0));
            if (update) {
                insideCallSender = msg.sender;
                insideCallCount = 1;
            }
            _;
            if (update) {
                insideCallSender = address(0);
                insideCallCount = 0;
            }
        }
    }

    /**
    * @dev Allows to perform method only after many owners call it with the same arguments
    */
    modifier onlyManyOwners {
        if (checkHowManyOwners(howManyOwnersDecide)) {
            bool update = (insideCallSender == address(0));
            if (update) {
                insideCallSender = msg.sender;
                insideCallCount = howManyOwnersDecide;
            }
            _;
            if (update) {
                insideCallSender = address(0);
                insideCallCount = 0;
            }
        }
    }

    /**
    * @dev Allows to perform method only after all owners call it with the same arguments
    */
    modifier onlyAllOwners {
        if (checkHowManyOwners(owners.length)) {
            bool update = (insideCallSender == address(0));
            if (update) {
                insideCallSender = msg.sender;
                insideCallCount = owners.length;
            }
            _;
            if (update) {
                insideCallSender = address(0);
                insideCallCount = 0;
            }
        }
    }

    /**
    * @dev Allows to perform method only after some owners call it with the same arguments
    */
    modifier onlySomeOwners(uint howMany) {
        require(howMany > 0, "onlySomeOwners: howMany argument is zero");
        require(howMany <= owners.length, "onlySomeOwners: howMany argument exceeds the number of owners");

        if (checkHowManyOwners(howMany)) {
            bool update = (insideCallSender == address(0));
            if (update) {
                insideCallSender = msg.sender;
                insideCallCount = howMany;
            }
            _;
            if (update) {
                insideCallSender = address(0);
                insideCallCount = 0;
            }
        }
    }

    // CONSTRUCTOR

    constructor() public {
        owners.push(msg.sender);
        ownersIndices[msg.sender] = 1;
        howManyOwnersDecide = 1;
    }

    // INTERNAL METHODS

    /**
     * @dev onlyManyOwners modifier helper
     */
    function checkHowManyOwners(uint howMany) internal returns(bool) {
        if (insideCallSender == msg.sender) {
            require(howMany <= insideCallCount, "checkHowManyOwners: nested owners modifier check require more owners");
            return true;
        }

        uint ownerIndex = ownersIndices[msg.sender] - 1;
        require(ownerIndex < owners.length, "checkHowManyOwners: msg.sender is not an owner");
        bytes32 operation = keccak256(abi.encodePacked(msg.data, ownersGeneration));

        require((votesMaskByOperation[operation] & (2 ** ownerIndex)) == 0, "checkHowManyOwners: owner already voted for the operation");
        votesMaskByOperation[operation] |= (2 ** ownerIndex);
        uint operationVotesCount = votesCountByOperation[operation] + 1;
        votesCountByOperation[operation] = operationVotesCount;
        if (operationVotesCount == 1) {
            allOperationsIndicies[operation] = allOperations.length;
            allOperations.push(operation);
            emit OperationCreated(operation, howMany, owners.length, msg.sender);
        }
        emit OperationUpvoted(operation, operationVotesCount, howMany, owners.length, msg.sender);

        // If enough owners confirmed the same operation
        if (votesCountByOperation[operation] == howMany) {
            deleteOperation(operation);
            emit OperationPerformed(operation, howMany, owners.length, msg.sender);
            return true;
        }

        return false;
    }

    /**
    * @dev Used to delete cancelled or performed operation
    * @param operation defines which operation to delete
    */
    function deleteOperation(bytes32 operation) internal {
        uint index = allOperationsIndicies[operation];
        if (index < allOperations.length - 1) { // Not last
            allOperations[index] = allOperations[allOperations.length - 1];
            allOperationsIndicies[allOperations[index]] = index;
        }
        allOperations.length--;

        delete votesMaskByOperation[operation];
        delete votesCountByOperation[operation];
        delete allOperationsIndicies[operation];
    }

    // PUBLIC METHODS

    /**
    * @dev Allows owners to change their mind by cancelling votesMaskByOperation operations
    * @param operation defines which operation to delete
    */
    function cancelPending(bytes32 operation) public onlyAnyOwner {
        uint ownerIndex = ownersIndices[msg.sender] - 1;
        require((votesMaskByOperation[operation] & (2 ** ownerIndex)) != 0, "cancelPending: operation not found for this user");
        votesMaskByOperation[operation] &= ~(2 ** ownerIndex);
        uint operationVotesCount = votesCountByOperation[operation] - 1;
        votesCountByOperation[operation] = operationVotesCount;
        emit OperationDownvoted(operation, operationVotesCount, owners.length, msg.sender);
        if (operationVotesCount == 0) {
            deleteOperation(operation);
            emit OperationCancelled(operation, msg.sender);
        }
    }

    /**
    * @dev Allows owners to change ownership
    * @param newOwners defines array of addresses of new owners
    * @param newHowManyOwnersDecide defines how many owners can decide
    */
    function transferOwnershipWithHowMany(address[] newOwners, uint256 newHowManyOwnersDecide) public onlyManyOwners {
        require(newOwners.length > 0, "transferOwnershipWithHowMany: owners array is empty");
        require(newOwners.length <= 256, "transferOwnershipWithHowMany: owners count is greater then 256");
        require(newHowManyOwnersDecide > 0, "transferOwnershipWithHowMany: newHowManyOwnersDecide equal to 0");
        require(newHowManyOwnersDecide <= newOwners.length, "transferOwnershipWithHowMany: newHowManyOwnersDecide exceeds the number of owners");

        // Reset owners reverse lookup table
        for (uint j = 0; j < owners.length; j++) {
            delete ownersIndices[owners[j]];
        }
        for (uint i = 0; i < newOwners.length; i++) {
            require(newOwners[i] != address(0), "transferOwnershipWithHowMany: owners array contains zero");
            require(ownersIndices[newOwners[i]] == 0, "transferOwnershipWithHowMany: owners array contains duplicates");
            ownersIndices[newOwners[i]] = i + 1;
        }

        emit OwnershipTransferred(owners, howManyOwnersDecide, newOwners, newHowManyOwnersDecide);
        owners = newOwners;
        howManyOwnersDecide = newHowManyOwnersDecide;
        allOperations.length = 0;
        ownersGeneration++;
    }

}

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address public owner;

    event OwnershipRenounced(address indexed previousOwner);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor() public {
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
     * @dev Allows the current owner to relinquish control of the contract.
     * @notice Renouncing to ownership will leave the contract without an owner.
     * It will not be possible to call the functions with the `onlyOwner`
     * modifier anymore.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipRenounced(owner);
        owner = address(0);
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param _newOwner The address to transfer ownership to.
     */
    function transferOwnership(address _newOwner) public onlyOwner {
        _transferOwnership(_newOwner);
    }

    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param _newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address _newOwner) internal {
        require(_newOwner != address(0));
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
}


// Token

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
interface IERC20 {
  function totalSupply() external view returns (uint256);

  function balanceOf(address _who) external view returns (uint256);

  function allowance(address _owner, address _spender)
    external view returns (uint256);

  function transfer(address _to, uint256 _value) external returns (bool);

  function approve(address _spender, uint256 _value)
    external returns (bool);

  function transferFrom(address _from, address _to, uint256 _value)
    external returns (bool);

  event Transfer(
    address indexed from,
    address indexed to,
    uint256 value
  );

  event Approval(
    address indexed owner,
    address indexed spender,
    uint256 value
  );
}

/**
 * @title Standard ERC20 token
 *
 * @dev Implementation of the basic standard token.
 * https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md
 * Originally based on code by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 */
contract ERC20 is IERC20 {
  using SafeMath for uint256;

  mapping (address => uint256) private balances_;

  mapping (address => mapping (address => uint256)) private allowed_;

  uint256 private totalSupply_;

  /**
  * @dev Total number of tokens in existence
  */
  function totalSupply() public view returns (uint256) {
    return totalSupply_;
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public view returns (uint256) {
    return balances_[_owner];
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(
    address _owner,
    address _spender
   )
    public
    view
    returns (uint256)
  {
    return allowed_[_owner][_spender];
  }

  /**
  * @dev Transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(_value <= balances_[msg.sender]);
    require(_to != address(0));

    balances_[msg.sender] = balances_[msg.sender].sub(_value);
    balances_[_to] = balances_[_to].add(_value);
    emit Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) public returns (bool) {
    allowed_[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amount of tokens to be transferred
   */
  function transferFrom(
    address _from,
    address _to,
    uint256 _value
  )
    public
    returns (bool)
  {
    require(_value <= balances_[_from]);
    require(_value <= allowed_[_from][msg.sender]);
    require(_to != address(0));

    balances_[_from] = balances_[_from].sub(_value);
    balances_[_to] = balances_[_to].add(_value);
    allowed_[_from][msg.sender] = allowed_[_from][msg.sender].sub(_value);
    emit Transfer(_from, _to, _value);
    return true;
  }

  /**
   * @dev Increase the amount of tokens that an owner allowed to a spender.
   * approve should be called when allowed_[_spender] == 0. To increment
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param _spender The address which will spend the funds.
   * @param _addedValue The amount of tokens to increase the allowance by.
   */
  function increaseApproval(
    address _spender,
    uint256 _addedValue
  )
    public
    returns (bool)
  {
    allowed_[msg.sender][_spender] = (
      allowed_[msg.sender][_spender].add(_addedValue));
    emit Approval(msg.sender, _spender, allowed_[msg.sender][_spender]);
    return true;
  }

  /**
   * @dev Decrease the amount of tokens that an owner allowed to a spender.
   * approve should be called when allowed_[_spender] == 0. To decrement
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param _spender The address which will spend the funds.
   * @param _subtractedValue The amount of tokens to decrease the allowance by.
   */
  function decreaseApproval(
    address _spender,
    uint256 _subtractedValue
  )
    public
    returns (bool)
  {
    uint256 oldValue = allowed_[msg.sender][_spender];
    if (_subtractedValue >= oldValue) {
      allowed_[msg.sender][_spender] = 0;
    } else {
      allowed_[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    emit Approval(msg.sender, _spender, allowed_[msg.sender][_spender]);
    return true;
  }

  /**
   * @dev Internal function that mints an amount of the token and assigns it to
   * an account. This encapsulates the modification of balances such that the
   * proper events are emitted.
   * @param _account The account that will receive the created tokens.
   * @param _amount The amount that will be created.
   */
  function _mint(address _account, uint256 _amount) internal {
    require(_account != 0);
    totalSupply_ = totalSupply_.add(_amount);
    balances_[_account] = balances_[_account].add(_amount);
    emit Transfer(address(0), _account, _amount);
  }

  /**
   * @dev Internal function that burns an amount of the token of a given
   * account.
   * @param _account The account whose tokens will be burnt.
   * @param _amount The amount that will be burnt.
   */
  function _burn(address _account, uint256 _amount) internal {
    require(_account != 0);
    require(_amount <= balances_[_account]);

    totalSupply_ = totalSupply_.sub(_amount);
    balances_[_account] = balances_[_account].sub(_amount);
    emit Transfer(_account, address(0), _amount);
  }

  /**
   * @dev Internal function that burns an amount of the token of a given
   * account, deducting from the sender's allowance for said account. Uses the
   * internal _burn function.
   * @param _account The account whose tokens will be burnt.
   * @param _amount The amount that will be burnt.
   */
  function _burnFrom(address _account, uint256 _amount) internal {
    require(_amount <= allowed_[_account][msg.sender]);

    // Should https://github.com/OpenZeppelin/zeppelin-solidity/issues/707 be accepted,
    // this function needs to emit an event with the updated approval.
    allowed_[_account][msg.sender] = allowed_[_account][msg.sender].sub(
      _amount);
    _burn(_account, _amount);
  }
}

/**
 * @title Burnable Token
 * @dev Token that can be irreversibly burned (destroyed).
 */
contract ERC20Burnable is ERC20 {

  event TokensBurned(address indexed burner, uint256 value);

  /**
   * @dev Burns a specific amount of tokens.
   * @param _value The amount of token to be burned.
   */
  function burn(uint256 _value) public {
    _burn(msg.sender, _value);
  }

  /**
   * @dev Burns a specific amount of tokens from the target address and decrements allowance
   * @param _from address The address which you want to send tokens from
   * @param _value uint256 The amount of token to be burned
   */
  function burnFrom(address _from, uint256 _value) public {
    _burnFrom(_from, _value);
  }

  /**
   * @dev Overrides ERC20._burn in order for burn and burnFrom to emit
   * an additional Burn event.
   */
  function _burn(address _who, uint256 _value) internal {
    super._burn(_who, _value);
    emit TokensBurned(_who, _value);
  }
}

/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is Ownable {
  event Paused();
  event Unpaused();

  bool public paused = false;


  /**
   * @dev Modifier to make a function callable only when the contract is not paused.
   */
  modifier whenNotPaused() {
    require(!paused);
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
  function pause() public onlyOwner whenNotPaused {
    paused = true;
    emit Paused();
  }

  /**
   * @dev called by the owner to unpause, returns to normal state
   */
  function unpause() public onlyOwner whenPaused {
    paused = false;
    emit Unpaused();
  }
}

/**
 * @title Pausable token
 * @dev ERC20 modified with pausable transfers.
 **/
contract ERC20Pausable is ERC20, Pausable {

  function transfer(
    address _to,
    uint256 _value
  )
    public
    whenNotPaused
    returns (bool)
  {
    return super.transfer(_to, _value);
  }

  function transferFrom(
    address _from,
    address _to,
    uint256 _value
  )
    public
    whenNotPaused
    returns (bool)
  {
    return super.transferFrom(_from, _to, _value);
  }

  function approve(
    address _spender,
    uint256 _value
  )
    public
    whenNotPaused
    returns (bool)
  {
    return super.approve(_spender, _value);
  }

  function increaseApproval(
    address _spender,
    uint _addedValue
  )
    public
    whenNotPaused
    returns (bool success)
  {
    return super.increaseApproval(_spender, _addedValue);
  }

  function decreaseApproval(
    address _spender,
    uint _subtractedValue
  )
    public
    whenNotPaused
    returns (bool success)
  {
    return super.decreaseApproval(_spender, _subtractedValue);
  }
}

/**
 * @title FreezableToken
 */
contract ERC20Freezable is ERC20, Ownable {
    mapping(address => bool) public frozenAccounts;
    event FrozenFunds(address target, bool frozen);

    function freezeAccount(address target) public onlyOwner {
        frozenAccounts[target] = true;
        emit FrozenFunds(target, true);
    }

    function unFreezeAccount(address target) public onlyOwner {
        frozenAccounts[target] = false;
        emit FrozenFunds(target, false);
    }

    function frozen(address _target) constant public returns(bool) {
        return frozenAccounts[_target];
    }

    // @dev Limit token transfer if _sender is frozen.
    modifier canTransfer(address _sender) {
        require(!frozenAccounts[_sender]);
        _;
    }

    function transfer(address _to, uint256 _value) public canTransfer(msg.sender) returns(bool success) {
        // Call StandardToken.transfer()
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public canTransfer(_from) returns(bool success) {
        // Call StandardToken.transferForm()
        return super.transferFrom(_from, _to, _value);
    }
}

/**
 * @title TokenTimelock
 * @dev TokenTimelock is a token holder contract that will allow a
 * beneficiary to extract the tokens after a given release time
 */
contract TokenTimelock {
  using SafeERC20 for IERC20;

  // ERC20 basic token contract being held
  IERC20 private token_;

  // beneficiary of tokens after they are released
  address private beneficiary_;

  // timestamp when token release is enabled
  uint256 private releaseTime_;

  constructor(
    IERC20 _token,
    address _beneficiary,
    uint256 _releaseTime
  )
    public
  {
    // solium-disable-next-line security/no-block-members
    require(_releaseTime > block.timestamp);
    token_ = _token;
    beneficiary_ = _beneficiary;
    releaseTime_ = _releaseTime;
  }

  /**
   * @return the token being held.
   */
  function token() public view returns(IERC20) {
    return token_;
  }

  /**
   * @return the beneficiary of the tokens.
   */
  function beneficiary() public view returns(address) {
    return beneficiary_;
  }

  /**
   * @return the time when the tokens are released.
   */
  function releaseTime() public view returns(uint256) {
    return releaseTime_;
  }

  /**
   * @notice Transfers tokens held by timelock to beneficiary.
   */
  function release() public {
    // solium-disable-next-line security/no-block-members
    require(block.timestamp >= releaseTime_);

    uint256 amount = token_.balanceOf(address(this));
    require(amount > 0);

    token_.safeTransfer(beneficiary_, amount);
  }
}

/**
 * @title CaleroToken
 */
contract CaleroToken is ERC20Freezable, ERC20Pausable, ERC20Burnable {
    string public constant name = "\"Calero\" Project utility token";
    string public constant symbol = "CLER";
    uint8 public constant decimals = 18;

    /**
    * @dev Constructor
    */
    constructor() public {
        _mint(msg.sender, 150000000 * 1 ether); // 150mln tokens totally
    }
}


// Interfaces

/**
 * @title CrowdsaleInterface
 * @dev Crowdsale functionality interface
 */
contract CrowdsaleInterface {
    function startPhase(uint256 _tokens, uint256 _bonus, uint256 _startDate, uint256 _finishDate) external;
    function transferTokensToNonETHBuyers(address _beneficiary, uint256 _tokens, uint256 _usdReceived) external;
    function transferERC20(address _token, address _beneficiary, uint256 _amount) external;
    function finalizeCrowdsale() external;
}

/**
 * @title TokenInterface
 * @dev Token functionality interface
 */
contract CLERInterface is IERC20 {
    function burn(uint256 _value) external;
    function pause() external;
    function unpause() external;
    function freezeAccount(address target) external;
    function unFreezeAccount(address target) external;
}


// Funds

/**
 * @title Escrow
 * @dev Base escrow contract, holds funds destinated to a payee until they
 * withdraw them. The contract that uses the escrow as its payment method
 * should be its owner, and provide public methods redirecting to the escrow's
 * deposit and withdraw.
 */
contract Escrow is Ownable {
  using SafeMath for uint256;

  event Deposited(address indexed payee, uint256 weiAmount);
  event Withdrawn(address indexed payee, uint256 weiAmount);

  mapping(address => uint256) private deposits;

  function depositsOf(address _payee) public view returns (uint256) {
    return deposits[_payee];
  }

  /**
  * @dev Stores the sent amount as credit to be withdrawn.
  * @param _payee The destination address of the funds.
  */
  function deposit(address _payee) public onlyOwner payable {
    uint256 amount = msg.value;
    deposits[_payee] = deposits[_payee].add(amount);

    emit Deposited(_payee, amount);
  }

  /**
  * @dev Withdraw accumulated balance for a payee.
  * @param _payee The address whose funds will be withdrawn and transferred to.
  */
  function withdraw(address _payee) public {
    uint256 payment = deposits[_payee];
    assert(address(this).balance >= payment);

    deposits[_payee] = 0;

    _payee.transfer(payment);

    emit Withdrawn(_payee, payment);
  }
}

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

/**
 * @title RefundEscrow
 * @dev Escrow that holds funds for a beneficiary, deposited from multiple parties.
 * The contract owner may close the deposit period, and allow for either withdrawal
 * by the beneficiary, or refunds to the depositors.
 */
contract RefundEscrow is Ownable, ConditionalEscrow {
  enum State { Active, Refunding, Closed }

  event Closed();
  event RefundsEnabled();

  State public state;
  address public beneficiary;

  /**
   * @dev Constructor.
   * @param _beneficiary The beneficiary of the deposits.
   */
  constructor(address _beneficiary) public {
    require(_beneficiary != address(0));
    beneficiary = _beneficiary;
    state = State.Active;
  }

  /**
   * @dev Stores funds that may later be refunded.
   * @param _refundee The address funds will be sent to if a refund occurs.
   */
  function deposit(address _refundee) public payable {
    require(state == State.Active);
    super.deposit(_refundee);
  }

  /**
   * @dev Allows for the beneficiary to withdraw their funds, rejecting
   * further deposits.
   */
  function close() public onlyOwner {
    require(state == State.Active);
    state = State.Closed;
    emit Closed();
  }

  /**
   * @dev Allows for refunds to take place, rejecting further deposits.
   */
  function enableRefunds() public onlyOwner {
    require(state == State.Active);
    state = State.Refunding;
    emit RefundsEnabled();
  }

  /**
   * @dev Withdraws the beneficiary's funds.
   */
  function beneficiaryWithdraw() public {
    require(state == State.Closed);
    beneficiary.transfer(address(this).balance);
  }

  /**
   * @dev Returns whether refundees can withdraw their deposits (be refunded).
   */
  function withdrawalAllowed() public view returns (bool) {
    return state == State.Refunding;
  }
}


// Crowdsale

/**
 * @title CaleroController
 */
contract CaleroController is Multiownable {
    using SafeERC20 for CLERInterface;

    CLERInterface public token;
    CrowdsaleInterface public crowdsale;

    event EthReceived(uint256 weiAmount);
    event LockedTokenAddresses(address teamTokensAddress, address contributorsTokensAddress);

    /**
     * @dev Constructor
     */
    constructor() public {
        token = CLERInterface(TokenDeployer.deployTokenContract());
    }

    function() external payable {
        emit EthReceived(msg.value);
    }

    function initCrowdsale() external onlyManyOwners {
        crowdsale = CrowdsaleInterface(CrowdsaleDeployer.deployCrowdsaleContract(address(token)));

        uint256 tokensForCrowdsale = 60000000 * 1 ether;        // 40% or 60mln
        token.safeTransfer(address(crowdsale), tokensForCrowdsale);   // Transfer the crowdsale tokens to crowdsale contract
    }

    function startPhase(uint256 _tokens, uint256 _bonus, uint256 _startDate, uint256 _finishDate) external onlyManyOwners {
        crowdsale.startPhase(_tokens, _bonus, _startDate, _finishDate);
    }

    function finalizeCrowdsale(address _companyReserveTokensWallet, address _teamTokensWallet, address _contributorsTokensWallet) external onlyManyOwners {
        crowdsale.finalizeCrowdsale();
        _distributeStayedTokens(_companyReserveTokensWallet, _teamTokensWallet, _contributorsTokensWallet);
    }

    function _distributeStayedTokens(address _teamTokensWallet, address _contributorsTokensWallet, address _companyReserveTokensWallet) internal {
        uint256 teamTokensAmaunt = 30000000 * 1 ether;             // 30mln / 20% of total supply
        uint256 contributorsTokensAmaunt =  30000000 * 1 ether;    // 30mln / 20% of total supply
        uint256 companyReserveTokens =  30000000 * 1 ether;        // 30mln / 20% of total supply

        // Create timelock contract for team and contributors tokens
        address lockedTeamTokens = new TokenTimelock(IERC20(token), _teamTokensWallet, block.timestamp + 365 days);
        address lockedContributorsTokens = new TokenTimelock(IERC20(token), _contributorsTokensWallet, block.timestamp + 60 days);

        token.safeTransfer(lockedTeamTokens, teamTokensAmaunt);
        token.safeTransfer(lockedContributorsTokens, contributorsTokensAmaunt);
        token.safeTransfer(_companyReserveTokensWallet, companyReserveTokens);
    }

    // Token / ETH transfers

    function transferEther(address _beneficiary, uint256 _amount) external onlyManyOwners {
        require(_beneficiary != address(0));
        require(_amount >= 0);

        _beneficiary.transfer(_amount);
    }

    function transferTokensToNonETHBuyers(address _beneficiary, uint256 _tokens, uint256 _usdReceived) external onlyManyOwners {
        crowdsale.transferTokensToNonETHBuyers(_beneficiary, _tokens, _usdReceived);
    }


    // Token features

    function transferERC20(address _token, address _beneficiary, uint256 _amount) external onlyManyOwners {
        require(_token != address(0));
        require(_beneficiary != address(0));
        require(_amount >= 0);

        crowdsale.transferERC20(_token, _beneficiary, _amount);
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
}

/**
 * @title Bonus lock contract, where will funds bonus of investors
 */
contract BonusLock is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // ERC20 basic token contract being held
    IERC20 private token;

    struct Investor {
        uint256 bonusTokens;
        uint256 releaseDate;
    }

    mapping(address => Investor) public investors;

    event BonusTokensReleased(address beneficiary, uint256 tokensAmaunt);

    constructor(IERC20 _token) public {
        token = _token;
    }

    function addBonus(address _beneficiary, uint256 _bonusTokens) public onlyOwner {
        investors[_beneficiary] = Investor(_bonusTokens, block.timestamp.add(90 days));
    }

    function releaseTokens(address _beneficiary) public {
        require(msg.sender == _beneficiary);
        require(block.timestamp >= investors[_beneficiary].releaseDate, "You can not release your bonus tokens now");

        uint256 amount = investors[_beneficiary].bonusTokens;
        require(amount > 0);

        investors[_beneficiary].bonusTokens = 0;
        token.safeTransfer(_beneficiary, amount);

        emit BonusTokensReleased(_beneficiary, amount);
    }
}

/**
 * @title Calero project crowdsale smart contract
 */
contract CaleroICO is Ownable, CrowdsaleInterface {
    using SafeMath for uint256;

    uint256 public pricePerToken = 40; // 1 CLER - 40 cents or $0.4
    uint256 public weiRaised;
    uint256 public usdRaised;
    uint256 public tokensSold;

    uint256 public softCap = 500000;    // softcap is $500k
    uint256 public hardCap = 10000000;  // hardcap is $10mln

    uint256 public stage = 0;
    uint256 public minContributionAmount = 10 ** 17; // 0.1 ETH

    bool public softCapReached = false;
    bool public hardCapReached = false;
    bool public finalizeIsAvailable = true;

    CLERInterface public token;
    EthPriceOraclize public oraclize;
    RefundEscrow public vault;

    event TokenPurchase(address purchaser, address beneficiary, uint256 value, uint256 amount);
    event StageStarted(uint256 tokens, uint256 bonus, uint256 startDate, uint256 finishDate);
    event StageFinished(uint256 time);
    event SoftCapReached(uint256 time);
    event HardCapReached(uint256 time);

    struct Ico {
        uint256 tokens;
        uint256 bonus;
        uint256 startDate;
        uint256 finishDate;
        bool finished;
    }
    Ico public ICO;
    BonusLock public bonusContract;

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
        token = CLERInterface(_tokenAddress);
        vault = VaultDeployer.deployVaultContract(msg.sender);
        oraclize = OraclizeDeployer.deployOraclize();
        bonusContract = new BonusLock(IERC20(token));
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

        require(ICO.tokens >= tokens);

        if(ICO.bonus != 0) {
            uint256 bonus = _getBonus(tokens);
            require(ICO.tokens >= tokens.add(bonus));
            bonusContract.addBonus(_beneficiary, bonus);
        }

        usdAmount = usdAmount.div(100); // Removing cents after whole calculation

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
        require(_weiAmount >= minContributionAmount, "_preValidatePurchase: ETH amount is smaller than the minimum contribution amount");
    }

    /**
     * @dev Get usd price of ETH which contributor send
     * @param _weiAmount Value in wei involved in the purchase
     */
    function _getUSDETHPrice(uint256 _weiAmount) internal view returns(uint256) {
        uint256 usdAmountOfETH = _weiAmount.mul(oraclize.getEthPrice()).div(1 ether);
        return usdAmountOfETH;
    }

    /**
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param _usdPrice Value in wei to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _usdPrice
     */
    function _getTokenAmount(uint256 _usdPrice) internal view returns(uint256) {
        uint256 tokensAmaunt = _usdPrice.div(pricePerToken).mul(1 ether);
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
        } else if(usdRaised == hardCap) {
            hardCapReached = true;

            emit HardCapReached(now);
        }
    }

    /**
     * @dev Start crowdsale phase
     */
    function startPhase(uint256 _tokens, uint256 _bonus, uint256 _startDate, uint256 _finishDate) external onlyOwner {
        require(_tokens <= token.balanceOf(this), "startPhase: amount of tokens is not enough for start");
        require(_startDate != 0 && _finishDate != 0, "startPhase: finishdate/startdate are not correct");
        require(_bonus < 100, "startPhase: the bonus size should be smaller of 100");

        ICO = Ico(_tokens, _bonus, _startDate, _finishDate, false);
        stage = stage.add(1);

        emit StageStarted(_tokens, _bonus, _startDate, _finishDate);
    }

    /**
     * @dev Finish the crowdsale, enable refund or send all money to owner address
     */
    function finalizeCrowdsale() external onlyOwner {
        require(finalizeIsAvailable, "finalizeCrowdsale: finalize is not available yet");
        require(stage == 3, "finalizeCrowdsale: finalize is not available yet");

        finalizeIsAvailable = false;

        if (softCapReached == true) {
            vault.close();
        } else {
            vault.enableRefunds();
        }
        stage = stage.add(1);
        token.burn(token.balanceOf(this));
    }

    function transferTokensToNonETHBuyers(address _beneficiary, uint256 _tokens, uint256 _usdReceived) external onlyOwner {
        require(_beneficiary != address(0));
        require(_tokens > 0);
        require(_usdReceived > 0);

        _deliverTokens(_beneficiary, _tokens);
        _updatePurchasingState(_tokens, 0, _usdReceived);

        _postValidatePurchase();
    }

    function transferERC20(address _token, address _beneficiary, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(_beneficiary, _amount);
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
}