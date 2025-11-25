// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.0) (primary-chain/ethereum/layerzero/GenericOftAdapter.sol)

pragma solidity 0.8.29;

// @remind Document (the entire file).

// Main functionality.
import {OFTAdapterUpgradeable} from "@layerzerolabs-oft-evm-upgradeable/contracts/oft/OFTAdapterUpgradeable.sol";

// Other functionality.
import {
    ReentrancyGuardTransientUpgradeable
} from "@openzeppelin-contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
import {InitializationCounterUpgradeable} from "../../etc/InitializationCounterUpgradeable.sol";

/// @title Non-Default OFT Adapter
/// @author See https://github.com/agglayer/vault-bridge
contract NonDefaultOftAdapter is
    OFTAdapterUpgradeable,
    ReentrancyGuardTransientUpgradeable,
    InitializationCounterUpgradeable
{
    // Errors.
    error InvalidToken();
    error InvalidLzEndpoint();

    // -----================= ::: SETUP ::: =================-----

    constructor(address _token, address _lzEndpoint) OFTAdapterUpgradeable(_token, _lzEndpoint) {
        _disableInitializers();

        require(_token != address(0), InvalidToken());
        require(_lzEndpoint != address(0), InvalidLzEndpoint());
    }

    function reinitialize1(address _owner, address _delegate)
        external
        locked
        reinitializer(_incrementGlobalInitializationCounter(1))
        nonReentrant
    {
        __Ownable_init(_owner);
        __OFTAdapter_init(_delegate);
        __ReentrancyGuardTransient_init();
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
}
