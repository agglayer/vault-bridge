// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (secondary-chain/agglayer/vbETH/WethWormhole.sol)

pragma solidity 0.8.29;

// @remind Document the entire file.

import {CustomTokenWormhole} from "../CustomTokenWormhole.sol";
import {CustomTokenWethExtension} from "../../CustomTokenWethExtension.sol";
import {CustomToken} from "../../CustomToken.sol";
import {ERC20Upgradeable} from "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

/// @title WETH (Wormhole)
/// @author See https://github.com/agglayer/vault-bridge
contract WethWormhole is CustomTokenWormhole, CustomTokenWethExtension {
    constructor() {
        _disableInitializers();
    }

    // @todo nttManager_ needs to be provided in a different way (deployment order).
    function reinitialize1(
        address owner_,
        string memory name_,
        string memory symbol_,
        uint8 originalUnderlyingTokenDecimals_,
        address nttManager_,
        bool gasTokenIsEth_,
        bool wethFunctionalityEnabled_
    ) external whenNotPaused reinitializer(_incrementGlobalInitializationCounter(1)) nonReentrant {
        if (wethFunctionalityEnabled_) require(gasTokenIsEth_, WethFunctionalityCannotBeEnabledIfGasTokenIsNotEth());

        __CustomToken_init1(owner_, name_, symbol_, originalUnderlyingTokenDecimals_, nttManager_, address(0));

        __CustomToken_init2();

        __CustomTokenWethExtension_init2_ext1(gasTokenIsEth_, wethFunctionalityEnabled_);
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

    /// @inheritdoc CustomTokenWethExtension
    function _CUSTOM_TOKEN_WETH_EXTENSION_INIT_2_EXT_1_COMPATIBLE() internal pure override {}
}
