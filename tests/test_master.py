import pytest
import brownie
from brownie import accounts, LaunchpadMaster, LaunchpadChild, interface, MockERC20, MockERC20WithFees
import time


@pytest.fixture(scope="function")
def deployer():
    return accounts[0]


@pytest.fixture(scope="function")
def alice():
    return accounts[1]


@pytest.fixture(scope="function")
def bob():
    return accounts[2]


@pytest.fixture(scope="function")
def feesWallet():
    return accounts[3]


@pytest.fixture(scope="function")
def now():
    return round(time.time())


@pytest.fixture(scope="function")
def signer():
    return ("0x9a68219f2043f84c6f53585a25ada91cbd5f24727912942a3a05a7981185a44c",
            "0x66666666f823add319d99db0deb95cbaf762b693")


@pytest.fixture(scope="function")
def master(deployer, feesWallet, signer):
    return LaunchpadMaster.deploy(
        500,  # feesBP
        0,  # startSaleId
        signer[1],  # signer
        feesWallet,  # feesWallet
        1e17,  # deploy fee
        {"from": deployer})


@pytest.fixture(scope="function")
def simpleERC20(deployer):
    return MockERC20.deploy(
        "mock", "MK", 1_000_000e18, {"from": deployer}
    )


@pytest.fixture(scope="function")
def feeERC20(deployer):
    return MockERC20withFees.deploy(
        "mock", "MK", 1_000_000e18, {"from": deployer}
    )


@pytest.fixture(scope="function")
def child(deployer, master, signer, simpleERC20, now):
    childTx = master.createPresale(
        simpleERC20,
        "presale",
        "presale.png",
        [1_000_000e18,  # _tokenTotalAmount
         5_000,  # _listingTokensPerOneEth
         3000,  # _liquidityShare
         1e17,  # _hardcap
         now+5,  # _startTime
         now+20,  # _endTime
         6e16,  # _maxBuyPerUser
         1e14  # _minBuyPerUser
         ],
        False,  # _whitelistEnabled
        0,  # _wlStartTime
        0,  # _liquidityLockDuration
        "0x10ED43C718714eb63d5aA57B78B54704E256024E",  # _router
        {"from": deployer, "value": 1e17}
    )

    return LaunchpadChild.at(childTx.return_value)


@pytest.fixture(scope="function")
def childFeeToken(deployer, master, signer, feeERC20, now):
    childTx = LaunchpadMaster.createPresale(
        feeERC20,
        "presale",
        "presale.png",
        [1_000_000e18,  # _tokenTotalAmount
         5_000,  # _listingTokensPerOneEth
         3000,  # _liquidityShare
         1e17,  # _hardcap
         now+5,  # _startTime
         now+20,  # _endTime
         6e16,  # _maxBuyPerUser
         1e14  # _minBuyPerUser
         ],
        False,  # _whitelistEnabled
        0,  # _wlStartTime
        0,  # _liquidityLockDuration
        "0x10ED43C718714eb63d5aA57B78B54704E256024E",  # _router
        {"from": deployer, "value": 1e17}
    )

    return LaunchpadChild.at(childTx.return_value)


def test_constructor(master, signer, feesWallet):
    assert master.currentSaleId() == 0
    assert master.feesBP() == 500
    assert master.startSaleId() == 0
    assert master.deployFee() == 1e17
    assert master.signer() == signer[1]
    assert master.feesWallet() == feesWallet


def test_claimFees(master, feesWallet, deployer, alice):
    feeBal = feesWallet.balance()
    deployer.transfer(master, 1e18)
    assert master.balance() == 1e18
    master.claimFees({"from": feesWallet})
    assert master.balance() == 0
    assert feesWallet.balance() > feeBal

    with brownie.reverts("not authorized"):
        master.claimFees({"from": deployer})
    with brownie.reverts("not authorized"):
        master.claimFees({"from": alice})


def test_setSigner(master, deployer, alice, signer):
    assert master.signer() == signer[1]
    master.setSigner(alice, {"from": deployer})
    assert master.signer() == alice

    with brownie.reverts("Ownable: caller is not the owner"):
        master.setSigner(deployer, {"from": alice})


def test_setFeesBP(master, deployer, alice):
    assert master.feesBP() == 500
    master.setFeesBP(1000, {"from": deployer})
    assert master.feesBP() == 1000

    with brownie.reverts("Ownable: caller is not the owner"):
        master.setFeesBP(0, {"from": alice})

    with brownie.reverts("too high"):
        master.setFeesBP(10000, {"from": deployer})


def test_deployFee(master, deployer, alice):
    assert master.deployFee() == 1e17
    master.setDeployFee(1e18)
    assert master.deployFee() == 1e18

    with brownie.reverts("Ownable: caller is not the owner"):
        master.setDeployFee(0, {"from": alice})


def test_childConstructor(master, child, simpleERC20, deployer, now, feesWallet):
    assert child.token() == simpleERC20
    assert child.description() == "presale"
    assert child.imageUrl() == "presale.png"
    assert child.tokenTotalAmount() == 1_000_000e18
    assert child.listingTokensPerOneEth() == 5_000
    assert child.liquidityShareBP() == 3000
    assert child.hardcap() == 1e17
    assert child.startTime() == now + 5
    assert child.endTime() == now + 20
    assert child.whitelistEnabled() == False
    assert child.wlStartTime() == 0
    assert child.router() == "0x10ED43C718714eb63d5aA57B78B54704E256024E"
    assert child.saleInitiator() == deployer
    assert child.feeBP() == 500
    assert child.master() == master
    assert child.recipient() == feesWallet
    assert child.saleId() == 0
    assert child.softcap() == child.hardcap()/2
    assert child.maxBuyPerUser() == 6e16
    assert child.minBuyPerUser() == 1e14


def test_finalizeSale(master, child, simpleERC20, deployer):
    with brownie.reverts("insufficient amount of tokens sent to the address"):
        child.finalizeSale({"from": deployer})

    assert simpleERC20.balanceOf(deployer) == 1_000_000e18
    simpleERC20.transfer(child, 1_000_000e18, {"from": deployer})
    assert simpleERC20.balanceOf(child) == 1_000_000e18
    child.finalizeSale({"from": deployer})
    assert child.saleFinalized() == True


def test_buyTokensPublic(master, child, simpleERC20, deployer, alice, bob):
    # Prep the sale
    simpleERC20.transfer(child, 1_000_000e18, {"from": deployer})

    with brownie.reverts("sale hasn't been finalized yet"):
        child.buyTokensPublic({"from": alice, "value": 6e16})

    child.finalizeSale({"from": deployer})
    assert child.saleFinalized() == True

    with brownie.reverts("sale hasn't started yet"):
        child.buyTokensPublic({"from": alice, "value": 1e15})

    time.sleep(6)
    with brownie.reverts("you're trying to buy too many tokens"):
        child.buyTokensPublic({"from": alice, "value": 1e18})
    with brownie.reverts("you're not sending enough"):
        child.buyTokensPublic({"from": alice, "value": 1e13})

    child.buyTokensPublic({"from": alice, "value": 6e16})
    assert child.userBuyAmount(alice) == 6e16
    assert child.totalBuyEth() == 6e16

    with brownie.reverts("you're trying to buy too many tokens"):
        child.buyTokensPublic({"from": alice, "value": 6e16})
    
    with brownie.reverts("there aren't enough tokens left. Try a lower amount"):
        child.buyTokensPublic({"from": bob, "value": 6e16}) 

