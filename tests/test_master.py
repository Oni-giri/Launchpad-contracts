import pytest
import brownie
from brownie import accounts, LaunchpadMaster, LaunchpadChild, interface, MockERC20
from brownie import MockERC20WithFees
import time
from utils.test_utils import mine_at


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
        {"from": deployer, "value": 1e17}
    )

    return LaunchpadChild.at(childTx.return_value)


@pytest.fixture(scope="function")
def childFeeToken(deployer, master, signer, feeERC20, now):
    childTx = LaunchpadMaster.createPresale(
        feeERC20,
        "presale",
        "presale.png",
        [900_000e18,  # _tokenTotalAmount
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
        {"from": deployer, "value": 1e17}
    )

    return LaunchpadChild.at(childTx.return_value)


@pytest.fixture(scope="function")
def childWhitelist(deployer, master, signer, simpleERC20, now):
    childTx = LaunchpadMaster.createPresale(
        feeERC20,
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
        True,  # _whitelistEnabled
        now,  # _wlStartTime
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
    assert child.listingTokensPerOneEth() == 10_000_000
    assert child.liquidityShareBP() == 3000
    assert child.hardcap() == 1e17
    assert child.startTime() == now + 5
    assert child.endTime() == now + 15
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

    assert master.saleIdToAddress(0) == child.address
    assert master.addressToSaleId(child) == 0


def test_finalizeSale(master, child, simpleERC20, deployer):
    with brownie.reverts("insufficient amount of tokens sent to the address"):
        child.finalizeSale({"from": deployer})

    assert simpleERC20.balanceOf(deployer) == 1_000_000e18
    simpleERC20.transfer(child, 1_000_000e18, {"from": deployer})
    assert simpleERC20.balanceOf(child) == 1_000_000e18
    child.finalizeSale({"from": deployer})
    assert child.saleFinalized() == True


def test_buyTokensPublic(master, child, simpleERC20, deployer, alice, bob, now):
    mine_at(now)
    # Prep the sale
    simpleERC20.transfer(child, 1_000_000e18, {"from": deployer})

    with brownie.reverts("sale hasn't been finalized yet"):
        child.buyTokensPublic({"from": alice, "value": 6e16})

    child.finalizeSale({"from": deployer})
    assert child.saleFinalized() == True

    with brownie.reverts("sale hasn't started yet"):
        child.buyTokensPublic({"from": alice, "value": 1e15})

    mine_at(now+6)
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

    child.buyTokensPublic({"from": bob, "value": 4e16})


def test_abortSale(master, child, simpleERC20, deployer, alice, bob, now):
    # Prep the sale
    simpleERC20.transfer(child, 1_000_000e18, {"from": deployer})
    child.finalizeSale({"from": deployer})

    mine_at(now+6)
    child.buyTokensPublic({"from": bob, "value": 1e16})
    child.abortSale({"from": deployer})
    with brownie.reverts("sale was aborted"):
        child.buyTokensPublic({"from": bob, "value": 1e16})
    with brownie.reverts("sale was aborted, please use claimStaleEth() function"):
        child.claimTokens({"from": bob})


def test_endSaleAllowClaim(master, child, simpleERC20, deployer, feesWallet, alice, bob, now):
    # Prep the sale
    simpleERC20.transfer(child, 1_000_000e18, {"from": deployer})

    with brownie.reverts("sale wasn't finalized"):
        child.endSaleAllowClaim({"from": deployer})

    child.finalizeSale({"from": deployer})
    mine_at(now+6)
    child.buyTokensPublic({"from": bob, "value": 1e16})
    with brownie.reverts("not enough tokens were sold"):
        child.endSaleAllowClaim({"from": deployer})

    child.buyTokensPublic({"from": bob, "value": 5e16})
    saleBal = child.balance()
    deployBal = deployer.balance()
    feesBal = feesWallet.balance()

    child.endSaleAllowClaim({"from": deployer})
    assert child.saleEnded() == True
    assert 0 == child.balance()
    assert deployBal < deployer.balance()
    assert feesBal < feesWallet.balance()
    router = interface.IUniswapV2Router02(child.router())
    factory = interface.IUniswapV2Factory(router.factory())
    pair = interface.IUniswapV2Pair(factory.getPair(simpleERC20, router.WETH()))
    assert pair.totalSupply() > 1;


def test_claimStaleEth1(master, child, simpleERC20, deployer, alice, bob, now):
    # Prep the sale
    simpleERC20.transfer(child, 1_000_000e18, {"from": deployer})
    child.finalizeSale({"from": deployer})
    mine_at(now+6)
    child.buyTokensPublic({"from": bob, "value": 1e16})

    child.abortSale({"from": deployer})

    before = bob.balance()
    child.claimStaleEth({"from": bob})
    assert bob.balance() > before
    assert child.userBuyAmount(bob) == 0

    with brownie.reverts("user hasn't any tokens to claim"):
        child.claimStaleEth({"from": bob})


def test_claimStaleEth2(master, child, simpleERC20, deployer, alice, bob, now):
    # Prep the sale
    simpleERC20.transfer(child, 1_000_000e18, {"from": deployer})
    child.finalizeSale({"from": deployer})
    mine_at(now+6)
    child.buyTokensPublic({"from": bob, "value": 6e16})

    mine_at(now+86500)
    before = bob.balance()
    child.claimStaleEth({"from": bob})
    assert bob.balance() > before
    assert child.userBuyAmount(bob) == 0
    with brownie.reverts("user hasn't any tokens to claim"):
        child.claimStaleEth({"from": bob})


def test_claimStaleEth3(master, child, simpleERC20, deployer, alice, bob, now):
    # Prep the sale
    simpleERC20.transfer(child, 1_000_000e18, {"from": deployer})
    child.finalizeSale({"from": deployer})
    mine_at(now+6)
    child.buyTokensPublic({"from": bob, "value": 1e16})

    mine_at(now+30)
    before = bob.balance()
    child.claimStaleEth({"from": bob})
    assert bob.balance() > before
    assert child.userBuyAmount(bob) == 0
    with brownie.reverts("user hasn't any tokens to claim"):
        child.claimStaleEth({"from": bob})


def test_claimTokensClassic(master, child, simpleERC20, deployer, alice, bob, now):
    # Prep the sale
    simpleERC20.transfer(child, 1_000_000e18, {"from": deployer})
    child.finalizeSale({"from": deployer})
    mine_at(now+6)
    child.buyTokensPublic({"from": bob, "value": 6e16})

    with brownie.reverts("initiator hasn't ended the sale yet"):
        child.claimTokens({"from": bob})

    child.endSaleAllowClaim({"from": deployer})

    mine_at(now+20)
    before = simpleERC20.balanceOf(bob)
    child.claimTokens({"from": bob})
    assert simpleERC20.balanceOf(
        bob) - before == 6e16 * child.saleTokensPerOneEth()
