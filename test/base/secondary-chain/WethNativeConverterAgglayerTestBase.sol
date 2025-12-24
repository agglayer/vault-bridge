// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test infrastructure
import {
    MockERC20Upgradeable,
    MockTokenWrappedBridgeUpgradeable,
    SecondaryChainBase
} from "test/base/secondary-chain/SecondaryChainBase.sol";

// Core contracts
import {WethNativeConverterAgglayer} from "src/secondary-chain/agglayer/vbETH/WethNativeConverterAgglayer.sol";
import {WethAgglayer} from "src/secondary-chain/agglayer/vbETH/WethAgglayer.sol";

// OpenZeppelin
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title WETH Native Converter Agglayer Test Base
/// @notice Base contract for testing WETH Native Converter Agglayer as a standalone contract
abstract contract WethNativeConverterAgglayerTestBase is SecondaryChainBase {
    // ========= MAIN CONTRACTS =========
    WethNativeConverterAgglayer internal nativeConverter;
    address internal nativeConverterImpl;

    /// @notice Deploy WETH NativeConverter-specific infrastructure
    /// @dev Sets up tokens, bridge, and related contracts for WETH NativeConverter testing
    function deployWethNativeConverterAgglayerInfrastructure() internal {
        underlyingTokenName = "Wrapped WETH";
        underlyingTokenSymbol = "uWETH";
        underlyingTokenDecimals = 18;
        customTokenName = "WETH Custom Token";
        customTokenSymbol = "cWETH";
        customTokenDecimals = 18;
        maxNonMigratableBackingPercentage = MAX_NON_MIGRATABLE_BACKING_PERCENTAGE;
        maxNonMigratableGasBackingPercentage = MAX_NON_MIGRATABLE_GAS_BACKING_PERCENTAGE;
        primaryChainAgglayerId = NETWORK_ID_L1;

        deploySecondaryChainInfrastructure();
        deployWethNativeConverterAgglayer();
        verifyWethNativeConverterAgglayerSetup();
        setupLabels();
    }
    /// @notice Deploy WETH Native Converter Agglayer and related contracts
    /// @dev This includes deploying the Custom Token and initializing both contracts

    function deployWethNativeConverterAgglayer() internal {
        // Set underlying and custom token addresses
        underlyingToken = new MockERC20Upgradeable();
        underlyingToken.initialize(underlyingTokenName, underlyingTokenSymbol);
        underlyingTokenMetadata = abi.encode(underlyingTokenName, underlyingTokenSymbol, underlyingTokenDecimals);

        MockTokenWrappedBridgeUpgradeable existingCustomTokenImpl = new MockTokenWrappedBridgeUpgradeable();
        TransparentUpgradeableProxy existingCustomTokenProxy = TransparentUpgradeableProxy(
            payable(
                _proxify(
                    address(existingCustomTokenImpl),
                    proxyAdmin,
                    abi.encodeCall(
                        MockTokenWrappedBridgeUpgradeable.initialize,
                        (customTokenName, customTokenSymbol, customTokenDecimals, address(mockAgglayerBridge))
                    )
                )
            )
        );

        WethAgglayer genericCustomTokenImpl = new WethAgglayer();

        calculatedNativeConverter = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);

        bytes[] memory reinitializeCallData = new bytes[](3);
        reinitializeCallData[0] = abi.encodeCall(WethAgglayer.reinitialize1, ());
        reinitializeCallData[1] = abi.encodeCall(
            WethAgglayer.reinitialize2,
            (proxyAdmin, customTokenDecimals, address(mockAgglayerBridge), calculatedNativeConverter)
        );
        reinitializeCallData[2] = abi.encodeCall(WethAgglayer.reinitialize3, (true));

        bytes memory customTokenInitData = abi.encodeCall(WethAgglayer.reinitialize, (reinitializeCallData));
        bytes memory customTokenUpgradeData = abi.encodeCall(
            ITransparentUpgradeableProxy.upgradeToAndCall, (address(genericCustomTokenImpl), customTokenInitData)
        );
        vm.prank(_getProxyAdmin(address(existingCustomTokenProxy)));
        (bool success,) = address(existingCustomTokenProxy).call(customTokenUpgradeData);
        require(success, "Failed to upgrade to WethAgglayer");

        // assign variables for generic testing
        customToken = MockTokenWrappedBridgeUpgradeable(address(existingCustomTokenProxy));

        nativeConverterImpl = address(new WethNativeConverterAgglayer());

        reinitializeCallData = new bytes[](2);
        reinitializeCallData[0] = abi.encodeCall(
            WethNativeConverterAgglayer.reinitialize1,
            (
                owner,
                address(customToken),
                address(underlyingToken),
                address(mockAgglayerBridge),
                primaryChainAgglayerId,
                maxNonMigratableBackingPercentage,
                migrationManager,
                maxNonMigratableGasBackingPercentage
            )
        );
        reinitializeCallData[1] = abi.encodeCall(WethNativeConverterAgglayer.reinitialize2, ());

        stateBeforeInitialize = vm.snapshotState();

        bytes memory wethNativeConverterAgglayerInitData =
            abi.encodeCall(WethNativeConverterAgglayer.reinitialize, (reinitializeCallData));
        nativeConverter = WethNativeConverterAgglayer(
            payable(_proxify(nativeConverterImpl, proxyAdmin, wethNativeConverterAgglayerInitData))
        );
        assertEq(address(nativeConverter), calculatedNativeConverter);

        vm.prank(address(nativeConverter));
        underlyingToken.approve(address(mockAgglayerBridge), type(uint256).max);
    }

    /// @notice Setup debugging labels
    function setupLabels() internal {
        vm.label(address(customToken), "WETH");
        vm.label(address(nativeConverter), "WethNativeConverterAgglayer");
        vm.label(address(underlyingToken), "UnderlyingToken");
    }

    /// @notice Helper to verify basic NativeConverter setup
    function verifyWethNativeConverterAgglayerSetup() internal view {
        assertEq(address(nativeConverter.bridge()), address(mockAgglayerBridge));
        assertEq(address(nativeConverter.customToken()), address(customToken));
        assertEq(address(nativeConverter.migrationManager()), migrationManager);
        assertEq(address(nativeConverter.underlyingToken()), address(underlyingToken));
        assertEq(nativeConverter.agglayerId(), NETWORK_ID_L2);
        assertEq(nativeConverter.nonMigratableBackingPercentage(), maxNonMigratableBackingPercentage);
        assertEq(nativeConverter.nonMigratableGasBackingPercentage(), maxNonMigratableGasBackingPercentage);
        assertEq(nativeConverter.primaryChainAgglayerId(), primaryChainAgglayerId);
        assertTrue(nativeConverter.hasRole(nativeConverter.DEFAULT_ADMIN_ROLE(), owner));
        assertEq(nativeConverter.nonMigratableGasBackingPercentage(), MAX_NON_MIGRATABLE_GAS_BACKING_PERCENTAGE);
    }
}
