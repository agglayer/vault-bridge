// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.0) (secondary-chain/wormhole/GenericCustomTokenWormhole.sol)

pragma solidity 0.8.29;

// Main functionality.
import {CustomTokenWormhole} from "./CustomTokenWormhole.sol";
import {CustomToken} from "../CustomToken.sol";

/// @title Generic Custom Token (Wormhole)
/// @author See https://github.com/agglayer/vault-bridge
/// @dev This contract can be used to deploy Custom Tokens that do not require any customization.
contract GenericCustomTokenWormhole is CustomTokenWormhole {
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
        address nttManager_
    ) external locked reinitializer(_incrementGlobalInitializationCounter(1)) nonReentrant {
        // Initialize the base implementation.
        __CustomToken_init1(owner_, name_, symbol_, originalUnderlyingTokenDecimals_, nttManager_, address(0));

        __CustomToken_init2();
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
}
