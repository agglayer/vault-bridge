// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.2.0) (secondary-chain/chainlink/GenericCustomTokenChainlink.sol)

pragma solidity 0.8.29;

// @remind Document (the entire file).

// Main functionality.
import {CustomTokenChainlink} from "./CustomTokenChainlink.sol";
import {CustomToken} from "../CustomToken.sol";

/// @author See https://github.com/agglayer/vault-bridge
contract GenericCustomTokenChainlink is CustomTokenChainlink {
    // -----================= ::: SETUP ::: =================-----

    constructor() {
        _disableInitializers();
    }

    function reinitialize1(
        address owner_,
        string memory name_,
        string memory symbol_,
        uint8 originalUnderlyingTokenDecimals_,
        address oftAdapter_,
        address ccipAdmin_
    ) external locked reinitializer(_incrementGlobalInitializationCounter(1)) nonReentrant {
        __CustomToken_init1(owner_, name_, symbol_, originalUnderlyingTokenDecimals_, oftAdapter_, address(0));

        __CustomToken_init2();

        if (ccipAdmin_ != address(0)) setCCIPAdmin(ccipAdmin_);
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
