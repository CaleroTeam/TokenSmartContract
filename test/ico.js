let utils = require('./utils.js')

let ico = artifacts.require('CaleroICO');
let token = artifacts.require('CaleroToken');

let icoInstance;
let tokenInstance;

let stage;
let contractDecimals;
let tokensSold;
let buyPrice;

let ICOdeadLine;
let softcap;
let hardcap;
let availableTokens;

let contributors;

contract('Calero ICO', accounts => {
    before(async () => {
        tokenInstance = await token.new();
        icoInstance = await ico.new(tokenInstance.address);

        await utils.increaseTime(dateToEpoch("2018-04-20") + 1);

        contractDecimals = await tokenInstance.decimals.call();
        decimals = 10 ** contractDecimals.toNumber();
    });

    it('Test initialization', async () => {
        stage = await icoInstance.stage.call();
        assert.equal(stage, 0, '0 stage');

        tokensSold = await icoInstance.tokensSold.call();
        assert.equal(tokensSold, 0, '0 tokens sold');

        buyPrice = await icoInstance.buyPrice.call();
        assert.equal(buyPrice, 0.001 * decimals, 'Buy price is 0.001 ETH');

        ICOdeadLine = await icoInstance.ICOdeadLine.call();
        assert.equal(ICOdeadLine, 1538082000, 'ICO finish time - 28 September 2018, 00:00:00');

        softcap = await icoInstance.softcap.call();
        assert.equal(softcap, 1600000 * decimals, 'Softcap');

        hardcap = await icoInstance.hardcap.call();
        assert.equal(hardcap, 50000000 * decimals, 'Hardcap');

        availableTokens = 0;

    });

    it('Should send tokens from owner to smart contract', async () => {
        let balance = await tokenInstance.balanceOf.call(accounts[0]);
        let result = await tokenInstance.transfer(icoInstance.address, balance, { from: accounts[0] });
        var event = result.logs[0].args;

        assert.equal(event.from, accounts[0]);
        assert.equal(event.to, icoInstance.address);
        assert.equal(event.value, balance.toNumber());

        balance = await tokenInstance.balanceOf.call(icoInstance.address);
        assert.equal(balance, hardcap.toNumber(), 'Crowdsale tokens on ico smart contract balance')

        balance = await tokenInstance.balanceOf.call(accounts[0]);
        assert.equal(balance, 0, 'Deployer (owner) hasnt tokens')
    });

    it('Should failed payable function before crowdsale', async () => {
        try {
            await web3.eth.sendTransaction({ from: accounts[1], to: icoInstance.address, value: web3.toWei(30, "ether") })
            assert.fail("Should have failed");
        } catch (error) {
            assertVMError(error);
        }
    });

    it('Should start crowdsale', async () => {
        let event = await icoInstance.startCrowd(20000000 * decimals, dateToEpoch("2018-04-20"), dateToEpoch("2018-04-25"), 40);
        let result = event.logs[0].args;

        let scBal = await tokenInstance.balanceOf.call(icoInstance.address);
        
        assert.equal(result.tokens.toNumber(), 20000000 * decimals, 'Tokens equal');
        assert.equal(result.startDate.toNumber(), 1524182400, 'Start date');
        assert.equal(result.endDate.toNumber(), 1524614400, 'End date');
        assert.equal(result.bonus.toNumber(), 40, 'End date');
        assert.equal(scBal.toNumber(), 50000000 * decimals, 'Smart contract balance');
    });
})

function assertVMError(error) {
    if (error.message.search('VM Exception') == -1) console.log(error);
    assert.isAbove(error.message.search('VM Exception'), -1, 'Error should have been caused by EVM');
}

const dateToEpoch = function (date) {
    return new Date(date).getTime() / 1000;
};