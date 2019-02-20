pragma solidity ^0.5.0;

import "openzeppelin-eth/contracts/token/ERC20/ERC20Mintable.sol";
import "openzeppelin-eth/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-eth/contracts/ownership/Ownable.sol";
import "openzeppelin-eth/contracts/cryptography/ECDSA.sol";
import "zos-lib/contracts/Initializable.sol";
// import "./Power.sol";



/**
 * @title An Inflationary Token with premint, gradual release, exponential decay of inflationary rewards, and a target inflation rate
 */

contract RelevantToken is Initializable, ERC20, Ownable, ERC20Mintable {

  event Released(uint256 releasableTokens, uint256 rewardFund, uint256 airdropFund, uint256 developmentFund);
  // event ParameterUpdate(string param);

  string public name;
  uint8 public decimals;
  string public symbol;
  string public version;
  address public devFundAddress;
  uint256 public initRoundReward;
  uint256 public currRoundReward;
  uint256 public timeConstant;
  uint256 public targetInflation;
  uint256 public targetRound;
  uint256 public roundLength;
  uint256 public roundDecay;

  uint256 public startBlock; // Block number at which the contract is deployed
  uint256 public lastRound; // Round at which the last release was made
  uint256 public lastRoundReward; // Reward of the round where tokens were last released
  uint256 public totalReleased; // All tokens released until and including the last release

  uint256 public rewardFund; // Bucket of inflationary tokens available to be allocated for curation rewards
  uint256 public airdropFund; // Bucket of inflationary tokens available for airdrops/new user/referral rewards
  uint256 public developmentFund; // Bucket of inflationary tokens reserved for development - gets transferred to devFundAddress immediately
  uint256 public allocatedRewards; // Bucket of curation reward tokens reserved/'spoken for' but not yet claimed by users
  uint256 public allocatedAirdrops; // Bucket of airdrop reward tokens reserved/'spoken for' but not yet claimed by users

  uint256 public e; // Euler's number // declared just to make the contract compile TODO: use Bancor Power formula

  mapping(address => uint256) nonces;

  /**
   * @dev ContPreInflationaryToken constructor
   * @param _devFundAddress         Address that receives and manages newly minted tokens for development fund
   * @param _initRoundReward        Number of released inflationary tokens per round during the first round
   * @param _timeConstant           Number of blocks after which reward reduces to 37% of initial value during exponential decay - can be calculated from half-life
   * @param _targetInflation        Target inflation rate per round at which the reward decay should stop - can be calculated from target yearly inflation rate
   * @param _targetRound            Number of round from which inflation stays constant - can be calculated from timeConstant, initRoundReward and targetInflation
   * @param _roundLength            Number of blocks that make up an inflation release round
   * @param _roundDecay             Decay factor for the reward reduction during one round - can be calculated from timeConstant and roundLength
   * @param _totalPremint           Rewards that are preminted (all until decay stops) - can be calculated from timeConstant, initRoundReward and targetInflation
   */
  function initialize(
    string memory _name,
    uint8 _decimals,
    string memory _symbol,
    string memory _version,
    address _devFundAddress,
    uint256 _initRoundReward,
    uint256 _timeConstant,
    uint256 _targetInflation,
    uint256 _targetRound,
    uint256 _roundLength,
    uint256 _roundDecay,
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
    initRoundReward = _initRoundReward;
    timeConstant = _timeConstant;
    targetInflation = _targetInflation;
    targetRound = _targetRound;
    roundLength = _roundLength;
    roundDecay = _roundDecay;

    e = 2718281828459045235; // e*10^18

    startBlock = block.number;
    currRoundReward = initRoundReward;
    lastRound = 0;
    lastRoundReward = initRoundReward;

    preMintTokens(_totalPremint);
  }

  /**
   * @dev Mint the number of inflationary tokens until constantInflations are reached
   */
  function preMintTokens(uint256 _toBeMinted) internal {
    mint(address(this), _toBeMinted);
  }

  /**
   * @dev Calculate and release currently releasable inflationary rewards.
   */
  function releaseTokens() public {
    uint256 releasableTokens;
    uint256 currentRound = roundNum();

    // Check if already called for the current round
    require(lastRound < currentRound, "No new rewards available");

    // Determine the number of rounds that have passed since the last release
    uint256 roundsPassed = currentRound.sub(lastRound);

    if (lastRound >= targetRound) {
      // If the decay had already stopped at the time of last release,
      // we have to loop through the passed rounds and add up the constant round inflation.
      uint256 totalTokens = totalSupply();
      for (uint i = 0; i < roundsPassed; i++) {
        uint256 toBeMintedInRound = targetInflation.mul(totalTokens);
        releasableTokens = releasableTokens.add(toBeMintedInRound);
        totalTokens = totalTokens.add(toBeMintedInRound);
      }
      // We still have to mint these
      mint(address(this), releasableTokens);
    } else {
      // If last release was during the decay period, we must distinguish two cases and within the first case again two more cases:
      if (currentRound < targetRound) {
        // We are still in the decay period
        if (roundsPassed < 24) {
        // If the last release was made less than 24 rounds ago, we use the discrete loop method to add up all new tokens applying roundDecay after each round.
          uint256 roundReward;
          for (uint j = 0; j < roundsPassed; j++) {
            roundReward = roundDecay.mul(lastRoundReward);
            releasableTokens = releasableTokens.add(roundReward);
            lastRoundReward = roundReward;
          }
        } else {
        // If more rounds have passed we don't want to loop that many times
        // and therefore use integration using the exponential decay formula
          releasableTokens = totalIntegral(currentRound).sub(totalReleased);
        // TODO: still need to set lastRoundReward!
        }
      } else {
        // We have recently crossed from the decay period into the constantInflationPeriod
        // and therefore have to calculate the releasable tokens for both segments separately
        uint256 releasableFromDecayPeriod = totalIntegral(targetRound).sub(totalReleased);
        uint256 totalTokensK = totalSupply() + releasableFromDecayPeriod;
        uint256 roundsSinceConstInflation = currentRound.sub(targetRound);
        uint256 toBeMintedK;
        for (uint k = 0; k < roundsSinceConstInflation; k++) {
          uint256 toBeMintedInRoundK = targetInflation.mul(totalTokensK);
          toBeMintedK = toBeMintedK.add(toBeMintedInRoundK);
          totalTokensK = totalTokensK.add(toBeMintedInRoundK);
        }
        releasableTokens = releasableFromDecayPeriod.add(toBeMintedK);
        mint(address(this), toBeMintedK);
      }
    }
    uint256 userRewards = releasableTokens.mul(4).div(5); // 80% of inflation goes to the users

    airdropFund += userRewards.div(2);
    rewardFund += userRewards.div(2);

    // For now half of the user rewards are curation rewards and half are signup/referral/airdrop rewards
    // @Proposal for later: Formula for calculating airdrop vs curation reward split: airdrops = user rewards * airdrop base share ^ (time)
    // uint256 airdropShare = 0.999988 ** currentRound; // @TODO: figure out decimals / precision

    developmentFund = developmentFund.add(releasableTokens.div(5)); // 20% of inflation goes to devFund
    toDevFund(); // transfer these out immediately

    // Set current round as last release
    lastRound = currentRound;
    // Increase totalReleased count
    totalReleased = totalReleased.add(releasableTokens);

    emit Released(releasableTokens, rewardFund, airdropFund, developmentFund);

  }

  /*
   * @dev compute number of tokens to release once inflation is constant
   * @params roundsPassed - number of rounds since last update
   */
  function newTokensForConstantRound(uint256 roundsPassed) public view returns (uint256) {
    uint256 releasableTokens;
    uint256 totalTokens = totalSupply();
    for (uint i = 0; i < roundsPassed; i++) {
      uint256 toBeMintedInRound = targetInflation.mul(totalTokens);
      releasableTokens = releasableTokens.add(toBeMintedInRound);
      totalTokens = totalTokens.add(toBeMintedInRound);
    }
    return releasableTokens;
  }

  /**
   * @dev Calculates total number of tokens minted by taking the integral of the block reward function
    @param _round Round until which the integral is taken
   */
  function totalIntegral(uint256 _round) public view returns (uint256) {
    // TODO: this needs to be worked out! take care of negative signs & use
    // Power() contract from Bancor - can it help deal with fractional exponent?!
    // return initRoundReward.mul(-timeConstant).mul(fixedExp(-_round/timeConstant, 18)).add(timeConstant.mul(initRoundReward)); 
  }


  /**
   * @dev Transfer eligible tokens from devFund bucket to devFundAddress
   */

  function toDevFund() internal returns(bool) {
    require(this.transfer(devFundAddress, developmentFund), "Transfer to devFundAddress failed");
    developmentFund = 0;
    return true;
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
   * @dev Return current round number
   */
  function roundNum() public view returns (uint256) {
    return (block.number.sub(startBlock)).div(roundLength);
  }

  /**
   * @dev Mock transaction to simulate change in block number for testing
   */
  // @TODO: remove in production
  function blockMiner() public {
    name = "NewDummyNameToMakeStateChange";
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

