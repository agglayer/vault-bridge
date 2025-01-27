// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.28;

import {OwnableUpgradeable} from "@openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IWETH9} from "../etc/IWETH9.sol";

// TODO
// - make upgradeable to enable potential future ETH staking plans

/// @title ZETH
/// @dev based on https://github.com/gnosis/canonical-weth/blob/master/contracts/WETH9.sol
contract ZETH is OwnableUpgradeable {
    string public name;
    string public symbol;
    uint8 public decimals;

    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor() {
        _disableInitializers();
    }

    /// @notice Owner should be WETHNativeConverter.
    function initialize(address owner) external initializer {
        __Ownable_init(owner);

        name = "zETH";
        symbol = "ZETH";
        decimals = 18;
    }

    function bridgeBackingToLayerX(uint256 amount) external onlyOwner {
        (bool success, ) = owner().call{value: amount}("");
        require(success);
    }

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) public {
        require(balanceOf[msg.sender] >= wad);
        balanceOf[msg.sender] -= wad;
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }

    function mint(address dst, uint256 wad) public onlyOwner {
        balanceOf[dst] += wad;
        emit Transfer(address(0), dst, wad);
    }

    function burn(address src, uint256 wad) public onlyOwner {
        require(balanceOf[src] >= wad);
        balanceOf[src] -= wad;
        emit Transfer(src, address(0), wad);
    }

    function totalSupply() public view returns (uint256) {
        return address(this).balance;
    }

    function approve(address guy, uint256 wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    function transfer(address dst, uint256 wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint256 wad) public returns (bool) {
        require(balanceOf[src] >= wad);

        if (src != msg.sender && allowance[src][msg.sender] != type(uint256).max) {
            require(allowance[src][msg.sender] >= wad);
            allowance[src][msg.sender] -= wad;
        }

        balanceOf[src] -= wad;
        balanceOf[dst] += wad;

        emit Transfer(src, dst, wad);

        return true;
    }
}
