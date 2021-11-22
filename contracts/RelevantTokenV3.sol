pragma solidity ^0.5.0;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/cryptography/ECDSA.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";

contract RelevantTokenV3 is Initializable, ERC20, Ownable {
  event Released(uint256 amount, uint256 secondsSinceLast, uint256 timestamp);
  event Claimed(address indexed account, uint256 amount);
  event SetAdmin(address admin);
  event SetInflation(uint256 inflation);
  event UpdateAllocatedRewards(uint256 allocatedRewards);

  uint256[101] private ______gap; // gap from prev version

  string public name;
  uint8 public decimals;
  string public symbol;
  string public version;
  address public admin; // (former dev fund address) this account is allowed to distribute rewards

  uint256 public inflation; // yearly inflation rate in basis points
  uint256 public lastReward; // timestamp when last reward was issued

  uint256[15] private ______gap1; // gap from prev version

  uint256 public allocatedRewards; // temporary - to be removed in future version for cleaner logic

  uint256 private ______gap2; // gap from prev version

  mapping(address => uint256) private nonces;

  uint256[4] private ______gap3; // gap from prev version

  bool public initializedV3;

  uint256 private constant INFLATION_DENOM = 1 days * 356 * 10000;

  // keccak256("ClaimTokens(address account,uint256 amount,uint256 nonce)")
  bytes32 public constant CLAIM_HASH =
    0xa53a2b3fab2ad1dd8877a41407c34f62362beca7419151220729194783585d4c;

  bytes32 public DOMAIN_SEPARATOR;

  // Initialize the current version
  function initV3(address _admin, uint256 _inflation) public onlyOwner {
    require(!initializedV3, "Rel: v3 already initialized");
    lastReward = block.timestamp;
    version = "v3";
    initializedV3 = true;
    setAdmin(_admin);
    setInflation(_inflation);

    bytes32 nameHash = keccak256(bytes(name));
    bytes32 versionHash = keccak256(bytes("1"));
    bytes32 typeHash = keccak256(
      "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    DOMAIN_SEPARATOR = keccak256(abi.encode(typeHash, nameHash, versionHash, 1, address(this)));
  }

  function setInflation(uint256 _inflation) public onlyOwner {
    require(initializedV3, "Rel: v3 not initialized");
    inflation = _inflation;
    emit SetInflation(_inflation);
  }

  function setAdmin(address _admin) public onlyOwner {
    require(initializedV3, "Rel: v3 not initialized");
    admin = _admin;
    emit SetAdmin(admin);
  }

  // Burn tokens that belong to the smart contract but are not allocatedRewards
  function burn(uint256 amount) public onlyOwner {
    _burn(address(this), amount);
    require(balanceOf(address(this)) >= allocatedRewards, "Rel: cannot burn allocated tokens");
  }

  function updateAllocatedRewards(uint256 newAllocatedRewards) public onlyOwner {
    require(newAllocatedRewards <= balanceOf(address(this)), "Rel: not enough tokens in contract");
    require(newAllocatedRewards >= allocatedRewards, "Rel: allocatedRewards cannot decrease");
    allocatedRewards = newAllocatedRewards;
    emit UpdateAllocatedRewards(allocatedRewards);
  }

  // send allocated tokens to vesting contracs
  // should we hardcode vestingContract or make this a generic recover funds method?
  function vestAllocatedTokens(address vestingContract, uint256 amount) public onlyOwner {
    require(allocatedRewards >= amount, "Rel: not enough allocated tokens");
    _transfer(address(this), vestingContract, amount);
    allocatedRewards = allocatedRewards.sub(amount);
  }

  // Compute and mint inflationary rewards (at most once a day)
  function releaseTokens() public {
    require(initializedV3, "Rel: v3 not initialized");
    require(inflation > 0, "Rel: inflation is 0");
    uint256 secondsSinceLast = (block.timestamp.sub(lastReward));
    require(secondsSinceLast / (1 days) > 0, "Rel: less than one day from last reward");

    uint256 rewardAmount = totalSupply().mul(secondsSinceLast).mul(inflation).div(INFLATION_DENOM);

    allocatedRewards = allocatedRewards.add(rewardAmount);

    uint256 balance = balanceOf(address(this));

    // currently there are tokens in the smart contract pre-allocated as rewards
    // while the contract holds more tokens than are allocated as rewards, we don't need to mint new tokens
    if (balance < allocatedRewards) {
      uint256 mintAmount = allocatedRewards.sub(balance);
      _mint(address(this), mintAmount);
    }
    lastReward = block.timestamp;

    emit Released(rewardAmount, secondsSinceLast, lastReward);
  }

  // Claim curation reward tokens (to be called by user)
  function claimTokens(uint256 amount, bytes memory signature) public {
    require(initializedV3, "Rel: v3 not initialized");
    require(allocatedRewards >= amount, "Rel: not enough allocated tokens");
    uint256 nonce = nonces[msg.sender];

    bytes32 structHash = keccak256(abi.encode(CLAIM_HASH, msg.sender, amount, nonce));
    bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));

    // check that the message was signed by contract owner
    address signer = ECDSA.recover(digest, signature);

    require(admin == signer, "Rel: claim not authorized");
    nonces[msg.sender] = nonce + 1;
    allocatedRewards = allocatedRewards.sub(amount);
    _transfer(address(this), msg.sender, amount);
    emit Claimed(msg.sender, amount);
  }

  function nonceOf(address account) public view returns (uint256) {
    return nonces[account];
  }
}
