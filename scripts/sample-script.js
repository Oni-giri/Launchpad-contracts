// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require('hardhat');
const { ethers } = require('ethers');

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');
  const owner = '0x1a0d5527F6a7C40D17236AA0565b830E28D004Ce';
  const user1 = '0xec7cdE35e5D9AcC71c1007EbcdD1f6A83C83536b';

  console.log('deploying master');

  // We get the contract to deploy
  const Master = await hre.ethers.getContractFactory('LaunchpadMaster');
  // deploy fee = 0.1 ether
  const fee = ethers.utils.parseEther('0.1');
  const master = await Master.deploy(500, 0, owner, user1, fee);

  await master.deployed();

  console.log('Master deployed to:', master.address);

  const MockERC20 = await hre.ethers.getContractFactory('MockERC20');
  console.log('deploying token');
  var totalSupply = ethers.BigNumber.from('10').pow(18);
  const token = await MockERC20.deploy('mock', 'MK', totalSupply);

  await token.deployed();

  const now = Math.floor(Date.now() / 1000);
  const maxBuyPerUser = ethers.BigNumber.from('60').pow(18);
  const minBuyPerUser = ethers.BigNumber.from('1').pow(14);
  // create a 100 children
  for (let i = 0; i < 1000; i++) {
    const child = await master.createPresale(
      token.address,
      'test-' + i,
      'presale',
      'presale.png',
      [totalSupply, 1e7, 3000, fee, now + 5, now + 15, maxBuyPerUser, minBuyPerUser],
      false,
      0,
      now + 20,
      '0x10ED43C718714eb63d5aA57B78B54704E256024E',
      { value: fee }
    );
  }

  console.log('children :', await master.getSales());
  console.log('master addr:', master.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
