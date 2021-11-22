pragma solidity ^0.5.0;

import "../RelevantTokenV3.sol";

contract RelevantTokenV3Mock is RelevantTokenV3 {
  function initialize() public initializer {
    Ownable.initialize(msg.sender);
    _mint(address(this), 100 ether);
    allocatedRewards = 50 ether;
    symbol = "REL";
    name = "Relevant";
    decimals = 18;
  }
}
