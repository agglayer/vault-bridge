// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test infrastructure
import {SecondaryChainBase} from "test/base/secondary-chain/SecondaryChainBase.sol";

// Core contracts
import {GenericCustomTokenWormhole} from "src/secondary-chain/wormhole/GenericCustomTokenWormhole.sol";

// OpenZeppelin
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Generic Custom Token Wormhole Test Base
/// @notice Base contract for testing GenericCustomTokenWormhole as a standalone contract
abstract contract GenericCustomTokenWormholeTestBase is SecondaryChainBase {
    // ========= MAIN CONTRACTS =========
    GenericCustomTokenWormhole internal genericCustomTokenWormhole;
    address internal genericCustomTokenWormholeImpl;
    TransparentUpgradeableProxy existingGenericCustomTokenWormholeProxy;

    // ========= VARIABLES =========
    address internal nttManager = makeAddr("NttManager");
    uint8 internal originalUnderlyingTokenDecimals = 18;

    /// @notice Deploy GenericCustomTokenWormhole-specific infrastructure
    /// @dev Sets up tokens, bridge, and related contracts for GenericCustomTokenWormhole testing
    function deployGenericCustomTokenWormholeInfrastructure() internal {
        customTokenName = "Generic Custom Token Wormhole";
        customTokenSymbol = "gcTKN";
        customTokenDecimals = 18;

        deploySecondaryChainInfrastructure();
        deployGenericCustomTokenWormhole();
        verifyGenericCustomTokenWormholeSetup();
        setupLabels();
    }

    /// @notice Deploy Generic Custom Token Wormhole and related contracts
    function deployGenericCustomTokenWormhole() internal {
        genericCustomTokenWormholeImpl = address(new GenericCustomTokenWormhole());

        bytes[] memory reinitializeCallData = new bytes[](1);
        reinitializeCallData[0] = abi.encodeCall(
            GenericCustomTokenWormhole.reinitialize1,
            (owner, customTokenName, customTokenSymbol, originalUnderlyingTokenDecimals, nttManager)
        );

        bytes memory genericCustomTokenWormholeInitData =
            abi.encodeCall(GenericCustomTokenWormhole.reinitialize, (reinitializeCallData));

        existingGenericCustomTokenWormholeProxy = TransparentUpgradeableProxy(
            payable(_proxify(genericCustomTokenWormholeImpl, proxyAdmin, genericCustomTokenWormholeInitData))
        );

        genericCustomTokenWormhole = GenericCustomTokenWormhole(address(existingGenericCustomTokenWormholeProxy));
    }

    /// @notice Setup debugging labels
    function setupLabels() internal {
        vm.label(address(genericCustomTokenWormhole), "GenericCustomTokenWormhole");
        vm.label(address(genericCustomTokenWormholeImpl), "GenericCustomTokenWormholeImplementation");
        vm.label(nttManager, "MockNttManager");
    }

    /// @notice Helper to verify basic GenericCustomTokenWormhole setup
    function verifyGenericCustomTokenWormholeSetup() internal view {
        assertEq(genericCustomTokenWormhole.name(), customTokenName);
        assertEq(genericCustomTokenWormhole.symbol(), customTokenSymbol);
        assertEq(genericCustomTokenWormhole.decimals(), customTokenDecimals);
        assertEq(genericCustomTokenWormhole.bridge(), nttManager);
        assertTrue(genericCustomTokenWormhole.hasRole(genericCustomTokenWormhole.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(genericCustomTokenWormhole.hasRole(genericCustomTokenWormhole.PAUSER_ROLE(), owner));
        assertEq(genericCustomTokenWormhole.totalSupply(), 0);
        assertFalse(genericCustomTokenWormhole.paused());
    }
}
