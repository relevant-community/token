// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

library Utils {
  using Utils for Unlock;
  using Utils for Vest;

  struct Vest {
    uint256 shortAmnt;
    uint256 longAmnt;
    uint256 lastUpdate;
  }

  struct Unlock {
    uint256 unlockAmnt;
    uint256 unlockTime;
  }

  // note: we should be able to unlock all tokens (including vested tokens)
  function unlock(
    Unlock storage self,
    uint256 amount,
    uint256 lockTime
  ) internal {
    self.unlockAmnt = amount;
    self.unlockTime = block.timestamp + lockTime;
  }

  function useUnlocked(Unlock storage self, uint256 amount) internal {
    require(self.unlockTime <= block.timestamp, "sRel Utils: tokens are not unlocked yet");
    require(self.unlockAmnt >= amount, "sRel Utils: tokens should be unlocked before transfer");

    self.unlockAmnt -= amount; // update locked amount;
  }

  function resetLock(Unlock storage self) internal {
    self.unlockAmnt = 0;
    self.unlockTime = 0;
  }

  function transferVestedTokens(Vest storage self, Vest storage vestTo) internal {
    require(self.vested() > 0, "sRel Utils: nothing to transfer");
    require(vestTo.vested() == 0, "sRel Utils: cannot transfer to account with vested tokens");

    vestTo.shortAmnt = self.shortAmnt;
    vestTo.longAmnt = self.longAmnt;
    vestTo.lastUpdate = self.lastUpdate;

    // reset initial vest
    self.shortAmnt = 0;
    self.longAmnt = 0;
    self.lastUpdate = 0;
  }

  function setVestedAmount(
    Vest storage self,
    uint256 shortAmnt,
    uint256 longAmnt
  ) public {
    require(
      self.shortAmnt + self.longAmnt == 0,
      "sRel Utils: this account already has vested tokens"
    );
    if (shortAmnt > 0) self.shortAmnt = shortAmnt;

    if (longAmnt > 0) self.longAmnt = longAmnt;

    self.lastUpdate = 0;
  }

  function vested(Vest storage self) internal view returns (uint256) {
    return self.shortAmnt + self.longAmnt;
  }

  // this method updates long and short vesting amounts
  function updateVestedAmount(
    Vest storage self,
    uint256 vestShort,
    uint256 vestLong,
    uint256 vestBegin
  ) public returns (uint256) {
    require(block.timestamp > vestBegin, "sRel Utils: Vesting has't started yet");
    uint256 amount = 0;
    uint256 shortAmnt = self.shortAmnt;
    uint256 longAmnt = self.longAmnt;
    uint256 last = self.lastUpdate < vestBegin ? vestBegin : self.lastUpdate;

    if (shortAmnt > 0 && last < vestShort) {
      uint256 currentTime = block.timestamp < vestShort ? block.timestamp : vestShort;
      uint256 sAmnt = (shortAmnt * (currentTime - last)) / (vestShort - last);
      self.shortAmnt -= sAmnt;
      amount += sAmnt;
    }

    if (longAmnt > 0 && last < vestLong) {
      uint256 currentTime = block.timestamp < vestLong ? block.timestamp : vestLong;
      uint256 lAmnt = (longAmnt * (currentTime - last)) / (vestLong - last);
      self.longAmnt -= lAmnt;
      amount += lAmnt;
    }

    require(amount > 0, "sRel Utils: There are no vested tokens to claim");
    self.lastUpdate = block.timestamp;

    return amount;
  }
}
