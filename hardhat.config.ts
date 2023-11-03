import '@nomicfoundation/hardhat-toolbox';
import '@zetachain/toolkit/tasks';

import { getHardhatConfigNetworks } from '@zetachain/networks';
import { HardhatUserConfig } from 'hardhat/config';
const { chainConfig } = require('@nomiclabs/hardhat-etherscan/dist/src/ChainConfig');
chainConfig['zeta_testnet'] = {
  chainId: 7001,
  urls: {
    apiURL: 'https://zetachain-athens-3.blockscout.com/api',
    browserURL: 'https://zetachain-athens-3.blockscout.com',
  },
};

const config: HardhatUserConfig = {
  networks: {
    ...getHardhatConfigNetworks(),
  },
  solidity: '0.8.7',
  etherscan: {
    apiKey: {
      zeta_testnet: '0',
    },
  },
};

export default config;
