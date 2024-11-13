const Wallet = artifacts.require("Wallet")
const Dex = artifacts.require("Dex")

module.exports = function(deployer){
    deployer.deploy(Wallet)
    deployer.deploy(Dex)
} 