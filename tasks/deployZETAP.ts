import { ethers, network } from 'hardhat';
import fs from 'fs';
import hre from 'hardhat';
import { verify, writeAddr } from './util';

const addressFile = './contract_addresses.md';
const exploreUrl = 'https://zetachain-athens-3.blockscout.com/';
async function main() {
  console.log('Starting deployments');
  const accounts = await hre.ethers.getSigners();

  const ZETAPAddress = '0x52a6080033AC5E0804C798928c47eC1278Cf4B39';
  const ZETAPFactory = await ethers.getContractFactory('ZETAP');
  // const ZETAP = await ZETAPFactory.deploy('ZETAP', 'ZTP');
  // await ZETAP.deployed();
  const ZETAP = ZETAPFactory.attach(ZETAPAddress);

  console.log('This is the ZETAP address: ', ZETAP.address);

  if (fs.existsSync(addressFile)) {
    fs.rmSync(addressFile);
  }

  fs.appendFileSync(addressFile, 'This file contains the latest test deployment addresses in the Goerli network<br/>');
  writeAddr(addressFile, exploreUrl, ZETAP.address, 'ERC-20');

  console.log('Deployments done, waiting for etherscan verifications');

  // Wait for the contracts to be propagated inside Etherscan
  await new Promise((f) => setTimeout(f, 10000));

  await verify(ZETAP.address, ['ZETAP', 'ZTP']);

  console.log('All done');
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
