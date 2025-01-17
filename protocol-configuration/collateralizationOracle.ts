// This config lists all of the contracts that should be in the collateralization oracle
// Key names are the tokens that the contract holds / should be tracked in
// Values are arrays of contracts that hold that token

export const CollateralizationOracleConfig = {
  bal: ['balancerDepositBalWeth', 'balancerLensVeBalBal', 'balancerGaugeStaker'],
  fei: ['rariTimelockFeiOldLens'],
  dai: ['simpleFeiDaiPSM', 'ethToDaiLensDai', 'daiHoldingPCVDeposit'],
  lusd: ['lusdHoldingPCVDeposit'],
  weth: ['ethLidoPCVDeposit', 'balancerLensVeBalWeth', 'ethToDaiLensEth', 'wethHoldingPCVDeposit']
};

export type CollateralizationOracleConfigType = typeof CollateralizationOracleConfig;
