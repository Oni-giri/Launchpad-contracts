from brownie import accounts, LaunchpadMaster, LaunchpadChild, interface, mockERC20
import time


def main():

    deployer = accounts[0];
    feesWallet = accounts[1];
    print(f"Balance of account is {deployer.balance()}")
    token = mockERC20.deploy("mock", "MK", 1_000_000e18, {"from":deployer})
    master = LaunchpadMaster.deploy(500, 0, deployer, feesWallet, 1e17, {"from":deployer})
    now = round(time.time())
    childAddress = master.createPresale(
                token,
                "This is a presale", 
                "presale.png",
                [1_000_000_000e18, # _tokenTotalAmount
                5_000_000, # _listingTokensPerOneEth
                3000, # _liquidityShare
                1e17,
                now+20,
                now+300,
                1e16,
                1e14
                ],
                False,
                0,
                0,
                "0x10ED43C718714eb63d5aA57B78B54704E256024E", 
                {"from":deployer, "value":1e17})
    


