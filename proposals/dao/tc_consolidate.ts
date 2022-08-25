import hre, { ethers, artifacts } from 'hardhat';
import { expect } from 'chai';
import {
  DeployUpgradeFunc,
  NamedAddresses,
  SetupUpgradeFunc,
  TeardownUpgradeFunc,
  ValidateUpgradeFunc
} from '@custom-types/types';
import { BigNumber } from 'ethers';

/*
TIP-122: Tribal Council consolidation

  1. End vesting of Rari Infrastructure team timelocks
  2. Burn all Fei held by the TC
  3. Send INDEX to Tribal Council Safe
  4. Send all remaining assets to the DAO timelock
*/

// Existing balance of FEI on the TC to burn
const TC_FEI_TO_BURN = '42905768215167745773610059';

// Clawed back FEI upper bound
const CLAWED_BACK_FEI_UPPER_BOUND = '2897332829955035696312531';

// Clawed back TRIBE upper bound
const CLAWED_BACK_TRIBE_UPPER_BOUND = '3068505367127310595321005';

let initialFeiSupply: BigNumber;

const fipNumber = 'TC-122'; // Change me!

// Do any deployments
// This should exclusively include new contract deployments
const deploy: DeployUpgradeFunc = async (deployAddress: string, addresses: NamedAddresses, logging: boolean) => {
  console.log(`No deploy actions for fip${fipNumber}`);
  return {
    // put returned contract objects here
  };
};

// Do any setup necessary for running the test.
// This could include setting up Hardhat to impersonate accounts,
// ensuring contracts have a specific state, etc.
const setup: SetupUpgradeFunc = async (addresses, oldContracts, contracts, logging) => {
  initialFeiSupply = await contracts.fei.totalSupply();
};

// Tears down any changes made in setup() that need to be
// cleaned up before doing any validation checks.
const teardown: TeardownUpgradeFunc = async (addresses, oldContracts, contracts, logging) => {
  console.log(`No actions to complete in teardown for fip${fipNumber}`);
};

// Run any validations required on the fip using mocha or console logging
// IE check balances, check state of contracts, etc.
const validate: ValidateUpgradeFunc = async (addresses, oldContracts, contracts, logging) => {
  // 1. Validate Rari Infra timelocks no longer have funds
  expect(await contracts.fei.balanceOf(addresses.newRariInfraFeiTimelock)).to.be.equal(0);
  expect(await contracts.tribe.balanceOf(addresses.newRariInfraTribeTimelock)).to.be.equal(0);

  // 2. Validate TC burned existing FEI
  const feiSupplyDiff = initialFeiSupply.sub(await contracts.fei.totalSupply());
  expect(feiSupplyDiff).to.be.equal(TC_FEI_TO_BURN);

  // 3. Validate FEI and TRIBE approvals given to DAO timelock
  expect(await contracts.fei.allowance(addresses.tribalCouncilTimelock, addresses.feiDAOTimelock)).to.be.equal(
    CLAWED_BACK_FEI_UPPER_BOUND
  );
  expect(await contracts.tribe.allowance(addresses.tribalCouncilTimelock, addresses.feiDAOTimelock)).to.be.equal(
    CLAWED_BACK_TRIBE_UPPER_BOUND
  );
};

export { deploy, setup, teardown, validate };
