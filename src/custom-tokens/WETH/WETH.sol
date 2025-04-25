// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.29;

// @todo REVIEW.

import {CustomToken} from "../../CustomToken.sol";
import {IWETH9} from "../../etc/IWETH9.sol";
import {IVersioned} from "../../etc/IVersioned.sol";
import {ILxLyBridge} from "../../etc/ILxLyBridge.sol";

// @todo Waiting for a confirmation on what the following comment means before removing it.
// TODO
// - make upgradeable to enable potential future ETH staking plans

/// @title WETH
/// @dev based on https://github.com/gnosis/canonical-weth/blob/master/contracts/WETH9.sol
contract WETH is CustomToken {
    /// @dev Storage of WETH contract.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:0xpolygon.storage.WETH
    struct WETHStorage {
        bool _gasTokenIsEth;
    }

    // @todo Change the namespace. If upgrading the testnet contracts, add a reinitializer and clean the old slots using assembly.
    /// @dev The storage slot at which WETH storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("0xpolygon.storage.WETH")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _WETH_STORAGE = hex"6d4cb2d05573f65a3f078817242fe7f4fc2dbdfbcc81ab3f1b74c8991c679300";

    error AssetsTooLarge(uint256 availableAssets, uint256 requestedAssets);
    error FunctionNotSupportedOnThisNetwork();

    event Deposit(address indexed from, uint256 value);
    event Withdrawal(address indexed to, uint256 value);

    constructor() {
        _disableInitializers();
    }

    modifier onlyNativeConverter() {
        require(msg.sender == nativeConverter(), Unauthorized());
        _;
    }

    modifier onlyIfGasTokenIsEth() {
        require(_getWETHStorage()._gasTokenIsEth, FunctionNotSupportedOnThisNetwork());
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
        WETHStorage storage $ = _getWETHStorage();

        // Initialize the inherited contracts.
        __CustomToken_init(owner_, name_, symbol_, originalUnderlyingTokenDecimals_, lxlyBridge_, nativeConverter_);

        $._gasTokenIsEth =
            ILxLyBridge(lxlyBridge_).gasTokenAddress() == address(0) && ILxLyBridge(lxlyBridge_).gasTokenNetwork() == 0;
    }

    function _getWETHStorage() private pure returns (WETHStorage storage $) {
        assembly {
            $.slot := _WETH_STORAGE
        }
    }

    /*
    // @todo Remove. (Required for the testnet).
    function reinitialize(
        address owner_,
        string calldata name_,
        string calldata symbol_,
        uint8 originalUnderlyingTokenDecimals_,
        address lxlyBridge_,
        address nativeConverter_
    ) external reinitializer(3) {
        // Reinitialize the inherited contracts.
        __CustomToken_init(owner_, name_, symbol_, originalUnderlyingTokenDecimals_, lxlyBridge_, nativeConverter_);
    }
    */

    function bridgeBackingToLayerX(uint256 amount)
        external
        whenNotPaused
        onlyIfGasTokenIsEth
        onlyNativeConverter
        nonReentrant
    {
        (bool success,) = nativeConverter().call{value: amount}("");
        require(success);
    }

    receive() external payable whenNotPaused onlyIfGasTokenIsEth nonReentrant {
        _deposit();
    }

    function deposit() external payable whenNotPaused onlyIfGasTokenIsEth nonReentrant {
        _deposit();
    }

    function _deposit() internal {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 value) external whenNotPaused onlyIfGasTokenIsEth nonReentrant {
        _burn(msg.sender, value);
        uint256 availableAssets = address(this).balance;
        require(availableAssets >= value, AssetsTooLarge(availableAssets, value));
        payable(msg.sender).transfer(value);
        emit Withdrawal(msg.sender, value);
    }

    /// @inheritdoc IVersioned
    function version() public pure returns (string memory) {
        return "1.0.0";
    }
}
