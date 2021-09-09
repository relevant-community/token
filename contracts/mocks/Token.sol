//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC20, Ownable {
  constructor(string memory symbol) ERC20(symbol, symbol) {
    _mint(msg.sender, 10 ** 36);
  }
  function mintTo(address account, uint amount) public onlyOwner {
    _mint(account, amount);
  }
}