let Calero = artifacts.require("CaleroToken");

let instance;
let totalSupply;
let availableTokens;

let teamWalletAddress = "0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C";

contract("Calero token", accounts => {
    before(async () => {
        instance = await Calero.deployed();

        let contractDecimals = await instance.decimals.call();
        decimals = 10 ** contractDecimals.toNumber();
    });

    it("First distribution initialization", async () => {
        totalSupply = await instance.totalSupply();
        assert.equal(totalSupply, 100000000 * decimals, 'Total supply');

        let balance = await instance.balanceOf.call(accounts[0]);
        assert.equal(balance, 50000000 * decimals, 'Owner tokens');

        let bal = await instance.balanceOf.call(accounts[1]);
        assert.equal(bal, 0, 'balance');

        let allowance = await instance.allowance(accounts[0], accounts[1]);
        assert.equal(allowance, 0, 'allowed');

        let lockedTokensContractAddress = await instance.lockedTeamTokensAddress.call();
        let balanceTeamLocked = await instance.balanceOf.call(lockedTokensContractAddress);
        assert.equal(balanceTeamLocked, 20000000 * decimals, 'team lock tokens');

        let balanceTeamWallet = await instance.balanceOf.call(teamWalletAddress);
        assert.equal(balanceTeamWallet, 0, 'team tokens');
    });

    it("Should allow account1 to spend 10 tokens", async () => {
        let result = await instance.approve(accounts[1], 10 * decimals);
        let event = result.logs[0].args;
        assert.equal(event.owner, accounts[0]);
        assert.equal(event.spender, accounts[1]);
        assert.equal(event.value, 10 * decimals);

        let allowed = await instance.allowance.call(accounts[0], accounts[1]);
        assert.equal(allowed, 10 * decimals);
    });

    it("Should set back allowance to 0 and then allow account1 to spend 20 tokens", async () => {
        await instance.approve(accounts[1], 0);
        allowed = await instance.allowance.call(accounts[0], accounts[1]);
        assert.equal(allowed, 0);

        await instance.approve(accounts[1], 20 * decimals);
        allowed = await instance.allowance.call(accounts[0], accounts[1]);
        assert.equal(allowed, 20 * decimals);
    });

    it("Should reduce the allowance by 5 tokens", async () => {
        await instance.decreaseApproval(accounts[1], 5 * decimals);
        allowed = await instance.allowance.call(accounts[0], accounts[1]);
        assert.equal(allowed, 15 * decimals);
    });

    it("Should reduce the allowance to 0", async () => {
        await instance.decreaseApproval(accounts[1], 25 * decimals);
        allowed = await instance.allowance.call(accounts[0], accounts[1]);
        assert.equal(allowed, 0);
    });

    it("Should increase the allowance to 10 tokens", async () => {
        await instance.increaseApproval(accounts[1], 7 * decimals);
        allowed = await instance.allowance.call(accounts[0], accounts[1]);
        assert.equal(allowed, 7 * decimals);

        await instance.increaseApproval(accounts[1], 3 * decimals);
        allowed = await instance.allowance.call(accounts[0], accounts[1]);
        assert.equal(allowed, 10 * decimals);
    });

    it("Should fail to transfer 20 tokens from the account0 to account1", async () => {
        try {
            let result = await instance.transferFrom(accounts[0], accounts[1], 20 * decimals, { from: accounts[1] });
            console.log(result);
            assert.fail("Should have failed");
        } catch (error) {
            assertVMError(error);
        }
    });

    it("Should fail to transfer 10 tokens from the account0 to account1 because of wrong sender", async () => {
        try {
            let result = await instance.transferFrom(accounts[0], accounts[1], 10 * decimals, { from: accounts[2] });
            assert.fail("Should have failed");
        } catch (error) {
            assertVMError(error);
        }
    });

    it("Should transfer 10 tokens from account0 to account1", async () => {
        let result = await instance.transferFrom(accounts[0], accounts[1], 10 * decimals, { from: accounts[1] });
        let event = result.logs[0].args;

        assert.equal(event.from, accounts[0]);
        assert.equal(event.to, accounts[1]);
        assert.equal(event.value, 10 * decimals);

        let bal = await instance.balanceOf.call(accounts[0]);
        assert.equal(bal.toNumber(), 49999990 * decimals, 'Account1 balance after transfer');

        let balance = await instance.balanceOf.call(accounts[1]);
        assert.equal(balance, 10 * decimals);

        let allowance = await instance.allowance(accounts[0], accounts[1]);
        assert.equal(allowance, 0);
    });

    it("Should transfer 10 tokens from account1 to account2", async () => {
        let result = await instance.transfer(accounts[2], 10 * decimals, { from: accounts[1] });
        var event = result.logs[0].args;

        assert.equal(event.from, accounts[1]);
        assert.equal(event.to, accounts[2]);
        assert.equal(event.value, 10 * decimals);

        let balance = await instance.balanceOf.call(accounts[2]);
        assert.equal(balance, 10 * decimals);

        let bal = await instance.balanceOf.call(accounts[1]);
        assert.equal(bal.toNumber(), 0);
    });

    it("Should fail to transfer from account1 because of insufficient funds", async () => {
        try {
            let result = await instance.transfer(accounts[2], 60 * decimals, { from: accounts[1] });
            assert.fail("Should have failed");
        } catch (error) {
            assertVMError(error);
        }
    });

    it("Should fail to transfer to 0x0", async () => {
        let initialBalance = await instance.balanceOf.call(accounts[0]);
        try {
            let result = await instance.transfer("0x0", 1 * decimals);
            assert.fail("Should have failed");
        } catch (error) { 
            assertVMError(error);
        }
        await instance.increaseApproval(accounts[1], 1 * decimals);
        try {
            let result = await instance.transferFrom(accounts[0], "0x0", 1 * decimals);
            assert.fail("Should have failed");
        } catch (error) { 
            assertVMError(error);
        }

        let balance = await instance.balanceOf.call(accounts[0]);
        assert.equal(balance.toNumber(), initialBalance.toNumber());

        let balance2 = await instance.balanceOf.call(accounts[1]);
        assert.equal(balance2.toNumber(), 0);
    });

    it("Should burn a tokens from account2", async () => {
        let bal = await instance.balanceOf.call(accounts[2]);
        assert.equal(bal, 10 * decimals, 'Account2 balance');

        let result = await instance.burn(bal, { from: accounts[2] });
        let event = result.logs[0].args;
        assert.equal(event.value.toNumber(), bal, "All tokens burned");
        assert.equal(event.burner, accounts[2], "Owner burn his tokens");
    });
})

function assertVMError(error) {
    if (error.message.search('VM Exception') == -1) console.log(error);
    assert.isAbove(error.message.search('VM Exception'), -1, 'Error should have been caused by EVM');
}