// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (secondary-chain/agglayer/vbETH/WethWormhole.sol)

pragma solidity 0.8.29;

// @remind Document the entire file.

import {WethCustomToken} from "../../WethCustomToken.sol";
import {CustomTokenWormhole} from "../CustomTokenWormhole.sol";
import {CustomToken} from "../../CustomToken.sol";
import {ERC20Upgradeable} from "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

/// @title WETH (Wormhole)
/// @author See https://github.com/agglayer/vault-bridge
contract WethWormhole is WethCustomToken, CustomTokenWormhole {
    constructor() {
        _disableInitializers();
    }

    function reinitialize1(
        address owner_,
        string memory name_,
        string memory symbol_,
        uint8 originalUnderlyingTokenDecimals_,
        address agglayerBridge_,
        bool gasTokenIsEth_
    ) external whenNotPaused reinitializer(_incrementGlobalInitializationCounter(1)) nonReentrant {
        __CustomToken_init1(owner_, name_, symbol_, originalUnderlyingTokenDecimals_, agglayerBridge_, address(0));

        __CustomToken_init2();

        __WethCustomToken_init1(gasTokenIsEth_);
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

    /// @inheritdoc WethCustomToken
    function _WETH_CUSTOM_TOKEN_INIT_1_COMPATIBLE() internal pure override {}
}
