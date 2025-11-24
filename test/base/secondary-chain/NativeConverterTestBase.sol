// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test infrastructure
import {
    MockERC20Upgradeable,
    MockTokenWrappedBridgeUpgradeable,
    SecondaryChainBase,
    TestHarnessNativeConverter,
    TestHarnessCustomToken
} from "test/base/secondary-chain/SecondaryChainBase.sol";

// Core contracts
import {NativeConverter} from "src/secondary-chain/NativeConverter.sol";

// OpenZeppelin
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Native Converter Test Base
/// @notice Base contract for testing NativeConverter as a standalone contract
abstract contract NativeConverterTestBase is SecondaryChainBase {
    // ========= MAIN CONTRACTS =========
    TestHarnessNativeConverter internal nativeConverter;
    address internal nativeConverterImpl;

    /// @notice Deploy NativeConverter-specific infrastructure
    /// @dev Sets up tokens, bridge, and related contracts for NativeConverter testing
    function deployNativeConverterInfrastructure() internal {
        underlyingTokenName = "Underlying Token";
        underlyingTokenSymbol = "uTKN";
        underlyingTokenDecimals = 18;
        customTokenName = "Custom Token";
        customTokenSymbol = "cTKN";
        customTokenDecimals = 18;
        maxNonMigratableBackingPercentage = MAX_NON_MIGRATABLE_BACKING_PERCENTAGE;
        primaryChainAgglayerId = NETWORK_ID_L1;

        deploySecondaryChainInfrastructure();
        deployNativeConverter();
        verifyNativeConverterSetup();
        setupLabels();
    }

    /// @notice Deploy Native Converter and related contracts
    /// @dev This includes deploying the Custom Token and initializing both contracts
    function deployNativeConverter() internal {
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

        TestHarnessCustomToken genericCustomTokenImpl = new TestHarnessCustomToken();

        calculatedNativeConverter = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);

        bytes[] memory reinitializeCallData = new bytes[](3);
        reinitializeCallData[0] = abi.encodeCall(TestHarnessCustomToken.reinitialize1, ());
        reinitializeCallData[1] = abi.encodeCall(
            TestHarnessCustomToken.reinitialize2,
            (proxyAdmin, customTokenDecimals, address(mockAgglayerBridge), calculatedNativeConverter)
        );
        reinitializeCallData[2] = abi.encodeCall(TestHarnessCustomToken.reinitialize3, ());

        bytes memory customTokenInitData = abi.encodeCall(TestHarnessCustomToken.reinitialize, (reinitializeCallData));
        bytes memory customTokenUpgradeData = abi.encodeCall(
            ITransparentUpgradeableProxy.upgradeToAndCall, (address(genericCustomTokenImpl), customTokenInitData)
        );
        vm.prank(proxyAdmin);
        (address(existingCustomTokenProxy).call(customTokenUpgradeData));

        // assign variables for generic testing
        customToken = MockTokenWrappedBridgeUpgradeable(address(existingCustomTokenProxy));

        nativeConverterImpl = address(new TestHarnessNativeConverter());

        stateBeforeInitialize = vm.snapshotState();

        reinitializeCallData = new bytes[](2);
        reinitializeCallData[0] = abi.encodeCall(
            TestHarnessNativeConverter.reinitialize1,
            (
                owner,
                address(customToken),
                address(underlyingToken),
                address(mockAgglayerBridge),
                primaryChainAgglayerId,
                maxNonMigratableBackingPercentage,
                migrationManager
            )
        );
        reinitializeCallData[1] = abi.encodeCall(TestHarnessNativeConverter.reinitialize2, ());

        bytes memory nativeConverterInitData =
            abi.encodeCall(TestHarnessNativeConverter.reinitialize, (reinitializeCallData));
        nativeConverter = TestHarnessNativeConverter(_proxify(nativeConverterImpl, proxyAdmin, nativeConverterInitData));
        assertEq(address(nativeConverter), calculatedNativeConverter);
        vm.prank(address(nativeConverter));
        underlyingToken.approve(address(mockAgglayerBridge), type(uint256).max);
    }

    /// @notice Setup debugging labels
    function setupLabels() internal {
        vm.label(address(customToken), "CustomToken");
        vm.label(address(nativeConverter), "NativeConverter");
        vm.label(address(underlyingToken), "UnderlyingToken");
    }

    /// @notice Helper to verify basic NativeConverter setup
    function verifyNativeConverterSetup() internal view {
        assertEq(address(nativeConverter.bridge()), address(mockAgglayerBridge));
        assertEq(address(nativeConverter.customToken()), address(customToken));
        assertEq(address(nativeConverter.migrationManager()), migrationManager);
        assertEq(address(nativeConverter.underlyingToken()), address(underlyingToken));
        assertEq(nativeConverter.agglayerId(), NETWORK_ID_L2);
        assertEq(nativeConverter.nonMigratableBackingPercentage(), maxNonMigratableBackingPercentage);
        assertEq(nativeConverter.primaryChainAgglayerId(), primaryChainAgglayerId);
        assertTrue(nativeConverter.hasRole(nativeConverter.DEFAULT_ADMIN_ROLE(), owner));
    }
}
