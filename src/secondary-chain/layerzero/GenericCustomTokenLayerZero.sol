// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.0) (secondary-chain/layerzero/GenericCustomTokenLayerZero.sol)

pragma solidity 0.8.29;

// @remind Document (the entire file).
// @todo overrides, constructor, initialization, disableInitializers

// Main functionality.
import {CustomTokenLayerZero} from "./CustomTokenLayerZero.sol";
import {OFTCoreUpgradeable} from "@layerzerolabs-oft-evm-upgradeable/contracts/oft/OFTCoreUpgradeable.sol";

abstract contract GenericCustomTokenLayerZero is CustomTokenLayerZero {
    /**
     * @dev Constructor for the OFT contract.
     * @param _lzEndpoint The LayerZero endpoint address.
     */
    constructor(address _lzEndpoint, uint8 _decimals) OFTCoreUpgradeable(_decimals, _lzEndpoint) {
        _disableInitializers();
    }

    /**
     * @dev Initializes the OFT with the provided delegate.
     * @param _delegate The delegate capable of making OApp configurations inside of the endpoint.
     *
     * @dev The delegate typically should be set as the owner of the contract.
     * @dev Ownable is not initialized here on purpose. It should be initialized in the child contract to
     * accommodate the different version of Ownable.
     */
    function reinitialize1(address _delegate) internal reinitializer(_incrementGlobalInitializationCounter(1)) {
        __OFTCore_init(_delegate);
        __Ownable_init();
    }

    // -----================= ::: DEV ::: =================-----

    function _CUSTOM_TOKEN_LAYERZERO_OFT_CORE_UPGRADEABLE_INITIALIZED() internal override {}
}
