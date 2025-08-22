// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (secondary-chain/agglayer/vbETH/WethWormhole.sol)

pragma solidity 0.8.29;

import {WethCustomToken} from "../../WethCustomToken.sol";
import {CustomTokenWormhole} from "../CustomTokenWormhole.sol";
import {CustomToken} from "../../CustomToken.sol";
import {ERC20Upgradeable} from "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

/// @title WETH (Wormhole)
/// @author See https://github.com/agglayer/vault-bridge
/// @dev based on https://github.com/gnosis/canonical-weth/blob/master/contracts/WETH9.sol
contract WethWormhole is WethCustomToken, CustomTokenWormhole {
    /// @dev Storage of WETH contract.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:agglayer.vault-bridge.WETH.storage
    struct WETHStorage {
        bool _gasTokenIsEth;
    }

    /// @dev The storage slot at which WETH storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("agglayer.vault-bridge.WETH.storage")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _WETH_WORMHOLE_STORAGE =
        hex"df8caff5d0161908572492829df972cd19b1aabe3c3078d95299408cd561dc00";

    function reinitialize1(
        address owner_,
        string memory name_,
        string memory symbol_,
        uint8 originalUnderlyingTokenDecimals_,
        address agglayerBridge_,
        bool gasTokenIsEth_
    ) external whenNotPaused reinitializer(_incrementGlobalInitializationCounter(1)) nonReentrant {
        WETHStorage storage $ = _getWethWormholeStorage();

        // Initialize the base implementation.
        __CustomToken_init(owner_, name_, symbol_, originalUnderlyingTokenDecimals_, agglayerBridge_, address(0));

        $._gasTokenIsEth = gasTokenIsEth_;

        __CustomToken_init2();
    }

    /*
    /// @dev How to add a new reinitializer:
    function reinitialize2()
        external
        whenNotPaused
        reinitializer(_incrementGlobalInitializationCounter(2))
        nonReentrant
    {}
    */

    /// @inheritdoc CustomToken
    function _CUSTOM_TOKEN_INIT_2_COMPATIBLE() internal pure override {}

    function _getWethWormholeStorage() private pure returns (WETHStorage storage $) {
        assembly {
            $.slot := _WETH_WORMHOLE_STORAGE
        }
    }

    function _gasTokenIsEth() internal view override returns (bool) {
        return _getWethWormholeStorage()._gasTokenIsEth;
    }
}
