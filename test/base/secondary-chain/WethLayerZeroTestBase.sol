// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test infrastructure
import {SecondaryChainBase} from "test/base/secondary-chain/SecondaryChainBase.sol";

// Core contracts
import {WethLayerZero} from "src/secondary-chain/layerzero/vbETH/WethLayerZero.sol";

// OpenZeppelin
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title WETH LayerZero Test Base
/// @notice Base contract for testing WethLayerZero as a standalone contract
/// @dev This test base combines CustomTokenLayerZero and CustomTokenWethExtension functionality
abstract contract WethLayerZeroTestBase is SecondaryChainBase {
    // ========= MAIN CONTRACTS =========
    WethLayerZero internal wethLayerZero;
    address internal wethLayerZeroImpl;
    TransparentUpgradeableProxy existingWethLayerZeroProxy;

    // ========= VARIABLES =========
    address internal oftAdapter = makeAddr("OftAdapter");
    uint8 internal originalUnderlyingTokenDecimals = 18;
    bool internal gasTokenIsEth = true;

    /// @notice Deploy WethLayerZero-specific infrastructure
    /// @dev Sets up tokens, bridge, and related contracts for WethLayerZero testing
    function deployWethLayerZeroInfrastructure() internal {
        customTokenName = "WETH LayerZero";
        customTokenSymbol = "lzWETH";
        customTokenDecimals = 18;

        deploySecondaryChainInfrastructure();
        deployWethLayerZero();
        verifyWethLayerZeroSetup();
        setupLabels();
    }

    /// @notice Deploy WethLayerZero and related contracts
    /// @dev This includes deploying the WethLayerZero implementation and initializing the proxy
    function deployWethLayerZero() internal {
        wethLayerZeroImpl = address(new WethLayerZero());

        bytes[] memory reinitializeCallData = new bytes[](1);
        reinitializeCallData[0] = abi.encodeCall(
            WethLayerZero.reinitialize1,
            (owner, customTokenName, customTokenSymbol, originalUnderlyingTokenDecimals, oftAdapter, gasTokenIsEth)
        );

        bytes memory wethLayerZeroInitData = abi.encodeCall(WethLayerZero.reinitialize, (reinitializeCallData));

        existingWethLayerZeroProxy =
            TransparentUpgradeableProxy(payable(_proxify(wethLayerZeroImpl, proxyAdmin, wethLayerZeroInitData)));

        wethLayerZero = WethLayerZero(payable(address(existingWethLayerZeroProxy)));
    }

    /// @notice Setup debugging labels
    function setupLabels() internal {
        vm.label(address(wethLayerZero), "WethLayerZero");
        vm.label(address(wethLayerZeroImpl), "WethLayerZeroImplementation");
        vm.label(oftAdapter, "MockOftAdapter");
    }

    /// @notice Helper to verify basic WethLayerZero setup
    function verifyWethLayerZeroSetup() internal view {
        assertEq(wethLayerZero.name(), customTokenName);
        assertEq(wethLayerZero.symbol(), customTokenSymbol);
        assertEq(wethLayerZero.decimals(), customTokenDecimals);
        assertEq(wethLayerZero.bridge(), oftAdapter);
        assertTrue(wethLayerZero.hasRole(wethLayerZero.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(wethLayerZero.hasRole(wethLayerZero.PAUSER_ROLE(), owner));
        assertEq(wethLayerZero.totalSupply(), 0);
        assertFalse(wethLayerZero.paused());
    }
}
