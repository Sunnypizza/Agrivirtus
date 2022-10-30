// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PowerToken is ERC20, AccessControl, Ownable {

    // Create a new role identifier for the minter role
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor() ERC20("PowerToken", "PWT") {}

    // For minting new Tokens
    function mint(address to, uint256 amount) public {
        // Check that the calling account has the minter role
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
        _mint(to, amount);
    }

    // For burning the Tokens
    function burn(address from, uint256 amount) public {
        require(hasRole(BURNER_ROLE, msg.sender), "Caller is not a burner");
        _burn(from, amount);
    }

    // Owner of the token can set provide minter role any of the user
    function setMinter(address _minter) public onlyOwner {
        _setupRole(MINTER_ROLE, _minter);
    }

    // Owner of the token can set provide burner role any of the user
    function setBurner(address _burner) public onlyOwner {
        _setupRole(BURNER_ROLE, _burner);
    }

}