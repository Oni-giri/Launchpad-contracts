const ethers = require('ethers');

const provider = new ethers.providers.JsonRpcProvider('http://localhost:8545');
// Pas la peine d'essayer, c'est une clé privée de test
const wallet = new ethers.Wallet('0x9a68219f2043f84c6f53585a25ada91cbd5f24727912942a3a05a7981185a44c');
console.log('Wallet:', wallet.address);

const target = '0x33A4622B82D4c04a53e170c638B944ce27cffce3';
const saleId = 0;
const chainId = 56;

let payload = ethers.utils.defaultAbiCoder.encode(['address', 'uint256', 'uint256'], [target, saleId, chainId]);
console.log('Payload:', payload);

let payloadHash = ethers.utils.keccak256(payload);
console.log('PayloadHash:', payloadHash);

// bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", payloadHash));
// solidityKeccak256 does both keccak256 and encoding using the thightly packed bytes.
// I have created a small contract over at contracts/testVerify.sol to test this.
let messageHash = ethers.utils.solidityKeccak256(
  ['string', 'bytes32'],
  ['\x19Ethereum Signed Message:\n32', payloadHash]
);

signature = wallet.signMessage(ethers.utils.arrayify(payloadHash));
console.log(signature)