// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.0) (secondary-chain/agglayer/GenericCustomTokenAgglayer.sol)

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

    function reinitialize1() external locked nonReentrant {
        _incrementGlobalInitializationCounter(1);
    }

    /// @notice The reinitializers start from `2` because Agglayer Bridge has already initialized the token.
    /// @dev @note (ATTENTION) There is no `reinitializer1`.
    function reinitialize2(
        address owner_,
        uint8 originalUnderlyingTokenDecimals_,
        address agglayerBridge_,
        address nativeConverter_
    ) external locked reinitializer(_incrementGlobalInitializationCounter(2)) nonReentrant {
        // Preserve the `name` and `symbol` of the bridged vbToken.
        string memory name_ = ERC20Upgradeable.name();
        string memory symbol_ = ERC20Upgradeable.symbol();

        // Prevent a mistake while initializing.
        uint8 previousDecimals;
        assembly {
            let word := sload(0x863b064fe9383d75d38f584f64f1aaba4520e9ebc98515fa15bdeae8c4274d00)
            previousDecimals := and(word, 0xff)
        }
        require(originalUnderlyingTokenDecimals_ == previousDecimals, InvalidOriginalUnderlyingTokenDecimals());

        // Initialize the base implementation.
        __CustomToken_init1(owner_, name_, symbol_, originalUnderlyingTokenDecimals_, agglayerBridge_, nativeConverter_);
    }

    // @remind Document (the entire function).
    function reinitialize3() external locked reinitializer(_incrementGlobalInitializationCounter(3)) nonReentrant {
        __CustomToken_init2();
    }

    /*
    /// @dev How to add a new reinitializer:
    function reinitialize4()
        external
        locked
        reinitializer(_incrementGlobalInitializationCounter(4))
        nonReentrant
    {}
    */

    // @remind Document (the entire function).
    function reinitialize(bytes[] calldata reinitializeData) external {
        bytes4[] memory reinitializeSelectors = new bytes4[](3);

        reinitializeSelectors[0] = this.reinitialize1.selector;
        reinitializeSelectors[1] = this.reinitialize2.selector;
        reinitializeSelectors[2] = this.reinitialize3.selector;

        _reinitialize(reinitializeSelectors, reinitializeData);
    }

    /// @inheritdoc CustomToken
    function _CUSTOM_TOKEN_INIT_2_COMPATIBLE() internal pure override {}
}
