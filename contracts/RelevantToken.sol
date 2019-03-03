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
  uint256 public totalPremint;
  uint256 public currentRound; // only for testing to simulate block progression
  uint256 public startBlock; // Block number at which the contract is deployed
  uint256 public lastRound; // Round at which the last release was made
  uint256 public lastRoundReward; // Reward of the round where tokens were last released (only computed during decay phase)
  uint256 public totalReleased; // All tokens released until and including the last release

  uint256 public rewardFund; // Bucket of inflationary tokens available to be allocated for curation rewards
  uint256 public airdropFund; // Bucket of inflationary tokens available for airdrops/new user/referral rewards
  uint256 public reserveFund; // Reserve bucket - these tokens are reserved for main protocol launch;
  uint256 public developmentFund; // Bucket of inflationary tokens reserved for development - gets transferred to devFundAddress immediately
  uint256 public allocatedRewards; // Bucket of curation reward tokens reserved/'spoken for' but not yet claimed by users
  uint256 public allocatedAirdrops; // Bucket of airdrop reward tokens reserved/'spoken for' but not yet claimed by users

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

    startBlock = block.number;
    currRoundReward = initRoundReward;
    lastRound = 0;
    lastRoundReward = initRoundReward;
    totalPremint = _totalPremint;
    preMintTokens(_totalPremint);
  }

  /**
   * @dev Mint the number of inflationary tokens until constant inflation/target round is reached
   */
  function preMintTokens(uint256 _toBeMinted) internal returns (bool) {
    mint(address(this), _toBeMinted);
    return true;
  }

  /**
   * @dev Compute and release currently releasable inflationary rewards
   */
  function releaseTokens() public returns (bool) {
    uint256 releasableTokens;
    uint256 currentRound = roundNum();
    require(lastRound < currentRound, "No new rewards available"); // Check if already called for the current round
    uint256 roundsPassed = currentRound.sub(lastRound);

    if (lastRound >= targetRound) {
      // Last release was during constant inflation, so we are entirely in the constant inflation phase
      uint256 startTotalTokens = totalReleased;
      releasableTokens = newTokensForConstantPhase(startTotalTokens, roundsPassed);
      mint(address(this), releasableTokens);
    } else {
      // Last release was during the decay phase - 2 nested cases:
      if (currentRound < targetRound) {
        // We are currently still in the decay phase - no new mint, since this is covered by the pre-mint
        releasableTokens = newTokensForDecayPhase(roundsPassed);
      } else {
        // We have recently crossed from the decay phase into the constant inflation phase, so we have to compute separately
        uint256 releasableFromDecay = newTokensForCrossingDecay();
        uint256 releasableFromConst = newTokensForCrossingConst(currentRound);
        releasableTokens = releasableFromDecay.add(releasableFromConst);
        mint(address(this), releasableFromConst);
      }
    }

    splitRewards(releasableTokens); // split into different buckets (rewardFund, airdrop, devFund)
    toDevFund(); // transfer devFund out immediately
    lastRound = currentRound; // Set current round as last release
    totalReleased = totalReleased.add(releasableTokens); // Increase totalReleased count
    emit Released(releasableTokens, rewardFund, airdropFund, developmentFund);
    return true;
  }

  /**
   * @dev Compute number of tokens to release once inflation is constant
   * @param _totalTokens Number of tokens in supply at the beginning of the phase for which the rewards are being calculated
   * @param _roundsPassed Number of rounds since last release
   */
  function newTokensForConstantPhase(uint256 _totalTokens, uint256 _roundsPassed) internal view returns (uint256) {
    uint256 totalTokens = _totalTokens;
    uint256 releasableTokens;
    for (uint i = 0; i < _roundsPassed; i++) {
      uint256 toBeMintedInRound = targetInflation.mul(totalTokens).div(10**uint256(decimals));
      releasableTokens = releasableTokens.add(toBeMintedInRound);
      totalTokens = totalTokens.add(toBeMintedInRound);
    }
    return releasableTokens;
  }

  /**
   * @dev Compute number of tokens to release during decay phase
   * @param _roundsPassed Number of rounds since last update
   */
  function newTokensForDecayPhase(uint256 _roundsPassed) internal returns (uint256) {
    uint256 releasableTokens;
    // if it is the very first release we have to make sure that initRoundReward is included in the release
    if (lastRound == 0) {
      releasableTokens = initRoundReward;
    }
    if (_roundsPassed < 100000) { // this threshold needs to be optimized - for now we always (virtually) use the loop method
    // If the last release was made less than X rounds ago, we use the discrete loop method to add up all new tokens applying roundDecay after each round.
      uint256 roundReward;
      for (uint j = 0; j < _roundsPassed; j++) {
        roundReward = roundDecay.mul(lastRoundReward).div(10**uint256(decimals));
        releasableTokens = releasableTokens.add(roundReward);
        lastRoundReward = roundReward;
      }
    } else {
    // If more rounds have passed we don't want to loop that many times
    // and therefore use integration using the partial sum formula
    // releasableTokens = initReward.add(partialSum(currentRound)).sub(totalReleased);
    // (then still need to set lastRoundReward using A_0*e^(-round/τ))
    }
    return releasableTokens;
  }

  /**
   * @dev Compute number of tokens to release from the decay phase when recently crossed to constant inflation phase
   */
  function newTokensForCrossingDecay() internal view returns (uint256) {
    uint256 releasableFromDecayPhase = totalPremint.sub(totalReleased);
    return releasableFromDecayPhase;
  }

  /**
   * @dev Compute number of tokens to release from the constant inflation phase when recently crossed from decay phase
   * @param _currentRound Round during which current release is made
   */
  function newTokensForCrossingConst(uint256 _currentRound) internal view returns (uint256) {
    uint256 constStartTotalTokens = totalPremint;
    uint256 roundsSinceConstInflation = _currentRound.sub(targetRound).add(1); // including the mint for target and for current round
    uint256 toBeMinted = newTokensForConstantPhase(constStartTotalTokens, roundsSinceConstInflation);
    return toBeMinted;
  }

  /**
   * @dev Put new rewards into the different buckets (userRewards: [airdrop, rewardFund], developmentFund)
   * @param _releasableTokens Amount of tokens that needs to be split up
   */
  function splitRewards(uint256 _releasableTokens) internal {
    uint256 userRewards = _releasableTokens.mul(4).div(5); // 80% of inflation goes to the users
    airdropFund = airdropFund.add(userRewards.div(3));
    rewardFund = rewardFund.add(userRewards.div(3));
    reserveFund = reserveFund.add(userRewards.div(3));
    // For now half of the user rewards are curation rewards and half are signup/referral/airdrop rewards
    // @Proposal for later: Formula for calculating airdrop vs curation reward split: airdrops = user rewards * airdrop base share ^ (roundNumber)
    developmentFund = developmentFund.add(_releasableTokens.div(5)); // 20% of inflation goes to devFund
  }

  /**
   * @dev Calculates total number of tokens to be minted during the decay phase until _round
   * @param _round Round until which the partial sum is taken
   */
  function partialSum(uint256 _round) public view returns (uint256) {
    // TODO: this needs to be worked out! with https://user-images.githubusercontent.com/337721/52804952-7e3f3080-3053-11e9-8bb2-9bc1c3df19ee.jpg
    // and using Bancor's Power formula for e^x
    // alternatively use the integral of the reward function:
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
  * @dev Allocate curation rewards
  * @param _rewards to be reserved for users claims
  */
  function allocateRewards(uint256 _rewards) public onlyOwner returns(bool) {
    require(_rewards <= rewardFund, "Not enough curation rewards available");
    rewardFund = rewardFund.sub(_rewards);
    allocatedRewards = allocatedRewards.add(_rewards);
    return true;
  }

  /**
  * @dev Allocate airdrop rewards
  * @param _rewards to be reserved for user claims
  */
  function allocateAirdrops(uint256 _rewards) public onlyOwner returns(bool) {
    require(_rewards <= airdropFund, "Not enough airdrop rewards available");
    airdropFund = airdropFund.sub(_rewards);
    allocatedAirdrops = allocatedAirdrops.add(_rewards);
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
  * @dev Nonce of user
  * @param _account User account address
  * @return nonce of user
  */
  function nonceOf(address _account) public view returns(uint256) {
    return nonces[_account];
  }

  /**
   * @dev Return current round number // using the state variable set by setRoundNum, for testing
   */
  function roundNum() public view returns (uint256) {
    return (block.number.sub(startBlock)).div(roundLength);
  }

  /**
   * @dev Return rounds since last release
   */
  function roundsSincleLast() public view returns (uint256) {
    return roundNum() - lastRound;
  }
}

