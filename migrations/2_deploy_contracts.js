var token = artifacts.require("./CaleroToken");
var ico = artifacts.require("./CaleroICO");

module.exports = function (deployer) {
    deployer.deploy(token).then( ()=> deployer.deploy(ico, token.address) );
};