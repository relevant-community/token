pragma solidity ^0.5.0;

import "openzeppelin-eth/contracts/token/ERC20/ERC20Mintable.sol";
import "openzeppelin-eth/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-eth/contracts/ownership/Ownable.sol";
import "zos-lib/contracts/Initializable.sol";


/**
 * @title An Inflationary Token with Premint and Gradual Release
 */

contract InflationaryToken is Initializable, ERC20, Ownable, ERC20Mintable {

    event Released(uint256 numTokens);
    event ParameterUpdate(string param);

    string public name;
    uint8 public decimals;
    string public symbol;
    string public version;
    address public devFund;
    uint256 public initBlockReward;
    uint256 public currBlockReward;
    uint256 public halvingTime;
    uint256 public lastHalvingPeriod;
    uint256 public startBlock; // Block number at which the contract is deployed
    uint256 public releasableRewards;
    uint256 public lastReleaseBlock; // Block number at which the last release was made
    uint256 public currentPeriod; // Number of the currently active period
    uint256 public currentPeriodStart; // Number of last block from previous period
    uint256 public constantRewardStart; // Number of block at which constant rewards start

    /**
     * @dev InflationaryToken constructor
     * @param _devFund Address that receives newly minted tokens for development fund
     * @param _initBlockReward Number of released inflationary tokens per block during the first period - should be multiple of a power of 2 (at least 2^_lastHalvingPeriod) to make halving simple
     * @param _halvingTime Number of blocks after which reward halves (e.g. 2102400 for 1 year on Ethereum based on 15 seconds block time)
     * @param _lastHalvingPeriod Number of halvingTime periods after which the reward should stay constant
     */
    function initialize(
        string memory _name, 
        uint8 _decimals, 
        string memory _symbol, 
        string memory _version, 
        address _devFund,
        uint256 _initBlockReward,
        uint256 _halvingTime,
        uint256 _lastHalvingPeriod
    )   public 
        initializer 
    {
        Ownable.initialize(msg.sender);
        ERC20Mintable.initialize(msg.sender);

        name = _name;
        decimals = _decimals;
        symbol = _symbol;
        version = _version;
        devFund = _devFund;
        initBlockReward = _initBlockReward;
        halvingTime = _halvingTime;
        lastHalvingPeriod = _lastHalvingPeriod;

        startBlock = block.number;
        currBlockReward = initBlockReward;
        lastReleaseBlock = block.number;
        constantRewardStart = _lastHalvingPeriod.mul(_halvingTime);
    }

    /**
     * @dev Calculate and mint the number of inflationary tokens from start to lastHalvingPeriod.
            Can only be called by owner. // TODO: Can only be called once.
     */
    function preMintInflation() public {
        uint256 totalRewards;
        uint256 periodBlockReward;
        
        for (uint i = 0; i < lastHalvingPeriod; i++) {
            periodBlockReward = initBlockReward.div(2**i);
            totalRewards += periodBlockReward * halvingTime;
        }
        mint(address(this), totalRewards);
    }

    /**
     * @dev Calculate and release currently releasable inflationary rewards. 
     */
    function releaseRewards() public {
        uint256 releasableRewards;
        uint256 currBlock = blockNum();

        // Check if already called for the current block
        require(lastReleaseBlock < currBlock, "No new rewards available");

        currentPeriod = (currBlock.sub(startBlock)).div(halvingTime);
        if (currBlock < constantRewardStart) {
            currBlockReward = initBlockReward.div(2**currentPeriod);
        } else {
            currBlockReward = initBlockReward.div(2**lastHalvingPeriod);
        }

        uint256 lastReleasePeriod = lastReleaseBlock.sub(startBlock).div(halvingTime);
        uint256 blocksPassed = currBlock - lastReleaseBlock;

        if (currentPeriod == lastReleasePeriod || lastReleasePeriod >= lastHalvingPeriod) {
            // If last release and current block are in the same halving period OR if we are past the last halving event,
            // rewards are simply the number of passed blocks times the current block reward.
            releasableRewards = blocksPassed * currBlockReward;
            if (lastReleasePeriod >= lastHalvingPeriod) {
            // if we are past the lastHalvingPeriod we still have to mint these
                mint(address(this), releasableRewards);
            }
        } else {
            // If last release block was in a different period, we have to add up the rewards for each period, separately
            for (uint i = lastReleasePeriod; i <= currentPeriod; i++) {
                uint256 periodBlockReward = initBlockReward.div(2**i);
                if (i == lastReleasePeriod) {
                    uint256 lastReleasePeriodEnd = startBlock.add((lastReleasePeriod.add(1)).mul(halvingTime));
                    releasableRewards += (lastReleasePeriodEnd.sub(lastReleaseBlock)).mul(periodBlockReward);
                    // TODO: rewards for lastReleaseBlock were already created - avoid double counting
                }
                if (i == currentPeriod) {
                    currentPeriodStart = startBlock.add(currentPeriod.mul(halvingTime));
                    releasableRewards += (blockNum().sub(currentPeriodStart)).mul(periodBlockReward);
                }
                if (i != lastReleasePeriod && i != currentPeriod) {
                    releasableRewards += halvingTime.mul(periodBlockReward);
                }
            }
            if (lastReleasePeriod <= lastHalvingPeriod && currentPeriod >= lastHalvingPeriod) {
                // if we are releasing tokens for the first time after the lastHalvingPeriod and the last release was
                // still within the halving periods, we have to mint new tokens
                uint256 constantBlockReward = initBlockReward.div(2**lastHalvingPeriod);
                uint256 toBeMinted = (blockNum().sub(constantRewardStart)).mul(constantBlockReward);
                mint(address(this), toBeMinted);
            }
        }
        this.transfer(devFund, releasableRewards);
        emit Released(releasableRewards);
        // Set current block as last release
        lastReleaseBlock = currBlock;
    }


    /**
     * @dev Return current block number
     */
    function blockNum() public view returns (uint256) {
        return block.number;
    }

    /**
     * @dev Mock transaction to simulate change in block number for testing
     */
    function blockMiner() public {
        name = "NewName";
    }
}

