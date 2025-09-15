// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test Base
import {VbUsdcNativeConverterAgglayerBridgedUsdcStandardTestBase} from
    "test/base/secondary-chain/VbUsdcNativeConverterAgglayerBridgedUsdcStandardTestBase.sol";

// Core contracts
import {NativeConverter} from "src/secondary-chain/NativeConverter.sol";
import {VbUsdcNativeConverterAgglayerBridgedUsdcStandard} from
    "src/secondary-chain/agglayer/vbUSDC/bridged-usdc-standard/VbUsdcNativeConverterAgglayerBridgedUsdcStandard.sol";

// OpenZeppelin
import {PausableUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";

/// @dev VbUsdcNativeConverterAgglayerBridgedUsdcStandard tests
contract VbUsdcNativeConverterAgglayerBridgedUsdcStandardTest is
    VbUsdcNativeConverterAgglayerBridgedUsdcStandardTestBase
{
    function setUp() public {
        deployVbUsdcNativeConverterAgglayerBridgedUsdcStandardInfrastructure();
    }

    function test_initialize() public {
        vm.revertToState(stateBeforeInitialize);

        bytes memory initData;

        // Test invalid owner
        initData = abi.encodeCall(
            VbUsdcNativeConverterAgglayerBridgedUsdcStandard(payable(address(0))).reinitialize1,
            (
                address(0),
                address(customToken),
                address(underlyingToken),
                address(mockAgglayerBridge),
                primaryChainAgglayerId,
                maxNonMigratableBackingPercentage,
                migrationManager
            )
        );
        vm.expectRevert(NativeConverter.InvalidOwner.selector);
        VbUsdcNativeConverterAgglayerBridgedUsdcStandard(payable(_proxify(nativeConverterImpl, proxyAdmin, initData)));

        // Test invalid custom token
        initData = abi.encodeCall(
            VbUsdcNativeConverterAgglayerBridgedUsdcStandard(payable(address(0))).reinitialize1,
            (
                owner,
                address(0),
                address(underlyingToken),
                address(mockAgglayerBridge),
                primaryChainAgglayerId,
                maxNonMigratableBackingPercentage,
                migrationManager
            )
        );
        vm.expectRevert(NativeConverter.InvalidCustomToken.selector);
        VbUsdcNativeConverterAgglayerBridgedUsdcStandard(payable(_proxify(nativeConverterImpl, proxyAdmin, initData)));

        // Test invalid underlying token
        initData = abi.encodeCall(
            VbUsdcNativeConverterAgglayerBridgedUsdcStandard(payable(address(0))).reinitialize1,
            (
                owner,
                address(customToken),
                address(0),
                address(mockAgglayerBridge),
                primaryChainAgglayerId,
                maxNonMigratableBackingPercentage,
                migrationManager
            )
        );
        vm.expectRevert(NativeConverter.InvalidUnderlyingToken.selector);
        VbUsdcNativeConverterAgglayerBridgedUsdcStandard(payable(_proxify(nativeConverterImpl, proxyAdmin, initData)));

        // Test invalid agglayer bridge
        initData = abi.encodeCall(
            VbUsdcNativeConverterAgglayerBridgedUsdcStandard(payable(address(0))).reinitialize1,
            (
                owner,
                address(customToken),
                address(underlyingToken),
                address(0), // invalid agglayer bridge
                primaryChainAgglayerId,
                maxNonMigratableBackingPercentage,
                migrationManager
            )
        );
        vm.expectRevert(NativeConverter.InvalidAgglayerBridge.selector);
        VbUsdcNativeConverterAgglayerBridgedUsdcStandard(payable(_proxify(nativeConverterImpl, proxyAdmin, initData)));

        // Test invalid primary chain agglayer ID (0 is invalid)
        initData = abi.encodeCall(
            VbUsdcNativeConverterAgglayerBridgedUsdcStandard(payable(address(0))).reinitialize1,
            (
                owner,
                address(customToken),
                address(underlyingToken),
                address(mockAgglayerBridge),
                1, // invalid primary chain agglayer ID
                maxNonMigratableBackingPercentage,
                migrationManager
            )
        );
        vm.expectRevert(NativeConverter.InvalidAgglayerBridge.selector);
        VbUsdcNativeConverterAgglayerBridgedUsdcStandard(payable(_proxify(nativeConverterImpl, proxyAdmin, initData)));

        // Test invalid non-migratable backing percentage (must be <= 100%)
        initData = abi.encodeCall(
            VbUsdcNativeConverterAgglayerBridgedUsdcStandard(payable(address(0))).reinitialize1,
            (
                owner,
                address(customToken),
                address(underlyingToken),
                address(mockAgglayerBridge),
                primaryChainAgglayerId,
                1.5e18, // 150% - should fail (above 100%)
                migrationManager
            )
        );
        vm.expectRevert(NativeConverter.InvalidNonMigratableBackingPercentage.selector);
        VbUsdcNativeConverterAgglayerBridgedUsdcStandard(payable(_proxify(nativeConverterImpl, proxyAdmin, initData)));
    }

    function test_burnCustomToken_viaDeconvert() public {
        uint256 amount = 100e6; // 100 USDC (6 decimals)

        // First create backing by converting
        deal(address(underlyingToken), owner, amount);
        vm.startPrank(owner);
        underlyingToken.approve(address(nativeConverter), amount);
        nativeConverter.convert(amount, recipient);
        vm.stopPrank();

        // Verify vbUSDC tokens were minted
        assertEq(vbUsdcToken.balanceOf(recipient), amount);
        uint256 initialSupply = vbUsdcToken.totalSupply();
        assertGt(initialSupply, 0);

        // Then deconvert which will burn the custom tokens via _burnCustomToken
        vm.startPrank(recipient);
        vbUsdcToken.approve(address(nativeConverter), amount);
        nativeConverter.deconvert(amount, sender);
        vm.stopPrank();

        // Verify tokens were burned during deconvert
        assertEq(vbUsdcToken.balanceOf(recipient), 0);
        assertEq(vbUsdcToken.totalSupply(), initialSupply - amount);
        assertEq(underlyingToken.balanceOf(sender), amount);
    }
}
