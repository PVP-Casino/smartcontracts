import fs from 'fs';
import hre from 'hardhat';

export const writeAddr = (addressFile: string, explorer: string, addr: string, name: string) => {
  fs.appendFileSync(addressFile, `${name}: [${explorer}/address/${addr}](${explorer}/address/${addr})<br/>`);
};

export const verify = async (addr: string, args: any[]) => {
  try {
    await hre.run('verify:verify', {
      address: addr,
      constructorArguments: args,
    });
  } catch (ex: any) {
    if (ex.toString().indexOf('Already Verified') == -1) {
      throw ex;
    }
  }
};
