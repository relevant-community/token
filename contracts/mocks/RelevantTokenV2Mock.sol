pragma solidity ^0.5.0;

import "../RelevantTokenV2.sol";

contract RelevantTokenMock is RelevantToken {
	/**
	 * @dev Return current round number // using the state variable set by setRoundNum, for testing
	 */

	uint256 currentRound;

	function roundNum() public view returns (uint256) {
		// return (block.number.sub(startBlock)).div(roundLength);
		return currentRound;
	}

	/**
	 * @dev Artificially increases current round number // auxiliary function for testing (simulating block progression)
	 */
	function setRoundNum(uint256 _roundNum) public returns (uint256) {
		currentRound = _roundNum;
		return currentRound;
	}

	/**
	 * @dev Artificially sets the last release round // auxiliary function for testing (simulating reward release)
	 */
	function setLastRound(
		uint256 _roundNum,
		uint256 _lastRoundReward,
		uint256 _totalReleased,
		uint256 _totalAirdrops,
		uint256 _lastRoundAirdrop,
		uint256 _totalRewardReserve
	) public onlyOwner returns (uint256) {
		require(_roundNum < currentRound, "Last release must be before current round");
		lastRound = _roundNum;
		lastRoundReward = _lastRoundReward;
		totalReleased = _totalReleased;
		rewardFund = _totalRewardReserve.div(2);
		airdropFund = _totalAirdrops;
		lastRoundAirdrop = _lastRoundAirdrop;
		reserveFund = _totalRewardReserve.div(2);
		// devFund is always 0 since it gets transferred right away
		return lastRound;
	}

	/**
	 * @dev Artificially empties the devFund account of all accumulated tokens // auxiliary function for testing
	 */
	function emptyDevBalance() public {
		uint256 devBalance = balanceOf(devFundAddress);
		this.transferFrom(devFundAddress, address(0x123), devBalance);
	}
}
