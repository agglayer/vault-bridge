// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.0) (secondary-chain/wormhole/vbETH/WethWormhole.sol)

pragma solidity 0.8.29;

// @remind Document the entire file.

import {CustomTokenWormhole} from "../CustomTokenWormhole.sol";
import {CustomTokenWethExtension} from "../../CustomTokenWethExtension.sol";
import {CustomToken} from "../../CustomToken.sol";

/// @title WETH (Wormhole)
/// @author See https://github.com/agglayer/vault-bridge
contract WethWormhole is CustomTokenWormhole, CustomTokenWethExtension {
    constructor() {
        _disableInitializers();
    }

    function reinitialize1(
        address owner_,
        string memory name_,
        string memory symbol_,
        uint8 originalUnderlyingTokenDecimals_,
        address nttManager_,
        bool gasTokenIsEth_
    ) external locked reinitializer(_incrementGlobalInitializationCounter(1)) nonReentrant {
        __CustomToken_init1(owner_, name_, symbol_, originalUnderlyingTokenDecimals_, nttManager_, address(0));

        __CustomToken_init2();

        __CustomTokenWethExtension_init2_ext1(gasTokenIsEth_, false);
    }

    /*
    /// @dev How to add a new reinitializer:
    function reinitialize2()
        external
        locked
        reinitializer(_incrementGlobalInitializationCounter(2))
        nonReentrant
    {}
    */

    // @remind Document (the entire function).
    function reinitialize(bytes[] calldata reinitializeData) external {
        bytes4[] memory reinitializeSelectors = new bytes4[](1);

        reinitializeSelectors[0] = this.reinitialize1.selector;

        _reinitialize(reinitializeSelectors, reinitializeData);
    }

    /// @inheritdoc CustomToken
    function _CUSTOM_TOKEN_INIT_2_COMPATIBLE() internal pure override {}

    /// @inheritdoc CustomTokenWethExtension
    function _CUSTOM_TOKEN_WETH_EXTENSION_INIT_2_EXT_1_COMPATIBLE() internal pure override {}

    function setNativeConverter(address)
        external
        view
        override(CustomToken, CustomTokenWormhole)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        revert FunctionNotSupportedWithThisBridgeProvider();
    }

    function setWethFunctionalityEnabled(bool) external view override onlyRole(DEFAULT_ADMIN_ROLE) {
        revert FunctionNotSupportedWithThisBridgeProvider();
    }
}
