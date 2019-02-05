pragma solidity ^0.5.0;

import "openzeppelin-eth/contracts/token/ERC20/ERC20Mintable.sol";
import "openzeppelin-eth/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-eth/contracts/ownership/Ownable.sol";
import "openzeppelin-eth/contracts/cryptography/ECDSA.sol";
import "zos-lib/contracts/Initializable.sol";


/**
 * @title An Inflationary Token with Premint and Gradual Release
 */

contract InflationaryToken is Initializable, ERC20, Ownable, ERC20Mintable {

    event Released(uint256 releasableTokens, uint256 rewardFund, uint256 airdropFund, uint256 developmentFund);
    // event ParameterUpdate(string param);

    string public name;
    uint8 public decimals;
    string public symbol;
    string public version;
    address public devFundAddress;
    uint256 public initBlockReward;
    uint256 public currBlockReward;
    uint256 public halvingTime;
    uint256 public lastHalvingPeriod;

    uint256 public startBlock; // Block number at which the contract is deployed
    uint256 public lastReleaseBlock; // Block number at which the last release was made
    uint256 public currentPeriod; // Number of the currently active halving period
    uint256 public currentPeriodStart; // Number of last block from previous period
    uint256 public constantRewardStart; // Number of block from which rewards stay constant
    
    uint256 public rewardFund; // Bucket of inflationary tokens available to be allocated for curation rewards
    uint256 public airdropFund; // Bucket of inflationary tokens available for airdrops/new user/referral rewards
    uint256 public developmentFund; // Bucket of inflationary tokens reserved for development - gets transferred to devFundAddress immediately
    uint256 public allocatedRewards; // Bucket of curation reward tokens reserved/'spoken for' but not yet claimed by users
    uint256 public allocatedAirdrops; // Bucket of airdrop reward tokens reserved/'spoken for' but not yet claimed by users

    mapping(address => uint256) nonces;

    /**
     * @dev PreInflationaryToken constructor
     * @param _devFundAddress Address that receives and manages newly minted tokens for development fund
     * @param _initBlockReward Number of released inflationary tokens per block during the first period - should be multiple of a power of 2 (at least 2^_lastHalvingPeriod) to make halving simple
     * @param _halvingTime Number of blocks after which reward halves (e.g. 2102400 for 1 year on Ethereum based on 15 seconds block time)
     * @param _lastHalvingPeriod Number of halvingTime periods after which the reward should stay constant
     */
    function initialize(
        string memory _name, 
        uint8 _decimals, 
        string memory _symbol, 
        string memory _version, 
        address _devFundAddress,
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
        devFundAddress = _devFundAddress;
        initBlockReward = _initBlockReward;
        halvingTime = _halvingTime;
        lastHalvingPeriod = _lastHalvingPeriod;

        startBlock = block.number;
        currBlockReward = initBlockReward;
        lastReleaseBlock = block.number;
        constantRewardStart = _lastHalvingPeriod.mul(_halvingTime);

        preMintTokens();
    }

    /**
     * @dev Calculate and mint the number of inflationary tokens until lastHalvingPeriod at the beginning.
     */
    function preMintTokens() internal {
        uint256 totalRewards;
        uint256 periodBlockReward;
        
        for (uint i = 0; i < lastHalvingPeriod; i++) {
            periodBlockReward = initBlockReward.div(2**i);
            totalRewards += periodBlockReward * halvingTime;
        }
        mint(address(this), totalRewards);
    }

    // @TODO: refactor into several smaller functions?!
    /**
     * @dev Calculate and release currently releasable inflationary rewards. 
     */
    function releaseTokens() public {
        uint256 releasableTokens;
        uint256 currBlock = blockNum();

        // Check if already called for the current block
        require(lastReleaseBlock < currBlock, "No new rewards available");

        // Determine what halving period we are in and what the corresponding block reward is
        currentPeriod = (currBlock.sub(startBlock)).div(halvingTime);
        if (currentPeriod < lastHalvingPeriod) {
            currBlockReward = initBlockReward.div(2**currentPeriod);
        } else {
            currBlockReward = initBlockReward.div(2**lastHalvingPeriod);
        }

        // Determine the period in which the last release was made,
        // in order to calculate how many new tokens are eligible for release
        uint256 lastReleasePeriod = lastReleaseBlock.sub(startBlock).div(halvingTime);
        uint256 blocksPassed = currBlock - lastReleaseBlock;

        if (currentPeriod == lastReleasePeriod || lastReleasePeriod >= lastHalvingPeriod) {
            // If last release and current block are in the same halving period OR if we are past the last halving event,
            // rewards are simply the number of passed blocks times the current block reward.
            releasableTokens = blocksPassed * currBlockReward;
            if (lastReleasePeriod >= lastHalvingPeriod) {
            // if we are past the lastHalvingPeriod we still have to mint these
                mint(address(this), releasableTokens);
            }
        } else {
            // If last release block was in a different period, we have to add up the rewards for each period, separately
            for (uint i = lastReleasePeriod; i <= currentPeriod; i++) {
                uint256 periodBlockReward = initBlockReward.div(2**i);
                if (i == lastReleasePeriod) {
                    uint256 nextPeriodStart = startBlock.add((lastReleasePeriod.add(1)).mul(halvingTime));
                    releasableTokens += (nextPeriodStart.sub(lastReleaseBlock)).mul(periodBlockReward);
                }
                if (i == currentPeriod) {
                    currentPeriodStart = startBlock.add(currentPeriod.mul(halvingTime));
                    releasableTokens += (blockNum().sub(currentPeriodStart)).mul(periodBlockReward);
                }
                if (i != lastReleasePeriod && i != currentPeriod) {
                    releasableTokens += halvingTime.mul(periodBlockReward);
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
        // @Note: When we divide by 5 the remainder gets lost - this is very small though if we have 18 decimals
        uint256 userRewards = releasableTokens.mul(4).div(5); // 80% of inflation goes to the users
        // For now half of the user rewards are curation rewards and half are signup/referral/airdrop rewards
        airdropFund += userRewards.div(2);
        rewardFund += userRewards.div(2);

        // @Proposal: Formula for calculating airdrop vs curation reward split: airdrops = user rewards * airdrop base share ^ (#months)
        // uint256 monthsPassed = (currBlock - startBlock).div(172800); // 172800 blocks per month
        // uint256 airdropShare = 0.8 ** monthsPassed; // @TODO: figure out decimals / precision
        // airdropFund += userRewards.mul(airdropShare);
        // rewardFund += userRewards.mul(1-airdropShare);

        developmentFund += releasableTokens.div(5); // 20% of inflation goes to devFund
        toDevFund(); // transfer these out immediately

        // Set current block as last release
        lastReleaseBlock = currBlock;

        emit Released(releasableTokens, rewardFund, airdropFund, developmentFund);
        
    }


    /**
     * @dev Transfer eligible tokens from devFund bucket to devFundAddress
     */

    function toDevFund() internal {
        require(this.transfer(devFundAddress, developmentFund), "Transfer to devFundAddress failed");
        developmentFund = 0;
    }


    /**
    * @dev Allocate rewards
    * @param rewards to be reserved for users claims
    */
    function allocateRewards(uint256 rewards) public onlyOwner returns(bool) {
        require(rewards <= rewardFund, "Not enough curation rewards available");
        rewardFund = rewardFund.sub(rewards);
        allocatedRewards += rewards;
        return true;
    }


    /**
    * @dev Allocate airdrops
    * @param rewards to be reserved for user claims
    */
    function allocateAirdrops(uint256 rewards) public onlyOwner returns(bool) {
        require(rewards <= airdropFund, "Not enough airdrop rewards available");
        airdropFund = airdropFund.sub(rewards);
        allocatedAirdrops += rewards;
        return true;
    }


    /**
    * @dev Claim curation reward tokens (to be called by user)
    * @param  _amount amount to be transferred to user
    * @param  _sig Signature by contract owner authorizing the transaction
    */
    function claimTokens(uint256 _amount, bytes memory _sig) public returns(bool) {
        // check _amount + account matches hash
        require(allocatedRewards >= _amount);

        bytes32 hash = keccak256(abi.encodePacked(_amount, msg.sender, nonces[msg.sender]));
        hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));

        // check that the message was signed by contract owner        
        address recOwner = ECDSA.recover(hash, _sig);
        require(owner() == recOwner, "Claim not authorized");
        nonces[msg.sender] += 1;
        allocatedRewards = allocatedRewards.sub(_amount);
        require(this.transfer(msg.sender, _amount), "Transfer to claimant failed");
        return true;
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
    // @TODO: remove in production
    function blockMiner() public {
        name = "NewName";
    }


    /**
    * @dev Nonce of user
    * @param _account User account address
    * @return nonce of user
    */
    function nonceOf(address _account) public view returns(uint256) {
        return nonces[_account];
    }

}

