const ethers = require("ethers");

const provider = new ethers.providers.JsonRpcProvider("http://localhost:8545")
const wallet = new ethers.Wallet("0x9a68219f2043f84c6f53585a25ada91cbd5f24727912942a3a05a7981185a44c")
console.log("Wallet:", wallet.address);

const target = "0xEB3FCc95E09baD8e53C8886AFBCEc8e6Aff9f626"
const saleId = 0
const chainId = 57

let payload = ethers.utils.defaultAbiCoder.encode([ "address", "uint", "uin" ], [ someHash, someDescr ]);
console.log("Payload:", payload);

let payloadHash = ethers.utils.keccak256(payload);
console.log("PayloadHash:", payloadHash);

let signature = wallet.signMessage(ethers.utils.arrayify(payloadHash));
console.log(signature)
