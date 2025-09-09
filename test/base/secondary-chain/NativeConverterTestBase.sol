// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test infrastructure
import {
    MockERC20Upgradeable,
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

        MockERC20Upgradeable existingCustomTokenImpl = new MockERC20Upgradeable();
        TransparentUpgradeableProxy existingCustomTokenProxy = TransparentUpgradeableProxy(
            payable(
                _proxify(
                    address(existingCustomTokenImpl),
                    proxyAdmin,
                    abi.encodeCall(MockERC20Upgradeable.initialize, (customTokenName, customTokenSymbol))
                )
            )
        );

        TestHarnessCustomToken genericCustomTokenImpl = new TestHarnessCustomToken();

        calculatedNativeConverter = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);

        bytes memory customTokenInitData = abi.encodeCall(
            TestHarnessCustomToken.reinitialize1,
            (proxyAdmin, customTokenDecimals, address(mockAgglayerBridge), calculatedNativeConverter)
        );
        bytes memory customTokenUpgradeData = abi.encodeCall(
            ITransparentUpgradeableProxy.upgradeToAndCall, (address(genericCustomTokenImpl), customTokenInitData)
        );
        vm.prank(proxyAdmin);
        (address(existingCustomTokenProxy).call(customTokenUpgradeData));

        // assign variables for generic testing
        customToken = MockERC20Upgradeable(address(existingCustomTokenProxy));

        nativeConverterImpl = address(new TestHarnessNativeConverter());

        stateBeforeInitialize = vm.snapshotState();

        bytes memory initData = abi.encodeCall(
            nativeConverter.reinitialize1,
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
        nativeConverter = TestHarnessNativeConverter(_proxify(nativeConverterImpl, proxyAdmin, initData));
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
        assertEq(address(nativeConverter.agglayerBridge()), address(mockAgglayerBridge));
        assertEq(address(nativeConverter.customToken()), address(customToken));
        assertEq(address(nativeConverter.migrationManager()), migrationManager);
        assertEq(address(nativeConverter.underlyingToken()), address(underlyingToken));
        assertEq(nativeConverter.agglayerId(), NETWORK_ID_L2);
        assertEq(nativeConverter.nonMigratableBackingPercentage(), maxNonMigratableBackingPercentage);
        assertEq(nativeConverter.primaryChainAgglayerId(), primaryChainAgglayerId);
        assertTrue(nativeConverter.hasRole(nativeConverter.DEFAULT_ADMIN_ROLE(), owner));
    }
}
