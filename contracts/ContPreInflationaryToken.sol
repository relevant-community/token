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
    uint256 public timeConstant;
    uint256 public constantReward;
    uint256 public constantRewardStart;

    uint256 public startBlock; // Block number at which the contract is deployed
    uint256 public lastReleaseBlock; // Block number at which the last release was made
    uint256 public totalReleased; // All tokens released until the last release
    
    uint256 public rewardFund; // Bucket of inflationary tokens available to be allocated for curation rewards
    uint256 public airdropFund; // Bucket of inflationary tokens available for airdrops/new user/referral rewards
    uint256 public developmentFund; // Bucket of inflationary tokens reserved for development - gets transferred to devFundAddress immediately
    uint256 public allocatedRewards; // Bucket of curation reward tokens reserved/'spoken for' but not yet claimed by users
    uint256 public allocatedAirdrops; // Bucket of airdrop reward tokens reserved/'spoken for' but not yet claimed by users
    
    uint256 public e; // Euler's number - using 18 decimals for precision

    mapping(address => uint256) nonces;

    /**
     * @dev ContPreInflationaryToken constructor
     * @param _devFundAddress       Address that receives and manages newly minted tokens for development fund
     * @param _initBlockReward      Number of released inflationary tokens per block during the first period
     * @param _timeConstant         Number of blocks after which reward reduces to 37% of initial value during exponential decay 
     *                              (take this times ln(2) to get the half life )
     * @param _constantReward       Block reward at which the decay should stop // maybe not necessary, because constantRewardStart holds equivalent information
     * @param _constantRewardStart  Number of block from which rewards stay constant - can be calculated from timeConstant, initBlockReward and constantReward
     * @param _totalPremint         Rewards that are preminted (all until decay stops) - can be calculated from timeConstant, initBlockReward and constantReward
     */
    function initialize(
        string memory _name, 
        uint8 _decimals, 
        string memory _symbol, 
        string memory _version, 
        address _devFundAddress,
        uint256 _initBlockReward,
        uint256 _timeConstant,
        uint256 _constantReward,
        uint256 _constantRewardStart,
        uint256 _totalPremint
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
        timeConstant = _timeConstant;
        constantReward = _constantReward;
        constantRewardStart = _constantRewardStart;

        e = 271828182845904523;

        startBlock = block.number;
        currBlockReward = initBlockReward;
        lastReleaseBlock = block.number;

        preMintTokens(_totalPremint);
    }

    /**
     * @dev Calculate and mint the number of inflationary tokens until constantRewards are reached
     */
    function preMintTokens(uint256 _totalPreMint) internal {
        mint(address(this), _totalPreMint);
    }

    /**
     * @dev Calculate and release currently releasable inflationary rewards. 
     */
    function releaseTokens() public {
        uint256 releasableTokens;
        uint256 currentBlock = blockNum();

        // Check if already called for the current block
        require(lastReleaseBlock < currentBlock, "No new rewards available");


        // Determine the number of blocks that have passed since the last release
        uint256 blocksPassed = currentBlock.sub(lastReleaseBlock);

        if (lastReleaseBlock >= constantRewardStart) {
            // If the decay had already stopped at the time of last release, 
            // rewards are simply the number of passed blocks times the constant block reward.
            releasableTokens = blocksPassed.mul(constantReward);
            // We still have to mint these
            mint(address(this), releasableTokens);
        } else {
            uint256 totalIntegral;
            // If last release was during the decay period, we must distinguish two cases:
            if (currentBlock < constantRewardStart) {
                totalIntegral = initBlockReward * (-timeConstant) * e ** (-currentBlock/timeConstant) + timeConstant;
                releasableTokens = totalIntegral.sub(totalReleased);
            }
            if (currentBlock >= constantRewardStart) {
                uint256 toBeMinted = (currentBlock.sub(constantRewardStart)).mul(constantReward);
                totalIntegral = initBlockReward * (-timeConstant) * e ** (-constantRewardStart/timeConstant) + timeConstant;
                releasableTokens = totalIntegral.sub(totalReleased).add(toBeMinted);
                mint(address(this), toBeMinted);
            }
        }
        uint256 userRewards = releasableTokens.mul(4).div(5); // 80% of inflation goes to the users
        // For now half of the user rewards are curation rewards and half are signup/referral/airdrop rewards
        airdropFund += userRewards.div(2);
        rewardFund += userRewards.div(2);

        // @Proposal: Formula for calculating airdrop vs curation reward split: airdrops = user rewards * airdrop base share ^ (#months)
        // uint256 monthsPassed = (currentBlock - startBlock).div(172800); // 172800 blocks per month
        // uint256 airdropShare = 0.8 ** monthsPassed; // @TODO: figure out decimals / precision
        // airdropFund += userRewards.mul(airdropShare);
        // rewardFund += userRewards.mul(1-airdropShare);

        developmentFund = developmentFund.add(releasableTokens.div(5)); // 20% of inflation goes to devFund
        toDevFund(); // transfer these out immediately

        // Set current block as last release
        lastReleaseBlock = currentBlock;
        // Increase totalReleased count
        totalReleased = totalReleased.add(releasableTokens);

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

