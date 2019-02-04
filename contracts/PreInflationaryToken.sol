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

    event Allocated(uint256 airdropFund, uint256 rewardFund, uint256 developmentFund);
    // event Released(uint256 numTokens);
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
    uint256 public lastAllocationBlock; // Block number at which the last allocation was made
    uint256 public currentPeriod; // Number of the currently active halving period
    uint256 public currentPeriodStart; // Number of last block from previous period
    uint256 public constantRewardStart; // Number of block from which rewards stay constant
    
    uint256 public rewardFund; // Bucket of inflationary tokens reserved for curation rewards
    uint256 public airdropFund; // Bucket of inflationary tokens reserved for airdrops/new user/referral rewards
    uint256 public distributed; // Bucket of curation rewards tokens claimed by users
    uint256 public developmentFund; // Bucket of inflationary tokens reserved for development

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
        lastAllocationBlock = block.number;
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

    // @TODO: 
    // refactor into several smaller functions
    // rename lastRelease to lastAllocation
    /**
     * @dev Calculate and allocate currently releasable inflationary rewards. 
     */
    function allocateRewards() public {
        uint256 releasableRewards;
        uint256 currBlock = blockNum();

        // Check if already called for the current block
        require(lastAllocationBlock < currBlock, "No new rewards available");

        currentPeriod = (currBlock.sub(startBlock)).div(halvingTime);
        if (currBlock < constantRewardStart) {
            currBlockReward = initBlockReward.div(2**currentPeriod);
        } else {
            currBlockReward = initBlockReward.div(2**lastHalvingPeriod);
        }

        uint256 lastAllocationPeriod = lastAllocationBlock.sub(startBlock).div(halvingTime);
        uint256 blocksPassed = currBlock - lastAllocationBlock;

        if (currentPeriod == lastAllocationPeriod || lastAllocationPeriod >= lastHalvingPeriod) {
            // If last release and current block are in the same halving period OR if we are past the last halving event,
            // rewards are simply the number of passed blocks times the current block reward.
            releasableRewards = blocksPassed * currBlockReward;
            if (lastAllocationPeriod >= lastHalvingPeriod) {
            // if we are past the lastHalvingPeriod we still have to mint these
                mint(address(this), releasableRewards);
            }
        } else {
            // If last release block was in a different period, we have to add up the rewards for each period, separately
            for (uint i = lastAllocationPeriod; i <= currentPeriod; i++) {
                uint256 periodBlockReward = initBlockReward.div(2**i);
                if (i == lastAllocationPeriod) {
                    uint256 nextPeriodStart = startBlock.add((lastAllocationPeriod.add(1)).mul(halvingTime));
                    releasableRewards += (nextPeriodStart.sub(lastAllocationBlock)).mul(periodBlockReward);
                }
                if (i == currentPeriod) {
                    currentPeriodStart = startBlock.add(currentPeriod.mul(halvingTime));
                    releasableRewards += (blockNum().sub(currentPeriodStart)).mul(periodBlockReward);
                }
                if (i != lastAllocationPeriod && i != currentPeriod) {
                    releasableRewards += halvingTime.mul(periodBlockReward);
                }
            }
            if (lastAllocationPeriod <= lastHalvingPeriod && currentPeriod >= lastHalvingPeriod) {
                // if we are releasing tokens for the first time after the lastHalvingPeriod and the last release was
                // still within the halving periods, we have to mint new tokens
                uint256 constantBlockReward = initBlockReward.div(2**lastHalvingPeriod);
                uint256 toBeMinted = (blockNum().sub(constantRewardStart)).mul(constantBlockReward);
                mint(address(this), toBeMinted);
            }
        }
        // @Note: When we devide by 5 the remainder gets lost - this is very small though if we have 18 decimals
        uint256 userRewards = releasableRewards.mul(4).div(5); // 80% of inflation goes to the users
        // For now half of the user rewards are curation rewards and half are signup/referral/airdrop rewards
        airdropFund += userRewards.div(2);
        rewardFund += userRewards.div(2);

        // @Proposal: Formula for calculating airdrop vs curation reward split: airdrops = user rewards * airdrop base share ^ (#months)
        // uint256 monthsPassed = (currBlock - startBlock).div(172800); // 172800 blocks per month
        // uint256 airdropShare = 0.8 ** monthsPassed; // @TODO: figure out decimals / precision
        // airdropFund += userRewards.mul(airdropShare);
        // rewardFund += userRewards.mul(1-airdropShare);

        developmentFund += releasableRewards.div(5); // 20% of inflation goes to devFund

        // Set current block as last allocation
        lastAllocationBlock = currBlock;

        emit Allocated(airdropFund, rewardFund, developmentFund);
        
    }


    /**
     * @dev Transfer eligible tokens from devFund bucket to devFundAddress
     */
    // TODO: who should be able do call this? internal and called from allocateTokens? 
    function toDevFund() public {
        require(this.transfer(devFundAddress, developmentFund), "Transfer to devFundAddress failed");
        developmentFund = 0;
    }


    /**
    * @dev Claim curation reward tokens
    * @param  _amount amount to be transferred to user
    * @param  _sig Signature by contract owner authorizing the transaction
    */
    function claimTokens(uint256 _amount, bytes memory _sig) public returns(bool) {
        // check _amount + account matches hash
        require(rewardFund >= _amount);

        bytes32 hash = keccak256(abi.encodePacked(_amount, msg.sender, nonces[msg.sender]));
        hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));

        // check that the message was signed by contract owner        
        address recOwner = ECDSA.recover(hash, _sig);
        require(owner() == recOwner, "Claim not authorized");
        nonces[msg.sender] += 1;
        rewardFund = rewardFund.sub(_amount);
        require(this.transfer(msg.sender, _amount), "Transfer to claimant failed");
        return true;
    }


    /**
    * @dev Distribute airdrop rewards
    * @param _recipients List of recipients
    * @param _balances Amount to send to recipients
    * TODO this is expensive - better solution:
    * https://github.com/cardstack/merkle-tree-payment-pool
    */
    function distributeRewards(address[] memory _recipients, uint256[] memory _balances) public onlyOwner returns(bool) {
        for(uint i = 0; i < _recipients.length; i++){
            require(airdropFund >= _balances[i], "No airdrop rewards available");
            airdropFund = airdropFund.sub(_balances[i]);
            this.transfer(_recipients[i], _balances[i]);
        }
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

