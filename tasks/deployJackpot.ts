import { ethers, network } from 'hardhat';
import { getAddress } from '@zetachain/protocol-contracts';
import { verify } from './util';
import { ContractTransaction } from 'ethers';
import { RewardPool } from '../typechain-types';

const main = async () => {
  console.log('Starting deployments');
  const [deployer] = await ethers.getSigners();

  const RewardPoolAddress = '0x05802839e5D80df6628c11D6f0A99291710a2523';
  const JackpotAddress = '0xAccCbDE8A82B5189fFC55ad777D96aC26d06DDc2';
  const ZETAPAddress = '0x52a6080033AC5E0804C798928c47eC1278Cf4B39';
  const systemContract = getAddress('systemContract', 'zeta_testnet');

  const ZETAPFactory = await ethers.getContractFactory('ZETAP');
  const ZETAP = ZETAPFactory.attach(ZETAPAddress);
  console.log('This is ZETAP address: ', ZETAP.address);

  const RewardPoolFactory = await ethers.getContractFactory('RewardPool');
  // const RewardPool = await RewardPoolFactory.deploy(ZETAP.address);
  // await RewardPool.deployed();
  const RewardPool = RewardPoolFactory.attach(RewardPoolAddress) as RewardPool;
  console.log('This is the RewardPool address: ', RewardPool.address);

  const Jackpotfactory = await ethers.getContractFactory('ZetaJackpot');
  const Jackpot = await Jackpotfactory.deploy(RewardPool.address, systemContract);
  await Jackpot.deployed();
  console.log('This is Jackpot Address: ', Jackpot.address);

  let tx: ContractTransaction;
  tx = await RewardPool.connect(deployer).allowFeeContract(Jackpot.address);
  await tx.wait();
  console.log('Allowed Fee contract');

  console.log('Deployments done, waiting for etherscan verifications');

  // Wait for the contracts to be propagated inside Etherscan
  await new Promise((f) => setTimeout(f, 10000));

  // await verify(RewardPool.address, [ZETAP.address]);
  await verify(Jackpot.address, [RewardPool.address, systemContract]);

  console.log('All done');
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
