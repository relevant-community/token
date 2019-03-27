pragma solidity ^0.5.0;
import "openzeppelin-eth/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-eth/contracts/math/SafeMath.sol";
import "zos-lib/contracts/Initializable.sol";

// this whole contract could be integrated into our main token contract
// for now we use it stand-alone because gas costs of combined deployment are above the limit.

contract TimeLock is Initializable {

  using SafeMath for uint256;

  mapping (address => uint256) public lock_nonce;
  mapping (address => uint256) public withdraw_nonce;
  mapping (address => mapping (uint256 => uint256)) public locked_tokens;
  mapping (address => mapping (uint256 => uint256)) public withdraw_start;
  mapping (address => mapping (uint256 => uint256)) public released;
  uint256 public duration;
  address public token;
  bool public vesting;

  /**
   * @dev Initialize the storage variable added as part of the TimeVesting upgrade
   * @param _duration Seconds until all tokens are unlocked after a user starts withdrawal
   * @param _token Address of the Relevant token that can be time-locked with this contract
   */
  function initialize(uint256 _duration, address _token, bool _vesting) public {
    duration = _duration;
    token = _token;
    vesting = _vesting;
  }

  function lockTokens(uint256 amount) public {
    IERC20(token).transferFrom(msg.sender, address(this), amount);
    locked_tokens[msg.sender][lock_nonce[msg.sender]] = locked_tokens[msg.sender][lock_nonce[msg.sender]].add(amount);
  }

  function startWithdraw() public {
    require(withdraw_start[msg.sender][withdraw_nonce[msg.sender]] == 0, "Vested tokens from previous withdrawal not entirely released yet.");
    withdraw_start[msg.sender][withdraw_nonce[msg.sender]] = block.timestamp;
    lock_nonce[msg.sender] = lock_nonce[msg.sender].add(1);
  }


  function releaseVestedTokens() public {
    uint256 unreleased = releasableAmount();
    require(unreleased > 0, "No new vested tokens to be released");
    released[msg.sender][withdraw_nonce[msg.sender]] = released[msg.sender][withdraw_nonce[msg.sender]].add(unreleased);
    IERC20(token).transfer(msg.sender, unreleased);
    if (block.timestamp >= withdraw_start[msg.sender][withdraw_nonce[msg.sender]].add(duration)) {
      withdraw_nonce[msg.sender] = withdraw_nonce[msg.sender].add(1);
    }
  }

  function releasableAmount() public view returns (uint256) {
    return vestedAmount() - released[msg.sender][withdraw_nonce[msg.sender]];
  }

  function vestedAmount() public view returns (uint256) {
    uint256 totalBalance = locked_tokens[msg.sender][withdraw_nonce[msg.sender]];

    if (withdraw_start[msg.sender][withdraw_nonce[msg.sender]] == 0) {
      return 0;
    } else if (block.timestamp >= withdraw_start[msg.sender][withdraw_nonce[msg.sender]].add(duration)) {
      return totalBalance;
    } else if (vesting) {
      return totalBalance.mul(block.timestamp.sub(withdraw_start[msg.sender][withdraw_nonce[msg.sender]])).div(duration);
    } else {
      return 0;
    }
  }

} 


