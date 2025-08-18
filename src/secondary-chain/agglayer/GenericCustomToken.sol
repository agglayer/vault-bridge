// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (secondary-chain/agglayer/GenericCustomToken.sol)

pragma solidity 0.8.29;

// Main functionality.
import {CustomToken, CustomTokenBase} from "../CustomToken.sol";
import {ERC20Upgradeable} from "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

/// @title Generic Custom Token (Agglayer)
/// @author See https://github.com/agglayer/vault-bridge
/// @dev This contract can be used to deploy Custom Tokens that do not require any customization.
contract GenericCustomToken is CustomToken {
    // -----================= ::: SETUP ::: =================-----

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        uint8 originalUnderlyingTokenDecimals_,
        address agglayerBridge_,
        address nativeConverter_
    ) external whenNotPaused initializer nonReentrant {
        // Preserve the `name` and `symbol` of the bridged vbToken.
        string memory name_ = ERC20Upgradeable.name();
        string memory symbol_ = ERC20Upgradeable.symbol();

        // Prevent a mistake while initializing.
        assert(ERC20Upgradeable.decimals() == originalUnderlyingTokenDecimals_);

        // Initialize the base implementation.
        __CustomToken_init(owner_, name_, symbol_, originalUnderlyingTokenDecimals_, agglayerBridge_, nativeConverter_);
    }

    function reinitialize2() external whenNotPaused reinitializer(2) nonReentrant {
        __CustomToken_reinit2();
    }

    function reinitialize3() external whenNotPaused reinitializer(3) nonReentrant {
        _incrementGlobalInitializationCounter(1);
        _incrementGlobalInitializationCounter(2);
        _incrementGlobalInitializationCounter(3);

        __CustomToken_reinit3();
    }

    /*
    /// @dev How to add a new reinitializer:
    function reinitialize4()
        external
        whenNotPaused
        reinitializer(_incrementGlobalInitializationCounter(4))
        nonReentrant
    {}
    */

    /// @inheritdoc CustomTokenBase
    function _CUSTOM_TOKEN_REINIT_3_COMPATIBLE() internal pure override {}
}
