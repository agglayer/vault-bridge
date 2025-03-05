// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.28;

import {CustomToken} from "../../CustomToken.sol";
import {IWETH9} from "../../etc/IWETH9.sol";
import {IVersioned} from "../../etc/IVersioned.sol";

// TODO
// - make upgradeable to enable potential future ETH staking plans

/// @title ZETH
/// @dev based on https://github.com/gnosis/canonical-weth/blob/master/contracts/WETH9.sol
contract WETH is CustomToken {
    event Deposit(address indexed from, uint256 value);
    event Withdrawal(address indexed to, uint256 value);

    constructor() {
        _disableInitializers();
    }

    modifier onlyNativeConverter() {
        require(msg.sender == nativeConverter(), Unauthorized());
        _;
    }

    function initialize(
        address owner_,
        string calldata name_,
        string calldata symbol_,
        uint8 originalUnderlyingTokenDecimals_,
        address lxlyBridge_,
        address nativeConverter_
    ) external initializer {
        // Initialize the inherited contracts.
        __CustomToken_init(owner_, name_, symbol_, originalUnderlyingTokenDecimals_, lxlyBridge_, nativeConverter_);
    }

    // @todo Remove.
    function reinitialize(
        address owner_,
        string calldata name_,
        string calldata symbol_,
        uint8 originalUnderlyingTokenDecimals_,
        address lxlyBridge_,
        address nativeConverter_
    ) external reinitializer(2) {
        // Reinitialize the inherited contracts.
        __CustomToken_init(owner_, name_, symbol_, originalUnderlyingTokenDecimals_, lxlyBridge_, nativeConverter_);
    }

    function bridgeBackingToLayerX(uint256 amount) external onlyNativeConverter {
        (bool success,) = nativeConverter().call{value: amount}("");
        require(success);
    }

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 value) external {
        require(balanceOf(msg.sender) >= value);
        _burn(msg.sender, value);
        payable(msg.sender).transfer(value);
        emit Withdrawal(msg.sender, value);
    }

    /// @inheritdoc IVersioned
    function version() public pure returns (string memory) {
        return "1.0.0";
    }
}
