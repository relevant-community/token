// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interfaces/IsRel.sol";
import "./libraries/Utils.sol";

import "hardhat/console.sol";

contract sRel is IsRel, ERC20Votes, Ownable {
	using Utils for Utils.Vest;
	using Utils for Utils.Unlock;

	IERC20 public immutable r3l; // RELEVANT TOKEN

	address public vestAdmin; // role is responsible for sending tokens to vesting contract

	uint256 public lockPeriod = 4 days; // how long it takes for staked tokens to become unlocked

	uint256 public immutable vestBegin; // start of all vesting periods
	uint256 public immutable vestShort; // short vesting period
	uint256 public immutable vestLong; // long vesting period

	mapping(address => uint256) private vestNonce;
	mapping(address => Utils.Unlock) private unlocks;
	mapping(address => Utils.Vest) private vest;

	// keccak256("UnvestTokens(address account,uint256 shortAmnt,uint256 longAmnt,uint256 nonce)")
	bytes32 public constant CLAIM_HASH =
		0x04f814cda49f9ebe5bd3eddee7e8c680f4d220315bf32a05bc59094194506bd3;

	constructor(
		IERC20 _r3l,
		address _vestAdmin,
		uint256 _vestBegin,
		uint256 _vestShort,
		uint256 _vestLong
	) ERC20("Staked REL", "sREL") ERC20Permit("Staked REL") {
		require(
			_vestBegin <= _vestShort && _vestShort <= _vestLong,
			"sRel: incorrect vesting timestamps"
		);
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

		uint256 vestedBalance = balanceOf(from) - vest[from].unvested();
		require(amount <= vestedBalance, "sRel: you cannot transfer unvested tokens");

		Utils.Unlock storage lock = unlocks[from];
		lock.useUnlocked(amount); // only unlocked tokens can be transferred
		emit lockUpdated(from, lock);
	}

	// ---- STAKING METHODS ----

	// unlock sRel - after lockPeriod tokens can be transferred or withdrawn
	function unlock(uint256 amount) external override(IsRel) {
		Utils.Unlock storage lock = unlocks[msg.sender];
		lock.unlock(amount, lockPeriod);
		emit lockUpdated(msg.sender, lock);
	}

	// re-lock tokens
	function resetLock() external override(IsRel) {
		Utils.Unlock storage lock = unlocks[msg.sender];
		lock.resetLock();
		emit lockUpdated(msg.sender, lock);
	}

	// deposit REL in exchange for sREL
	function stakeRel(uint256 amount) external override(IsRel) {
		require(r3l.transferFrom(msg.sender, address(this), amount), "sRel: transfer failed");
		_mint(msg.sender, amount);
	}

	// withdraws all unlocked tokens
	function unstakeRel(uint256 amount) external override(IsRel) {
		_burn(msg.sender, amount);
		require(r3l.transfer(msg.sender, amount), "sRel: transfer failed");
	}

	// ---- VESTING METHODS ----

	// onwer can set amount of unvested tokens manually
	// NOTE: REL must be sent to this contract before this method is called
	function setUnvestedAmount(
		address account,
		uint256 shortAmnt,
		uint256 longAmnt
	) external override(IsRel) onlyOwner {
		_setUnvestedAmount(account, shortAmnt, longAmnt);
	}

	// Claim curation reward tokens (to be called by user from an app)
	function unvestTokens(
		uint256 _shortAmount,
		uint256 _longAmount,
		bytes memory _sig
	) external override(IsRel) {
		uint256 nonce = vestNonce[msg.sender];

		bytes32 structHash = keccak256(
			abi.encode(CLAIM_HASH, msg.sender, _shortAmount, _longAmount, nonce)
		);

		bytes32 digest = ECDSA.toTypedDataHash(_domainSeparatorV4(), structHash);
		address signer = ECDSA.recover(digest, _sig);

		// check that the message was signed by a vest admin
		require(signer == vestAdmin, "sRel: Claim not authorized");

		vestNonce[msg.sender] = nonce + 1;
		_setUnvestedAmount(msg.sender, _shortAmount, _longAmount);
	}

	// helper function that initializes unvested amounts
	// NOTE: REL must be sent to this contract before this method is called
	function _setUnvestedAmount(
		address account,
		uint256 shortAmnt,
		uint256 longAmnt
	) internal {
		Utils.Vest storage vesting = vest[account];
		vesting.setUnvestedAmount(shortAmnt, longAmnt);
		uint256 totalUnvestedAmnt = shortAmnt + longAmnt;
		require(
			totalSupply() + totalUnvestedAmnt <= r3l.balanceOf(address(this)),
			"sRel: Not enought REL in contract"
		);
		_mint(account, totalUnvestedAmnt);
		emit vestUpdated(account, msg.sender, vesting);
	}

	// unvest and unlock tokens
	function claimUnvestedRel() external override(IsRel) {
		Utils.Vest storage vesting = vest[msg.sender];
		uint256 amount = vesting.updateUnvestedAmount(vestShort, vestLong, vestBegin);
		require(amount > 0, "sRel: no unvested tokens to claim");
		unlocks[msg.sender].unlock(amount, lockPeriod);
		emit vestUpdated(msg.sender, msg.sender, vesting);
	}

	// transfer all unvested tokens to a new address
	function transferUnvestedTokens(address to) external override(IsRel) {
		Utils.Vest storage senderVest = vest[msg.sender];
		Utils.Vest storage toVest = vest[to];
		uint256 amount = senderVest.unvested();
		senderVest.transferUnvestedTokens(toVest);
		transfer(to, amount);
		emit vestUpdated(msg.sender, msg.sender, senderVest);
		emit vestUpdated(to, msg.sender, toVest);
	}

	// ---- GOVERNANCE ----

	function updateLockPeriod(uint256 newLockPeriod) external override(IsRel) onlyOwner {
		require(lockPeriod != newLockPeriod, "sRel: pointless update");
		lockPeriod = newLockPeriod;
		emit lockPeriodUpdated(lockPeriod);
	}

	function setVestAdmin(address newAdmin) external override(IsRel) onlyOwner {
		require(vestAdmin != newAdmin, "sRel: pointless update");
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

	function unvested(address account) external view override(IsRel) returns (uint256) {
		return vest[account].unvested();
	}

	function vestData(address account) external view override(IsRel) returns (Utils.Vest memory) {
		return vest[account];
	}
}
