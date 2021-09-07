// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "../libraries/Utils.sol";

// Relevant Governance Token
interface IsRel {

  // staking events
  event lockUpdated(address indexed account, Utils.Unlock unlockData);
  // vesting events
  event vestUpdated(address indexed account, Utils.Vest vestData);

  // governance events (contract size is too large for these)
  event lockPeriodUpdated(uint newLockPeriod);
  event vestAdminUpdated(address newVestAdmin);

  // staking
  function unlock(uint256 amount) external;
  function resetLock() external;
  function stakeRel(uint256 amount) external;
  function unstakeRel(uint256 amount) external;
  // vesting
  function setVestedAmount(address account, uint256 amountShort, uint256 amountLong) external;
  function vestTokens(uint256 _shortAmount, uint256 _longAmount, bytes memory _sig) external;
  function claimVestedRel() external;
  function transferVestedTokens(address to) external;
  // governance 
  function updateLockPeriod(uint newLockPeriod) external;
  function setVestAdmin(address newAdmin) external;
  // view
  function unstaked(address account) external view returns (uint);
  function unlockTime(address account) external view returns (uint);
  function vested(address account) external view returns (uint);
  function vestData(address account) external view returns (Utils.Vest memory);
}
