pragma solidity ^0.5.0;
import "openzeppelin-eth/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-eth/contracts/math/SafeMath.sol";
import "zos-lib/contracts/Initializable.sol";

// this contract could theoretically be integrated into our main token contract, however
// the gas costs of combined deployment are currently above the limit, so for now we use it stand-alone.

contract TimeLock is Initializable {

  using SafeMath for uint256;
  
  struct Withdrawal {
    uint256 withdraw_start;
    uint256 withdraw_amount;  
  }
  
  struct Nonce {
    uint256 next_withdraw_nonce;
    uint256 next_release_start_nonce;
  }
  
  struct Release {
    uint256 vested_tokens;
    uint256 next_vesting_nonce;
  }

  mapping (address => Nonce) public nonces;
  mapping (address => uint256) public locked_tokens;
  mapping (address => mapping (uint256 => Withdrawal)) public withdrawals;
  
  uint256 public duration;
  address public token_address;

  /**
   * @dev Initialize the TimeLock contract to connect it with the Relevant Token and set the vesting duration
   * @param _duration Seconds until tokens are unlocked after a user starts withdrawal
   * @param _token Address of the Relevant token that can be time-locked with this contract
   */
  function initialize(uint256 _duration, address _token) public {
    duration = _duration;
    token_address = _token_address;
  }
  
  function lockTokens(uint256 amount) public {
    IERC20(token).transferFrom(msg.sender, address(this), amount);
    locked_tokens[msg.sender] = locked_tokens[msg.sender].add(amount);
  }

  function startWithdraw(uint256 amount) public {
    require(amount <= locked_tokens[msg.sender]);
    locked_tokens[msg.sender] = locked_tokens[msg.sender].sub(amount);
    withdrawals[msg.sender][nonces[msg.sender].next_withdraw_nonce].withdraw_start = block.timestamp;
    withdrawals[msg.sender][nonces[msg.sender].next_withdraw_nonce].withdraw_amount = amount;
    nonces[msg.sender].next_withdraw_nonce = nonces[msg.sender].next_withdraw_nonce.add(1);
  }

  function releaseVestedTokens() public {
    Release memory currRelease = getReleaseInfo();
    uint256 unlocked = currRelease.vested_tokens;
    require(unlocked > 0, "No new vested tokens to be released");
    nonces[msg.sender].next_release_start_nonce = currRelease.next_vesting_nonce;
    IERC20(token).transfer(msg.sender, unlocked);
  }

  function getReleaseInfo() public view returns (Release memory) {
    uint256 vestedAmount;
    uint256 lastVest;
    for (uint i = nonces[msg.sender].next_release_start_nonce; i < nonces[msg.sender].next_withdraw_nonce; i++) {
      if (block.timestamp >= withdrawals[msg.sender][i].withdraw_start.add(duration)) {
        vestedAmount = vestedAmount.add(withdrawals[msg.sender][i].withdraw_amount);
        lastVest = i;
      }
    }
    if (vestedAmount > 0) {
      return Release(vestedAmount, lastVest + 1);
    }
  }

}