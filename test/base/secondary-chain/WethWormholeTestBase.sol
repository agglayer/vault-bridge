// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test infrastructure
import {SecondaryChainBase} from "test/base/secondary-chain/SecondaryChainBase.sol";

// Core contracts
import {WethWormhole} from "src/secondary-chain/wormhole/vbETH/WethWormhole.sol";

// OpenZeppelin
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title WETH Wormhole Test Base
/// @notice Base contract for testing WethWormhole as a standalone contract
/// @dev This test base combines CustomTokenWormhole and CustomTokenWethExtension functionality
abstract contract WethWormholeTestBase is SecondaryChainBase {
    // ========= MAIN CONTRACTS =========
    WethWormhole internal wethWormhole;
    address internal wethWormholeImpl;
    TransparentUpgradeableProxy existingWethWormholeProxy;

    // ========= VARIABLES =========
    address internal nttManager = makeAddr("NttManager");
    uint8 internal originalUnderlyingTokenDecimals = 18;
    bool internal gasTokenIsEth = true;

    /// @notice Deploy WethWormhole-specific infrastructure
    /// @dev Sets up tokens, bridge, and related contracts for WethWormhole testing
    function deployWethWormholeInfrastructure() internal {
        customTokenName = "WETH Wormhole";
        customTokenSymbol = "wWETH";
        customTokenDecimals = 18;

        deploySecondaryChainInfrastructure();
        deployWethWormhole();
        verifyWethWormholeSetup();
        setupLabels();
    }

    /// @notice Deploy WethWormhole and related contracts
    /// @dev This includes deploying the WethWormhole implementation and initializing the proxy
    function deployWethWormhole() internal {
        wethWormholeImpl = address(new WethWormhole());

        bytes[] memory reinitializeCallData = new bytes[](1);
        reinitializeCallData[0] = abi.encodeCall(
            WethWormhole.reinitialize1,
            (owner, customTokenName, customTokenSymbol, originalUnderlyingTokenDecimals, nttManager, gasTokenIsEth)
        );

        bytes memory wethWormholeInitData = abi.encodeCall(WethWormhole.reinitialize, (reinitializeCallData));

        existingWethWormholeProxy =
            TransparentUpgradeableProxy(payable(_proxify(wethWormholeImpl, proxyAdmin, wethWormholeInitData)));

        wethWormhole = WethWormhole(payable(address(existingWethWormholeProxy)));
    }

    /// @notice Setup debugging labels
    function setupLabels() internal {
        vm.label(address(wethWormhole), "WethWormhole");
        vm.label(address(wethWormholeImpl), "WethWormholeImplementation");
        vm.label(nttManager, "MockNttManager");
    }

    /// @notice Helper to verify basic WethWormhole setup
    function verifyWethWormholeSetup() internal view {
        assertEq(wethWormhole.name(), customTokenName);
        assertEq(wethWormhole.symbol(), customTokenSymbol);
        assertEq(wethWormhole.decimals(), customTokenDecimals);
        assertEq(wethWormhole.bridge(), nttManager);
        assertTrue(wethWormhole.hasRole(wethWormhole.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(wethWormhole.hasRole(wethWormhole.PAUSER_ROLE(), owner));
        assertEq(wethWormhole.totalSupply(), 0);
        assertFalse(wethWormhole.paused());
    }
}
