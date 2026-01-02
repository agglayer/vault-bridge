// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.0) (secondary-chain/CustomTokenWethExtension.sol)

pragma solidity 0.8.29;

// @remind Document the entire file.

// Main functionality.
import {CustomToken} from "./CustomToken.sol";

// External contracts.
import {IAgglayerBridge} from "../etc/IAgglayerBridge.sol";
import {NativeConverter} from "./NativeConverter.sol";

/// @title Custom Token WETH Extension
/// @author See https://github.com/agglayer/vault-bridge
abstract contract CustomTokenWethExtension is CustomToken {
    /// @dev Storage of Custom Token WETH Extension.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:agglayer.vault-bridge.CustomTokenWethExtension.storage
    struct CustomTokenWethExtensionStorage {
        bool _gasTokenIsEth;
        uint256 gasBackingOnSecondaryChain;
        bool wethFunctionalityEnabled;
    }

    /// @dev The storage slot at which Custom Token WETH Extension storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("agglayer.vault-bridge.CustomTokenWethExtension.storage")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _CUSTOM_TOKEN_WETH_EXTENSION_STORAGE =
        hex"79530e5f68ac2fe03ca888330cb59cd18fe7ab48bdc97271c9f69b4c84c28700";

    error FunctionNotSupportedOnThisChain();
    error FunctionNotEnabledOnThisChain();
    error AssetsTooLarge(uint256 availableAssets, uint256 requestedAssets);
    error WithdrawalFailed();
    error WethFunctionalityCannotBeEnabledIfGasTokenIsNotEth();

    event Deposit(address indexed from, uint256 value);
    event Withdrawal(address indexed to, uint256 value);
    event WethFunctionalityEnabledSet(bool enabled);

    modifier onlyNativeConverter() {
        require(msg.sender == nativeConverter(), Unauthorized());
        _;
    }

    modifier onlyIfGasTokenIsEth() {
        CustomTokenWethExtensionStorage storage $ = _getCustomTokenWethExtensionStorage();
        require($._gasTokenIsEth, FunctionNotSupportedOnThisChain());
        _;
    }

    modifier onlyIfWethFunctionalityEnabled() {
        CustomTokenWethExtensionStorage storage $ = _getCustomTokenWethExtensionStorage();
        require($.wethFunctionalityEnabled, FunctionNotEnabledOnThisChain());
        _;
    }

    function __CustomTokenWethExtension_init2_ext1(bool gasTokenIsEth_, bool wethFunctionalityEnabled_)
        internal
        onlyInitializing
        incrementsExtensionInitializationCounter(2, Extension.WETH, 1)
    {
        CustomTokenWethExtensionStorage storage $ = _getCustomTokenWethExtensionStorage();

        $._gasTokenIsEth = gasTokenIsEth_;
        $.wethFunctionalityEnabled = wethFunctionalityEnabled_;
    }

    /*
    /// @dev How to add a new ext step:
    function __CustomTokenWethExtension_initX_ext2()
        internal
        onlyInitializing
        incrementsExtensionInitializationCounter(X, Extension.WETH, 2)
    {}
    */

    function _CUSTOM_TOKEN_WETH_EXTENSION_INIT_2_EXT_1_COMPATIBLE() internal pure virtual;

    function gasBackingOnSecondaryChain() public view returns (uint256) {
        CustomTokenWethExtensionStorage storage $ = _getCustomTokenWethExtensionStorage();
        return $.gasBackingOnSecondaryChain;
    }

    function wethFunctionalityEnabled() public view returns (bool) {
        CustomTokenWethExtensionStorage storage $ = _getCustomTokenWethExtensionStorage();
        return $.wethFunctionalityEnabled;
    }

    receive() external payable whenNotPaused onlyIfGasTokenIsEth onlyIfWethFunctionalityEnabled nonReentrant {
        _deposit();
    }

    /// @notice Same as WETH9 deposit function.
    function deposit() external payable whenNotPaused onlyIfGasTokenIsEth onlyIfWethFunctionalityEnabled nonReentrant {
        _deposit();
    }

    function _deposit() internal {
        CustomTokenWethExtensionStorage storage $ = _getCustomTokenWethExtensionStorage();
        $.gasBackingOnSecondaryChain += msg.value;
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Same as WETH9 withdraw function, but liqudity is guaranteed only up to a certain percentage.
    function withdraw(uint256 value) external whenNotPaused onlyIfGasTokenIsEth nonReentrant {
        CustomTokenWethExtensionStorage storage $ = _getCustomTokenWethExtensionStorage();
        require(value <= $.gasBackingOnSecondaryChain, AssetsTooLarge($.gasBackingOnSecondaryChain, value));
        $.gasBackingOnSecondaryChain -= value;
        _burn(msg.sender, value);
        (bool ok,) = msg.sender.call{value: value}("");
        require(ok, WithdrawalFailed());
        emit Withdrawal(msg.sender, value);
    }

    function moveGasBackingToNativeConverter(uint256 amount)
        external
        onlyIfGasTokenIsEth
        onlyNativeConverter
        nonReentrant
    {
        CustomTokenWethExtensionStorage storage $ = _getCustomTokenWethExtensionStorage();
        require(amount <= $.gasBackingOnSecondaryChain, AssetsTooLarge($.gasBackingOnSecondaryChain, amount));
        $.gasBackingOnSecondaryChain -= amount;
        (bool ok,) = nativeConverter().call{value: amount}("");
        require(ok);
    }

    function setWethFunctionalityEnabled(bool wethFunctionalityEnabled_) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        CustomTokenWethExtensionStorage storage $ = _getCustomTokenWethExtensionStorage();
        if (wethFunctionalityEnabled_) require($._gasTokenIsEth, WethFunctionalityCannotBeEnabledIfGasTokenIsNotEth());
        $.wethFunctionalityEnabled = wethFunctionalityEnabled_;
        emit WethFunctionalityEnabledSet(wethFunctionalityEnabled_);
    }

    function _getCustomTokenWethExtensionStorage() private pure returns (CustomTokenWethExtensionStorage storage $) {
        assembly {
            $.slot := _CUSTOM_TOKEN_WETH_EXTENSION_STORAGE
        }
    }
}
