pragma solidity ^0.5.0;
import "openzeppelin-eth/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-eth/contracts/math/SafeMath.sol";
import "zos-lib/contracts/Initializable.sol";

// this contract could theoretically be integrated into our main token contract, however
// the gas costs of combined deployment are currently above the limit, so for now we use it stand-alone.

contract TimeLock is Initializable {

  using SafeMath for uint256;

  uint256 public duration; // Number of seconds after which withdrawn tokens become available for release.
  address public token_address; // Address of the token that should be locked with this TimeLock contract.

  // A withdrawal is a timestamped instruction from the user to unlock a certain amount of her locked tokens.
  // After the vesting period has passed, these tokens become available for release.
  struct Withdrawal {
    uint256 withdraw_start;
    uint256 withdraw_amount;  
  }
  
  // Every user has a 'nonce state' determined by how many withdrawals have currently been made already,
  // and for which withdrawals, the corresponding token amounts have been released already
  // (this is expressed here by storing nonces for the withdrawal and the release coming next, 
  // i.e. following after the current ones - this makes sense, as we start with nonce values of 0, 
  // even when no withdrawal or release has been made yet).
  struct Nonce {
    uint256 next_withdraw_nonce;
    uint256 next_release_start_nonce;
  }
  
  // This is just an auxiliary struct to return two values at the same time
  // through the internal view function getReleaseInfo():
  struct Release {
    uint256 vested_tokens;
    uint256 next_vesting_nonce;
  }

  // The following mappings store  for every user: the nonce state, currently locked tokens and all withdrawals.
  mapping (address => Nonce) public nonces;
  mapping (address => uint256) public locked_tokens;
  mapping (address => mapping (uint256 => Withdrawal)) public withdrawals;

  /**
   * @dev Initialize the TimeLock contract to connect it with the Relevant Token and set the vesting duration
   * @param _duration Seconds until tokens are unlocked after a user starts withdrawal
   * @param _token_address Address of the Relevant token that can be time-locked with this contract
   */
  function initialize(uint256 _duration, address _token_address) public {
    duration = _duration;
    token_address = _token_address;
  }

  // Note: Before locking, a user needs to approve this TimeLock contract with the corresponding amount
  function lockTokens(uint256 amount) public {
    IERC20(token_address).transferFrom(msg.sender, address(this), amount);
    locked_tokens[msg.sender] = locked_tokens[msg.sender].add(amount);
  }

  function startWithdraw(uint256 amount) public {
    require(amount <= locked_tokens[msg.sender], "You cannot withdraw more tokens than you have locked");
    locked_tokens[msg.sender] = locked_tokens[msg.sender].sub(amount);
    // Store the information for the current withdrawal:
    withdrawals[msg.sender][nonces[msg.sender].next_withdraw_nonce].withdraw_start = block.timestamp;
    withdrawals[msg.sender][nonces[msg.sender].next_withdraw_nonce].withdraw_amount = amount;
    // Update the withdrawal nonce for the next withdrawal:
    nonces[msg.sender].next_withdraw_nonce = nonces[msg.sender].next_withdraw_nonce.add(1);
  }

  function releaseVestedTokens() public {
    // Get the number of tokens (across all withdrawals made so far) that can be released
    Release memory currRelease = getReleaseInfo();
    uint256 unlocked = currRelease.vested_tokens;
    require(unlocked > 0, "No new vested tokens to be released");
    // and the nonce of the withdrawal from which we should be checking at the next release:
    nonces[msg.sender].next_release_start_nonce = currRelease.next_vesting_nonce;
    IERC20(token_address).transfer(msg.sender, unlocked);
  }

  function getReleaseInfo() internal view returns (Release memory) {
    uint256 vestedAmount;
    uint256 lastVest;
    for (uint i = nonces[msg.sender].next_release_start_nonce; i < nonces[msg.sender].next_withdraw_nonce; i++) {
      if (block.timestamp >= withdrawals[msg.sender][i].withdraw_start.add(duration)) {
        vestedAmount = vestedAmount.add(withdrawals[msg.sender][i].withdraw_amount);
        lastVest = i; // this is the nonce of a withdrawal that has fully vested
      }
    }
    if (vestedAmount > 0) {
      return Release(vestedAmount, lastVest + 1);
    }
  }

}