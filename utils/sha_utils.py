import sha3
from web3 import Web3
from web3.auto import w3
from eth_account.messages import encode_defunct


def keccak256(_string):
    k = sha3.keccak_256()
    k.update(str.encode(_string))
    return k.hexdigest()


def sign_message(message_hex, private_key):
    message_eth_signed = encode_defunct(hexstr=message_hex)
    message_signed = w3.eth.account.sign_message(message_eth_signed, private_key=private_key)
    return message_signed