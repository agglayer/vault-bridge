// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.0) (primary-chain/ethereum/layerzero/GenericOftAdapter.sol)

pragma solidity 0.8.29;

// @remind Document (the entire file).

// Main functionality.
import {OFTAdapterUpgradeable} from "@layerzerolabs-oft-evm-upgradeable/contracts/oft/OFTAdapterUpgradeable.sol";

/// @title Generic OFT Adapter
/// @author See https://github.com/agglayer/vault-bridge
contract GenericOftAdapter is OFTAdapterUpgradeable {
    // -----================= ::: SETUP ::: =================-----

    constructor(address _token, address _lzEndpoint) OFTAdapterUpgradeable(_token, _lzEndpoint) {
        _disableInitializers();
    }
}
