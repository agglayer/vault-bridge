// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.0) (secondary-chain/agglayer/vbETH/WethAgglayer.sol)

pragma solidity 0.8.29;

// @remind Document (the entire file).

import {CustomTokenAgglayer} from "../CustomTokenAgglayer.sol";
import {CustomTokenWethExtension} from "../../CustomTokenWethExtension.sol";
import {CustomToken} from "../../CustomToken.sol";
import {ERC20Upgradeable} from "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {IAgglayerBridge} from "../../../etc/IAgglayerBridge.sol";

/// @title WETH (Agglayer)
/// @author See https://github.com/agglayer/vault-bridge
/// @dev based on https://github.com/gnosis/canonical-weth/blob/master/contracts/WETH9.sol
contract WethAgglayer is CustomTokenAgglayer, CustomTokenWethExtension {
    constructor() {
        _disableInitializers();
    }

    // @remind Document.
    function reinitialize1() external locked nonReentrant {
        _incrementGlobalInitializationCounter(1);
    }

    /// @notice The reinitializers start from `2` because Agglayer Bridge has already initialized the token.
    /// @dev @note (ATTENTION) There is no `reinitializer1`.
    /// @dev @note (ATTENTION) This reinitializer used to set `_gasTokenIsEth`, but that has been moved to `reinitialize3`.
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

    function reinitialize3(bool wethFunctionalityEnabled_)
        external
        locked
        reinitializer(_incrementGlobalInitializationCounter(3))
        nonReentrant
    {
        // Clean up the old ERC-7201 namespace where `bool _gasTokenIsEth` used to be stored.
        // Calculated as `keccak256(abi.encode(uint256(keccak256("agglayer.vault-bridge.WETH.storage")) - 1)) & ~bytes32(uint256(0xff))`.
        assembly {
            sstore(0xdf8caff5d0161908572492829df972cd19b1aabe3c3078d95299408cd561dc00, 0)
        }

        __CustomToken_init2();

        bool gasTokenIsEth_ = IAgglayerBridge(bridge()).gasTokenAddress() == address(0)
            && IAgglayerBridge(bridge()).gasTokenNetwork() == 0;

        __CustomTokenWethExtension_init2_ext1(gasTokenIsEth_, wethFunctionalityEnabled_);
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

    /// @inheritdoc CustomTokenWethExtension
    function _CUSTOM_TOKEN_WETH_EXTENSION_INIT_2_EXT_1_COMPATIBLE() internal pure override {}
}
