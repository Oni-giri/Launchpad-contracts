const LaunchpadMaster = artifacts.require('LaunchpadMaster');
const LaunchpadChild = artifacts.require('LaunchpadChild');
const MockERC20 = artifacts.require('MockERC20');

module.exports = async function (deployer) {
  // store the first three acounts in variables
  const owner = '0x1a0d5527F6a7C40D17236AA0565b830E28D004Ce';
  const user1 = '0xec7cdE35e5D9AcC71c1007EbcdD1f6A83C83536b';

  console.log('deploying master');
  let master = await LaunchpadMaster.at('0x71DA145395551aB4f9a36a6344D7a2cCA539Ecf3');
  console.log('master deployed');

  deployer.deploy(MockERC20, 'mock', 'MK', 1e18);
  let token = await MockERC20.deployed();
  console.log('token deployed');

  const now = Math.floor(Date.now() / 1000);
  let child = await master.createPresale(
    token.address,
    'presale',
    'presale.png',
    // [1000000000000000,10000000,3000,100000000000000000,1648221071,1648221081000,6000000000000000,100000000000000]
    [1e24, 1e7, 3000, 1e17, now + 5, now + 15, 6e16, 1e14],
    false,
    0,
    0,
    '0x10ED43C718714eb63d5aA57B78B54704E256024E',
    { value: 1e17 }
  );
  await LaunchpadChild.at(child);
};

// [1000000000000000,10000000,3000,100000000000000000,1648221071,16482210810,6000000000000000,100000000000000]
// 16482210820
// 0x3b00ef435fa4fcff5c209a37d1f3dcff37c705ad

// "0x3b00ef435fa4fcff5c209a37d1f3dcff37c705ad",
//           "test",
//           "test.png",
//           [
//             1000000000000000,
//             "10000000",
//             3000,
//             "100000000000000000",
//             1648221071,
//             "16482210810",
//             6000000000000000,
//             100000000000000
//           ],
//           false,
//           "0",
//           "16482210820",
//           "0x3b00ef435fa4fcff5c209a37d1f3dcff37c705ad"
