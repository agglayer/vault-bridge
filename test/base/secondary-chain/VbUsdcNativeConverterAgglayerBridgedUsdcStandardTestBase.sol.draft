// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test infrastructure
import {MockERC20Upgradeable, SecondaryChainBase} from "test/base/secondary-chain/SecondaryChainBase.sol";
import {MockFiatTokenV2_2} from "test/utils/mocks/MockFiatTokenV2_2.sol";

// Core contracts
import {VbUsdcNativeConverterAgglayerBridgedUsdcStandard} from
    "src/secondary-chain/agglayer/vbUSDC/bridged-usdc-standard/VbUsdcNativeConverterAgglayerBridgedUsdcStandard.sol";

// OpenZeppelin
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
/// @title Mock USDC Token with 6 decimals
/// @notice Mock implementation with USDC-like properties (6 decimals)

contract MockUSDCToken is MockERC20Upgradeable {
    /// @notice Get decimals (USDC has 6 decimals)
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

/// @title vbUSDC Native Converter Agglayer Bridged USDC Standard Test Base
/// @notice Base contract for testing VbUsdcNativeConverterAgglayerBridgedUsdcStandard as a standalone contract
abstract contract VbUsdcNativeConverterAgglayerBridgedUsdcStandardTestBase is SecondaryChainBase {
    // ========= MAIN CONTRACTS =========
    VbUsdcNativeConverterAgglayerBridgedUsdcStandard internal nativeConverter;
    address internal nativeConverterImpl;
    MockFiatTokenV2_2 internal vbUsdcToken;

    /// @notice Deploy vbUSDC NativeConverter-specific infrastructure
    /// @dev Sets up tokens, bridge, and related contracts for vbUSDC NativeConverter testing
    function deployVbUsdcNativeConverterAgglayerBridgedUsdcStandardInfrastructure() internal {
        underlyingTokenName = "Bridged USDC";
        underlyingTokenSymbol = "USDC.e";
        underlyingTokenDecimals = 6; // USDC has 6 decimals
        customTokenName = "vbUSDC";
        customTokenSymbol = "vbUSDC";
        customTokenDecimals = 6; // vbUSDC also has 6 decimals
        maxNonMigratableBackingPercentage = 1e18; // 100% - migration not supported yet
        primaryChainAgglayerId = NETWORK_ID_L1;

        deploySecondaryChainInfrastructure();
        deployVbUsdcNativeConverterAgglayerBridgedUsdcStandard();
        verifyVbUsdcNativeConverterAgglayerBridgedUsdcStandardSetup();
        setupLabels();
    }

    /// @notice Deploy vbUSDC Native Converter and related contracts
    /// @dev This includes deploying the Custom Token (MockFiatTokenV2_2) and initializing both contracts
    function deployVbUsdcNativeConverterAgglayerBridgedUsdcStandard() internal {
        // Override the default decimals by creating a custom implementation that returns 6
        MockUSDCToken usdcToken = new MockUSDCToken();
        usdcToken.initialize(underlyingTokenName, underlyingTokenSymbol);
        underlyingToken = MockERC20Upgradeable(address(usdcToken));

        // Deploy vbUSDC token (FiatTokenV2_2 implementation)
        MockFiatTokenV2_2 existingCustomTokenImpl = new MockFiatTokenV2_2();
        TransparentUpgradeableProxy existingCustomTokenProxy = TransparentUpgradeableProxy(
            payable(
                _proxify(
                    address(existingCustomTokenImpl),
                    proxyAdmin,
                    abi.encodeCall(MockFiatTokenV2_2.initialize, (customTokenName, customTokenSymbol))
                )
            )
        );

        // Calculate the native converter address for proper initialization
        calculatedNativeConverter = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);

        // For vbUSDC, we use the MockFiatTokenV2_2 directly as the custom token
        // The bridge will mint this token directly
        vbUsdcToken = MockFiatTokenV2_2(address(existingCustomTokenProxy));
        nativeConverterImpl = address(new VbUsdcNativeConverterAgglayerBridgedUsdcStandard());

        bytes[] memory reinitializeCallData = new bytes[](2);
        reinitializeCallData[0] = abi.encodeCall(
            VbUsdcNativeConverterAgglayerBridgedUsdcStandard(payable(address(0))).reinitialize1,
            (
                owner,
                address(vbUsdcToken),
                address(underlyingToken),
                address(mockAgglayerBridge),
                primaryChainAgglayerId,
                maxNonMigratableBackingPercentage,
                migrationManager
            )
        );
        reinitializeCallData[1] =
            abi.encodeCall(VbUsdcNativeConverterAgglayerBridgedUsdcStandard(payable(address(0))).reinitialize2, ());

        stateBeforeInitialize = vm.snapshotState();

        bytes memory vbUsdcNativeConverterAgglayerBridgedInitData = abi.encodeCall(
            VbUsdcNativeConverterAgglayerBridgedUsdcStandard(payable(address(0))).reinitialize, (reinitializeCallData)
        );
        nativeConverter = VbUsdcNativeConverterAgglayerBridgedUsdcStandard(
            _proxify(nativeConverterImpl, proxyAdmin, vbUsdcNativeConverterAgglayerBridgedInitData)
        );

        vm.prank(address(nativeConverter));
        underlyingToken.approve(address(mockAgglayerBridge), type(uint256).max);
    }

    /// @notice Setup debugging labels
    function setupLabels() internal {
        vm.label(address(vbUsdcToken), "vbUSDC");
        vm.label(address(nativeConverter), "VbUsdcNativeConverterAgglayerBridgedUsdcStandard");
        vm.label(address(underlyingToken), "BridgedUSDC");
    }

    /// @notice Helper to verify basic vbUSDC NativeConverter setup
    function verifyVbUsdcNativeConverterAgglayerBridgedUsdcStandardSetup() internal view {
        assertEq(address(nativeConverter.bridge()), address(mockAgglayerBridge));
        assertEq(address(nativeConverter.customToken()), address(vbUsdcToken));
        assertEq(address(nativeConverter.migrationManager()), migrationManager);
        assertEq(address(nativeConverter.underlyingToken()), address(underlyingToken));
        assertEq(nativeConverter.agglayerId(), NETWORK_ID_L2);
        assertEq(nativeConverter.nonMigratableBackingPercentage(), maxNonMigratableBackingPercentage);
        assertEq(nativeConverter.primaryChainAgglayerId(), primaryChainAgglayerId);
        assertTrue(nativeConverter.hasRole(nativeConverter.DEFAULT_ADMIN_ROLE(), owner));

        // Verify USDC-specific properties
        assertEq(vbUsdcToken.decimals(), 6);
        assertEq(vbUsdcToken.name(), customTokenName);
        assertEq(vbUsdcToken.symbol(), customTokenSymbol);
        assertEq(underlyingToken.decimals(), 6); // Mock USDC with 6 decimals
    }
}
