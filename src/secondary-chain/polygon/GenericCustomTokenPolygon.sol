// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (secondary-chain/polygon/GenericCustomTokenPolygon.sol)

pragma solidity 0.8.29;

// Main functionality.
import {CustomTokenPolygon} from "./CustomTokenPolygon.sol";
import {CustomToken} from "../CustomToken.sol";

// @remind Update documentation.
/// @title Generic Custom Token (Polygon)
/// @author See https://github.com/agglayer/vault-bridge
/// @dev This contract can be used to deploy Custom Tokens that do not require any customization.
contract GenericCustomTokenPolygon is CustomTokenPolygon {
    // -----================= ::: SETUP ::: =================-----

    constructor() {
        _disableInitializers();
    }

    // @remind Document (the entire function).
    function reinitialize1(
        address owner_,
        string memory name_,
        string memory symbol_,
        uint8 originalUnderlyingTokenDecimals_,
        address childChainManager_
    ) external whenNotPaused reinitializer(_incrementGlobalInitializationCounter(1)) nonReentrant {
        // Initialize the base implementation.
        __CustomToken_init1(owner_, name_, symbol_, originalUnderlyingTokenDecimals_, childChainManager_, address(0));

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
}
