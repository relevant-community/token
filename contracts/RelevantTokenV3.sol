pragma solidity ^0.5.2;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/cryptography/ECDSA.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";

contract RelevantTokenV3 is Initializable, ERC20, Ownable {
  event Released(uint256 amount, uint256 hoursSinceLast);
  event Claimed(address indexed account, uint256 amount);
  
  uint256[101] private ______gap; // ERC20Minter gaps

  string public name;
  uint8 public decimals;
  string public symbol;
  string public version;
  address public admin; // (former dev fund address) this account is allowed to distribute rewards

  uint256 public inflation; // yearly inflation rate in basis points
  uint256 public lastReward; // timestamp when last reward was issued

  uint256[15] private ______gap1; // gap from prev version


  uint256 public allocatedRewards; // temporary - to be removed in future version for cleaner logic


  uint256 private ______gap2;  // gap from prev version

  mapping(address => uint256) nonces;

  uint256[4] private ______gap3; // gap from prev version

  bool public initializedV3;

  // Initialize the current version
  function initV3(address _admin) public onlyOwner {
    require(initializedV3 == false, "Relevant: this version has already been initialized");
    lastReward = block.timestamp;
    version = "v3";
    initializedV3 = true;
    admin = _admin;
    inflation = 0;  // initialize inflation at 0 to avoid accidentaly reading previous values
  }

  function setInflation(uint256 _inflation) public onlyOwner {
    inflation = _inflation;
  }

  function setAdmin(address _admin) public onlyOwner {
    admin = _admin;
  }

  // Burn tokens that belong to the smart contract but are not allocatedRewards
  function burn(uint256 amount) public onlyOwner {
    require(balanceOf(address(this)).sub(allocatedRewards) >= amount, "Relevant: cannot burn allocated tokens");
    _burn(address(this), amount);
  }

  function updateAllocatedRewards(uint256 newAllocatedRewards) public onlyOwner {
    require(newAllocatedRewards <= balanceOf(address(this)), "Relevant: there aren't enough tokens in the contract");
    require(newAllocatedRewards >= allocatedRewards, "Relevant: amount of allocated tokens cannot be reduced");
    allocatedRewards = newAllocatedRewards;
  }

  // send allocated tokens to vesting contracs
  // should we hardcode vestingContract or make this a generic recover funds method?
  function vestAllocatedTokens(address vestingContract, uint256 amount) public onlyOwner {
    require(allocatedRewards >= amount, "Relevant: there aren't enough tokens in the contract");
    _transfer(address(this), vestingContract, amount);
    allocatedRewards = allocatedRewards.sub(amount);
  }

  // Compute and mint inflationary rewards (at most once a day)
  function releaseTokens() public {
    require(initializedV3 == true, "Relevant: this version has not been initialized");
    require(inflation > 0, "Relevant: inflation rate has not been set");
    uint256 hoursSinceLast = (block.timestamp.sub(lastReward)).div(1 hours);
    require(hoursSinceLast/24 > 0, "Relevant: less than one day from last reward");

    uint256 rewardAmount = totalSupply().mul(hoursSinceLast).mul(inflation).div(10000).div(365).div(24);
    allocatedRewards = allocatedRewards.add(rewardAmount);

    uint256 balance = balanceOf(address(this));

    // currently there are tokens in the smart contract pre-allocated as rewards
    // while the contract holds more tokens than are allocated as rewards, we don't need to mint new tokens
    if (balance < allocatedRewards) {  
      uint256 mintAmount = allocatedRewards.sub(balance); 
      _mint(address(this), mintAmount);
    }
    lastReward = block.timestamp;

    emit Released(rewardAmount, hoursSinceLast);
  }

  // Claim curation reward tokens (to be called by user)
  function claimTokens(uint256 amount, bytes memory signature) public {
    require(allocatedRewards >= amount, "Relevant: there aren't enough tokens in the contract");
    bytes32 hash = keccak256(abi.encodePacked(amount, msg.sender, nonces[msg.sender]));
    hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));

    // check that the message was signed by contract owner
    address signer = ECDSA.recover(hash, signature);
    require(admin == signer, "Relevant: claim not authorized");
    nonces[msg.sender] += 1;
    allocatedRewards = allocatedRewards.sub(amount);
    _transfer(address(this), msg.sender, amount);
    emit Claimed(msg.sender, amount);
  }

  function nonceOf(address account) public view returns(uint256) {
    return nonces[account];
  }
}

