// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (secondary-chain/WethCustomToken.sol)

pragma solidity 0.8.29;

// Main functionality.
import {CustomToken} from "./CustomToken.sol";

/// @title WETH Custom Token
/// @author See https://github.com/agglayer/vault-bridge
abstract contract WethCustomToken is CustomToken {
    /// @dev Storage of WETH contract.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:agglayer.vault-bridge.WETH.storage
    struct WETHStorage {
        bool _gasTokenIsEth;
    }

    /// @dev The storage slot at which WETH storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("agglayer.vault-bridge.WETH.storage")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _WETH_CUSTOM_TOKEN_STORAGE =
        hex"df8caff5d0161908572492829df972cd19b1aabe3c3078d95299408cd561dc00";

    error AssetsTooLarge(uint256 availableAssets, uint256 requestedAssets);
    error FunctionNotSupportedOnThisChain();

    event Deposit(address indexed from, uint256 value);
    event Withdrawal(address indexed to, uint256 value);

    modifier onlyNativeConverter() {
        require(msg.sender == nativeConverter(), Unauthorized());
        _;
    }

    modifier onlyIfGasTokenIsEth() {
        WETHStorage storage $ = _getWethCustomTokenStorage();
        require($._gasTokenIsEth, FunctionNotSupportedOnThisChain());
        _;
    }

    receive() external payable whenNotPaused onlyIfGasTokenIsEth nonReentrant {
        _deposit();
    }

    function __WethCustomToken_init1(bool gasTokenIsEth_) internal onlyInitializing {
        WETHStorage storage $ = _getWethCustomTokenStorage();

        $._gasTokenIsEth = gasTokenIsEth_;
    }

    function _WETH_CUSTOM_TOKEN_INIT_1_COMPATIBLE() internal pure virtual;

    /// @notice Same as WETH9 deposit function.
    function deposit() external payable whenNotPaused onlyIfGasTokenIsEth nonReentrant {
        _deposit();
    }

    function _deposit() internal {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Same as WETH9 withdraw function, but liqudity is guaranteed only up to a certain percentage.
    function withdraw(uint256 value) external whenNotPaused onlyIfGasTokenIsEth nonReentrant {
        _burn(msg.sender, value);
        uint256 availableAssets = address(this).balance;
        require(availableAssets >= value, AssetsTooLarge(availableAssets, value));
        payable(msg.sender).transfer(value);
        emit Withdrawal(msg.sender, value);
    }

    function bridgeBackingToPrimaryChain(uint256 amount)
        external
        whenNotPaused
        onlyIfGasTokenIsEth
        onlyNativeConverter
        nonReentrant
    {
        (bool success,) = nativeConverter().call{value: amount}("");
        require(success);
    }

    function _getWethCustomTokenStorage() private pure returns (WETHStorage storage $) {
        assembly {
            $.slot := _WETH_CUSTOM_TOKEN_STORAGE
        }
    }
}
