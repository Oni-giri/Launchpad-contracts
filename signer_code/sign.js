const ethers = require('ethers');

const provider = new ethers.providers.JsonRpcProvider('http://localhost:8545');
// Pas la peine d'essayer, c'est une clé privée de test
const wallet = new ethers.Wallet('0x9a68219f2043f84c6f53585a25ada91cbd5f24727912942a3a05a7981185a44c');
console.log('Wallet:', wallet.address);

const target = '0xEB3FCc95E09baD8e53C8886AFBCEc8e6Aff9f626';
const saleId = 0;
const chainId = 57;

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

// results:
// solidity: 0x5988c913cac8d37dd289548ddaa90b74bc3d4cdb2667d6d881984628b25d7d20
// ethers: 0x5988c913cac8d37dd289548ddaa90b74bc3d4cdb2667d6d881984628b25d7d20

console.log('\n\n\n');
console.log('solidity: 0x5988c913cac8d37dd289548ddaa90b74bc3d4cdb2667d6d881984628b25d7d20');
console.log('ethers: ' + messageHash);
console.log('match: ' + (0x5988c913cac8d37dd289548ddaa90b74bc3d4cdb2667d6d881984628b25d7d20 == messageHash));
