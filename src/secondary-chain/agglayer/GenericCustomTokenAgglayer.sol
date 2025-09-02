// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (secondary-chain/agglayer/GenericCustomTokenAgglayer.sol)

pragma solidity 0.8.29;

// Main functionality.
import {CustomTokenAgglayer} from "./CustomTokenAgglayer.sol";
import {ERC20Upgradeable} from "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {CustomToken} from "../CustomToken.sol";

/// @title Generic Custom Token (Agglayer)
/// @author See https://github.com/agglayer/vault-bridge
/// @dev This contract can be used to deploy Custom Tokens that do not require any customization.
contract GenericCustomTokenAgglayer is CustomTokenAgglayer {
    // -----================= ::: SETUP ::: =================-----

    constructor() {
        _disableInitializers();
    }

    /// @notice The reinitializers start from `2` because Agglayer Bridge has already initialized the token.
    /// @dev @note (ATTENTION) There is no `reinitializer1`.
    function reinitialize2(
        address owner_,
        uint8 originalUnderlyingTokenDecimals_,
        address agglayerBridge_,
        address nativeConverter_
    ) external whenNotPaused reinitializer(2) nonReentrant {
        // Preserve the `name` and `symbol` of the bridged vbToken.
        string memory name_ = ERC20Upgradeable.name();
        string memory symbol_ = ERC20Upgradeable.symbol();

        // Prevent a mistake while initializing.
        assert(ERC20Upgradeable.decimals() == originalUnderlyingTokenDecimals_);

        // Initialize the base implementation.
        __CustomToken_init(owner_, name_, symbol_, originalUnderlyingTokenDecimals_, agglayerBridge_, nativeConverter_);
    }

    // @remind Document (the entire function).
    function reinitialize3() external whenNotPaused reinitializer(3) nonReentrant {
        _incrementGlobalInitializationCounter(1);
        _incrementGlobalInitializationCounter(2);
        _incrementGlobalInitializationCounter(3);

        __CustomToken_init2();
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

    /// @inheritdoc CustomToken
    function _CUSTOM_TOKEN_INIT_2_COMPATIBLE() internal pure override {}
}
