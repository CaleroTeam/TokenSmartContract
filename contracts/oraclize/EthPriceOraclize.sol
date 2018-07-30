pragma solidity ^0.4.24;

import "./usingOraclize.sol";

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