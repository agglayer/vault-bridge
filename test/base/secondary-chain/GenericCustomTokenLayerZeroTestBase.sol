// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test infrastructure
import {SecondaryChainBase} from "test/base/secondary-chain/SecondaryChainBase.sol";

// Core contracts
import {GenericCustomTokenLayerZero} from "src/secondary-chain/layerzero/GenericCustomTokenLayerZero.sol";

// OpenZeppelin
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Generic Custom Token LayerZero Test Base
/// @notice Base contract for testing GenericCustomTokenLayerZero as a standalone contract
abstract contract GenericCustomTokenLayerZeroTestBase is SecondaryChainBase {
    // ========= MAIN CONTRACTS =========
    GenericCustomTokenLayerZero internal genericCustomTokenLayerZero;
    address internal genericCustomTokenLayerZeroImpl;
    TransparentUpgradeableProxy existingGenericCustomTokenLayerZeroProxy;

    // ========= VARIABLES =========
    address internal oftAdapter = makeAddr("OftAdapter");
    uint8 internal originalUnderlyingTokenDecimals = 18;

    /// @notice Deploy GenericCustomTokenLayerZero-specific infrastructure
    /// @dev Sets up tokens, bridge, and related contracts for GenericCustomTokenLayerZero testing
    function deployGenericCustomTokenLayerZeroInfrastructure() internal {
        customTokenName = "Generic Custom Token LayerZero";
        customTokenSymbol = "gcTKN";
        customTokenDecimals = 18;

        deploySecondaryChainInfrastructure();
        deployGenericCustomTokenLayerZero();
        verifyGenericCustomTokenLayerZeroSetup();
        setupLabels();
    }

    /// @notice Deploy Generic Custom Token LayerZero and related contracts
    function deployGenericCustomTokenLayerZero() internal {
        genericCustomTokenLayerZeroImpl = address(new GenericCustomTokenLayerZero());

        bytes[] memory reinitializeCallData = new bytes[](1);
        reinitializeCallData[0] = abi.encodeCall(
            GenericCustomTokenLayerZero.reinitialize1,
            (owner, customTokenName, customTokenSymbol, originalUnderlyingTokenDecimals, oftAdapter)
        );

        stateBeforeInitialize = vm.snapshotState();

        bytes memory genericCustomTokenLayerZeroInitData =
            abi.encodeCall(GenericCustomTokenLayerZero.reinitialize, (reinitializeCallData));

        existingGenericCustomTokenLayerZeroProxy = TransparentUpgradeableProxy(
            payable(_proxify(genericCustomTokenLayerZeroImpl, proxyAdmin, genericCustomTokenLayerZeroInitData))
        );

        genericCustomTokenLayerZero = GenericCustomTokenLayerZero(address(existingGenericCustomTokenLayerZeroProxy));
    }

    /// @notice Setup debugging labels
    function setupLabels() internal {
        vm.label(address(genericCustomTokenLayerZero), "GenericCustomTokenLayerZero");
        vm.label(address(genericCustomTokenLayerZeroImpl), "GenericCustomTokenLayerZeroImplementation");
        vm.label(oftAdapter, "MockOftAdapter");
    }

    /// @notice Helper to verify basic GenericCustomTokenLayerZero setup
    function verifyGenericCustomTokenLayerZeroSetup() internal view {
        assertEq(genericCustomTokenLayerZero.name(), customTokenName);
        assertEq(genericCustomTokenLayerZero.symbol(), customTokenSymbol);
        assertEq(genericCustomTokenLayerZero.decimals(), customTokenDecimals);
        assertEq(genericCustomTokenLayerZero.bridge(), oftAdapter);
        assertTrue(genericCustomTokenLayerZero.hasRole(genericCustomTokenLayerZero.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(genericCustomTokenLayerZero.hasRole(genericCustomTokenLayerZero.PAUSER_ROLE(), owner));
        assertEq(genericCustomTokenLayerZero.totalSupply(), 0);
        assertFalse(genericCustomTokenLayerZero.paused());
    }
}
