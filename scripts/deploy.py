from brownie import accounts, LaunchpadMaster, LaunchpadChild, interface, MockERC20
import time


def main():

    deployer = accounts[0]
    feesWallet = accounts[1]
    print(f"Balance of account is {deployer.balance()}")
    token = MockERC20.deploy("mock", "MK", 1_000_000e18, {"from": deployer})
    master = LaunchpadMaster.deploy(
        500, 0,"0x66666666f823add319d99db0deb95cbaf762b693", feesWallet, 1e17, {"from": deployer})
    now = round(time.time())
    childAddress = master.createPresale(
        token,
        "presale",
        "presale.png",
        [1_000_000e18,  # _tokenTotalAmount
         10_000_000,  # _listingTokensPerOneEth
         3000,  # _liquidityShare
         1e17,  # _hardcap
         now+5,  # _startTime
         now+15,  # _endTime
         6e16,  # _maxBuyPerUser
         1e14  # _minBuyPerUser
         ],
        False,  # _whitelistEnabled
        0,  # _wlStartTime
        0,  # _liquidityLockDuration
        "0x10ED43C718714eb63d5aA57B78B54704E256024E",  # _router
                {"from": deployer, "value": 1e17})
    child = LaunchpadChild.at(LaunchpadChild)
    # // recipient.call{value: (totalBuyEth * feeBP) / 10000}("");
    # // payable(msg.sender).call{value: address(this).balance}("");

# child.verify("0x7d07d165018bec693675073b0e7b816c4ab4252c9ec9ec2cc7925369980cee3f479f55213818238fc531cdccd5b6b83b800a463c210c77e26e7d597bf8a42ce51c", "0x66666666f823add319d99db0deb95cbaf762b693", 0, 56)