import pytest
import brownie
from brownie import accounts, LaunchpadMaster, LaunchpadChild, interface, mockERC20

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
def signer():
    return ("0x9a68219f2043f84c6f53585a25ada91cbd5f24727912942a3a05a7981185a44c",
            "0x66666666f823add319d99db0deb95cbaf762b693")

@pytest.fixture(scope="function")
def masterContract(deployer, feesWalle, signer):
    return LaunchpadMaster.deploy(
        500, # feesBP
        0,  # startSaleId
        signer[1], # signer 
        feesWallet, # feesWallet
        1e17, # deploy fee
        {"from":deployer})

