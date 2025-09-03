// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (secondary-chain/agglayer/vbETH/WethAgglayer.sol)

pragma solidity 0.8.29;

// @remind Document the entire file.

import {WethCustomToken} from "../../WethCustomToken.sol";
import {CustomTokenAgglayer} from "../CustomTokenAgglayer.sol";
import {CustomToken} from "../../CustomToken.sol";
import {ERC20Upgradeable} from "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {IAgglayerBridge} from "../../../etc/IAgglayerBridge.sol";

/// @title WETH (Agglayer)
/// @author See https://github.com/agglayer/vault-bridge
/// @dev based on https://github.com/gnosis/canonical-weth/blob/master/contracts/WETH9.sol
contract WethAgglayer is WethCustomToken, CustomTokenAgglayer {
    constructor() {
        _disableInitializers();
    }

    /// @notice The reinitializers start from `2` because Agglayer Bridge has already initialized the token.
    /// @dev @note (ATTENTION) There is no `reinitializer1`.
    /// @dev @note (ATTENTION) This reinitializer used to set `_gasTokenIsEth`, but that has been moved to `reinitialize3`.
    function reinitialize2(
        address owner_,
        uint8 originalUnderlyingTokenDecimals_,
        address agglayerBridge_,
        address nativeConverter_
    ) external whenNotPaused reinitializer(2) nonReentrant {
        // Preserve the `name` and `symbol` of the bridged vbToken.
        string memory name_ = name();
        string memory symbol_ = symbol();

        // Prevent a mistake while initializing.
        assert(ERC20Upgradeable.decimals() == originalUnderlyingTokenDecimals_);

        // Initialize the base implementation.
        __CustomToken_init1(owner_, name_, symbol_, originalUnderlyingTokenDecimals_, agglayerBridge_, nativeConverter_);
    }

    function reinitialize3() external whenNotPaused reinitializer(3) nonReentrant {
        _incrementGlobalInitializationCounter(1);
        _incrementGlobalInitializationCounter(2);
        _incrementGlobalInitializationCounter(3);

        __CustomToken_init2();

        bool gasTokenIsEth_ = IAgglayerBridge(bridge()).gasTokenAddress() == address(0)
            && IAgglayerBridge(bridge()).gasTokenNetwork() == 0;

        __WethCustomToken_init1(gasTokenIsEth_);
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

    /// @inheritdoc WethCustomToken
    function _WETH_CUSTOM_TOKEN_INIT_1_COMPATIBLE() internal pure override {}
}
