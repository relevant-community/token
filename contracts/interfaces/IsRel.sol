// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "../libraries/Utils.sol";

// Relevant Governance Token
interface IsRel {
  event lockUpdated(address indexed account, Utils.Unlock unlockData); // staking events
  event vestUpdated(address indexed account, address sender, Utils.Vest vestData); // vesting events

  // governance events
  event lockPeriodUpdated(uint256 newLockPeriod);
  event vestAdminUpdated(address newVestAdmin);

  // staking
  function unlock(uint256 amount) external;

  function resetLock() external;

  function stakeRel(uint256 amount) external;

  function unstakeRel(uint256 amount) external;

  // vesting
  function setVestedAmount(
    address account,
    uint256 amountShort,
    uint256 amountLong
  ) external;

  function vestTokens(
    uint256 _shortAmount,
    uint256 _longAmount,
    bytes memory _sig
  ) external;

  function claimVestedRel() external;

  function transferVestedTokens(address to) external;

  // governance
  function updateLockPeriod(uint256 newLockPeriod) external;

  function setVestAdmin(address newAdmin) external;

  // view
  function nonceOf(address account) external view returns (uint256);

  function unstaked(address account) external view returns (uint256);

  function staked(address account) external view returns (uint256);

  function unlockTime(address account) external view returns (uint256);

  function vested(address account) external view returns (uint256);

  function vestData(address account) external view returns (Utils.Vest memory);
}
