from brownie import accounts, LaunchpadMaster, LaunchpadChild, interface, mockERC20



def main():

    deployer = accounts[0];
    feesWallet = accounts[1];
    print(f"Balance of account is {deployer.balance()}")
    token = mockERC20.deploy("mock", "MK", 1_000_000e18, {"from":deployer})
    master = LaunchpadMaster.deploy(500, 0, deployer, feesWallet, 1e17, {"from":deployer})
    
    
