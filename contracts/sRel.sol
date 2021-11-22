// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interfaces/IsRel.sol";
import "./libraries/Utils.sol";

contract sRel is IsRel, ERC20Votes, Ownable {
  using Utils for Utils.Vest;
  using Utils for Utils.Unlock;

  address public immutable r3l; // RELEVANT TOKEN

  address public vestAdmin; // role is responsible for sending tokens to vesting contract

  uint256 public lockPeriod = 4 days; // how long it takes for staked tokens to become unlocked

  uint256 public immutable vestBegin; // start of all vesting periods
  uint256 public immutable vestShort; // short vesting period
  uint256 public immutable vestLong; // long vesting period

  mapping(address => uint256) private vestNonce;
  mapping(address => Utils.Unlock) private unlocks;
  mapping(address => Utils.Vest) private vest;

  constructor(
    address _r3l,
    address _vestAdmin,
    uint256 _vestBegin,
    uint256 _vestShort,
    uint256 _vestLong
  ) ERC20("Staked REL", "sREL") ERC20Permit("Staked REL") {
    r3l = _r3l;
    vestBegin = _vestBegin;
    vestShort = _vestShort;
    vestLong = _vestLong;
    vestAdmin = _vestAdmin;
  }

  // only unlocked & unvested tokens can be transferred
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override(ERC20) {
    super._beforeTokenTransfer(from, to, amount);

    // minting and transfers from contract are not subject to unlocks
    if (from == address(0) || from == address(this)) return;

    uint256 unvestedBalance = balanceOf(msg.sender) - vest[msg.sender].vested();
    require(amount <= unvestedBalance, "sRel: you cannot transfer vested tokens");

    unlocks[from].useUnlocked(amount); // only unlocked tokens can be transferred
    emit lockUpdated(from, unlocks[from]);
  }

  // ---- STAKING METHODS ----

  // unlock sRel - after lockPeriod tokens can be transferred or withdrawn
  function unlock(uint256 amount) external override(IsRel) {
    unlocks[msg.sender].unlock(amount, lockPeriod);
    emit lockUpdated(msg.sender, unlocks[msg.sender]);
  }

  // re-lock tokens
  function resetLock() external override(IsRel) {
    unlocks[msg.sender].resetLock();
    emit lockUpdated(msg.sender, unlocks[msg.sender]);
  }

  // deposit REL in exchange for sREL
  function stakeRel(uint256 amount) external override(IsRel) {
    IERC20(r3l).transferFrom(msg.sender, address(this), amount);
    _mint(msg.sender, amount);
  }

  // withdraws all unlocked tokens
  function unstakeRel(uint256 amount) external override(IsRel) {
    _burn(msg.sender, amount);
    IERC20(r3l).transfer(msg.sender, amount);
  }

  // ---- VESTING METHODS ----

  // onwer can set amount of vested tokens manually
  // NOTE: REL must be sent to this contract before this method is called
  function setVestedAmount(
    address account,
    uint256 shortAmnt,
    uint256 longAmnt
  ) external override(IsRel) onlyOwner {
    _setVestedAmount(account, shortAmnt, longAmnt);
  }

  // Claim curation reward tokens (to be called by user from an app)
  function vestTokens(
    uint256 _shortAmount,
    uint256 _longAmount,
    bytes memory _sig
  ) external override(IsRel) {
    bytes32 hash = keccak256(
      abi.encodePacked(_shortAmount, _longAmount, msg.sender, vestNonce[msg.sender])
    );
    hash = ECDSA.toEthSignedMessageHash(hash);
    address signer = ECDSA.recover(hash, _sig);

    // check that the message was signed by a vest admin
    require(signer == vestAdmin, "sRel: Claim not authorized");

    vestNonce[msg.sender] += 1;
    _setVestedAmount(msg.sender, _shortAmount, _longAmount);
  }

  // helper function that initializes vesting amounts
  // NOTE: REL must be sent to this contract before this method is called
  function _setVestedAmount(
    address account,
    uint256 shortAmnt,
    uint256 longAmnt
  ) internal {
    vest[account].setVestedAmount(shortAmnt, longAmnt);
    require(
      totalSupply() + shortAmnt + longAmnt <= IERC20(r3l).balanceOf(address(this)),
      "sRel: Not enought REL in contract"
    );
    _mint(account, shortAmnt + longAmnt);
    emit vestUpdated(account, msg.sender, vest[account]);
  }

  // unvest and unlock tokens
  function claimVestedRel() external override(IsRel) {
    uint256 amount = vest[msg.sender].updateVestedAmount(vestShort, vestLong, vestBegin);
    unlocks[msg.sender].unlock(amount, lockPeriod);
    emit vestUpdated(msg.sender, msg.sender, vest[msg.sender]);
  }

  // transfer all vested tokens to a new address
  function transferVestedTokens(address to) external override(IsRel) {
    uint256 amount = vest[msg.sender].vested();
    vest[msg.sender].transferVestedTokens(vest[to]);
    transfer(to, amount);
    emit vestUpdated(msg.sender, msg.sender, vest[msg.sender]);
    emit vestUpdated(to, msg.sender, vest[msg.sender]);
  }

  // ---- GOVERNANCE ----

  function updateLockPeriod(uint256 newLockPeriod) external override(IsRel) onlyOwner {
    lockPeriod = newLockPeriod;
    emit lockPeriodUpdated(lockPeriod);
  }

  function setVestAdmin(address newAdmin) external override(IsRel) onlyOwner {
    vestAdmin = newAdmin;
    emit vestAdminUpdated(vestAdmin);
  }

  // ---- VIEW --------
  function nonceOf(address account) external view override(IsRel) returns (uint256) {
    return vestNonce[account];
  }

  function staked(address account) external view override(IsRel) returns (uint256) {
    return balanceOf(account) - unlocks[account].unlockAmnt;
  }

  function unstaked(address account) external view override(IsRel) returns (uint256) {
    return unlocks[account].unlockAmnt;
  }

  function unlockTime(address account) external view override(IsRel) returns (uint256) {
    return unlocks[account].unlockTime;
  }

  function vested(address account) external view override(IsRel) returns (uint256) {
    return vest[account].vested();
  }

  function vestData(address account) external view override(IsRel) returns (Utils.Vest memory) {
    return vest[account];
  }
}
