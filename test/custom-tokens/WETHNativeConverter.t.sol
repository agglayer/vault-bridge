// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {MockERC20MintableBurnable} from "../GenericNativeConverter.t.sol";
import {WETH} from "src/custom-tokens/WETH/WETH.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {PausableUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";

import {GenericNativeConverterTest} from "../GenericNativeConverter.t.sol";
import {WETHNativeConverter} from "../../src/custom-tokens/WETH/WETHNativeConverter.sol";
import {GenericNativeConverter, NativeConverter} from "../../src/custom-tokens/GenericNativeConverter.sol";

contract WETHNativeConverterTest is Test, GenericNativeConverterTest {
    MockERC20 internal wWETH;
    WETH internal wETH;
    address internal vbETH = makeAddr("vbETH");

    WETHNativeConverter internal wETHConverter;

    function setUp() public override {
        zkevmFork = vm.createSelectFork("polygon_zkevm", 19164969);

        // Setup tokens
        wWETH = new MockERC20();
        wWETH.initialize("Wrapped WETH", "wWETH", 18);
        wETH = new WETH();
        address calculatedNativeConverterAddr = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 2);
        vm.etch(LXLY_BRIDGE, SOVEREIGN_BRIDGE_BYTECODE);
        bytes memory initData = abi.encodeCall(
            WETH.initialize, (address(this), "wETH", "wETH", 18, LXLY_BRIDGE, calculatedNativeConverterAddr)
        );
        wETH = WETH(payable(address(new TransparentUpgradeableProxy(address(wETH), address(this), initData))));

        // assign addresses for generic testing
        customToken = MockERC20MintableBurnable(address(wETH));
        underlyingToken = MockERC20(address(wWETH));
        vbToken = vbETH;

        underlyingTokenMetadata = abi.encode("Wrapped WETH", "wWETH", 18);

        // Deploy and initialize converter
        nativeConverter = GenericNativeConverter(address(new WETHNativeConverter()));

        /// important to assign customToken, underlyingToken, and nativeConverter
        /// before the snapshot, so test_initialize will work
        beforeInit = vm.snapshotState();

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                owner,
                18, // decimals
                address(wETH), // custom token
                address(wWETH), // wrapped underlying token
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                vbETH,
                migrator,
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE
            )
        );
        nativeConverter = GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
        assertEq(address(nativeConverter), calculatedNativeConverterAddr);

        // giving control over custom token to NativeConverter
        wETH.transferOwnership(address(nativeConverter));
        wETHConverter = WETHNativeConverter(payable(address(nativeConverter)));

        vm.label(address(wETH), "wETH");
        vm.label(address(this), "testerAddress");
        vm.label(LXLY_BRIDGE, "lxlyBridge");
        vm.label(vbToken, "vbToken");
        vm.label(owner, "owner");
        vm.label(recipient, "recipient");
        vm.label(sender, "sender");
        vm.label(address(nativeConverter), "WETHNativeConverter");
        vm.label(address(wWETH), "wWETH");
    }

    function test_initialize() public override {
        vm.revertToState(beforeInit);

        bytes memory initData;

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                address(0),
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(customToken),
                address(underlyingToken),
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                vbToken,
                migrator,
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE
            )
        );
        vm.expectRevert(NativeConverter.InvalidOwner.selector);
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
        vm.revertToState(beforeInit);

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(0),
                address(underlyingToken),
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                vbToken,
                migrator,
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE
            )
        );
        vm.expectRevert(NativeConverter.InvalidCustomToken.selector);
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
        vm.revertToState(beforeInit);

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(customToken),
                address(0),
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                vbToken,
                migrator,
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE
            )
        );
        vm.expectRevert(NativeConverter.InvalidUnderlyingToken.selector);
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
        vm.revertToState(beforeInit);

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(customToken),
                address(underlyingToken),
                address(0),
                NETWORK_ID_L1,
                vbToken,
                migrator,
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE
            )
        );
        vm.expectRevert(NativeConverter.InvalidLxLyBridge.selector);
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
        vm.revertToState(beforeInit);

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(customToken),
                address(underlyingToken),
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                address(0),
                migrator,
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE
            )
        );
        vm.expectRevert(NativeConverter.InvalidVbToken.selector);
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
        vm.revertToState(beforeInit);

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(customToken),
                address(underlyingToken),
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                vbToken,
                address(0),
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE
            )
        );
        vm.expectRevert(NativeConverter.InvalidMigrator.selector);
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
        vm.revertToState(beforeInit);

        MockERC20 dummyToken = new MockERC20();
        dummyToken.initialize("Dummy Token", "DT", 6);

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(dummyToken),
                address(underlyingToken),
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                vbToken,
                migrator,
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE
            )
        );
        vm.expectRevert(abi.encodeWithSelector(NativeConverter.NonMatchingCustomTokenDecimals.selector, 6, 18));
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
        vm.revertToState(beforeInit);

        dummyToken = new MockERC20(); // have to deploy again because of revert
        dummyToken.initialize("Dummy Token", "DT", 6);

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(customToken),
                address(dummyToken),
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                vbToken,
                migrator,
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE
            )
        );
        vm.expectRevert(abi.encodeWithSelector(NativeConverter.NonMatchingUnderlyingTokenDecimals.selector, 6, 18));
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));

        vm.revertToState(beforeInit);

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(customToken),
                address(dummyToken),
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                vbToken,
                migrator,
                1e19
            )
        );
        vm.expectRevert(abi.encodeWithSelector(NativeConverter.InvalidMaxNonMigratableBackingPercentage.selector));
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
    }

    function test_migrateGasBackingToLayerX() public {
        uint256 amount = 100;
        uint256 amountToMigrate = 50;

        vm.startPrank(owner);
        wETHConverter.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        wETHConverter.migrateGasBackingToLayerX(amountToMigrate);
        wETHConverter.unpause();
        vm.stopPrank();

        vm.expectRevert(NativeConverter.InvalidAssets.selector);
        vm.prank(owner);
        wETHConverter.migrateGasBackingToLayerX(0); // try with 0 backing

        // create backing on layer Y
        vm.deal(address(wETH), amount);

        vm.expectEmit();
        emit BridgeEvent(
            LEAF_TYPE_ASSET, NETWORK_ID_L1, address(0x00), NETWORK_ID_L1, vbToken, amountToMigrate, "", 55413
        );
        vm.expectEmit();
        emit BridgeEvent(
            LEAF_TYPE_MESSAGE,
            NETWORK_ID_L2,
            address(wETHConverter),
            NETWORK_ID_L1,
            vbToken,
            0,
            abi.encode(
                NativeConverter.CrossNetworkInstruction.CUSTOM,
                abi.encode(
                    WETHNativeConverter.CustomCrossNetworkInstruction.WRAP_COIN_AND_COMPLETE_MIGRATION,
                    abi.encode(amountToMigrate, amountToMigrate)
                )
            ),
            55414
        );
        vm.expectEmit();
        emit NativeConverter.MigrationStarted(owner, amountToMigrate, amountToMigrate);
        vm.prank(owner);
        wETHConverter.migrateGasBackingToLayerX(amountToMigrate);
        assertEq(address(wETH).balance, amount - amountToMigrate);

        vm.prank(owner);
        vm.expectRevert(NativeConverter.InvalidAssets.selector);
        wETHConverter.migrateGasBackingToLayerX(0);

        uint256 currentBacking = address(wETH).balance;

        vm.expectRevert(
            abi.encodeWithSelector(NativeConverter.AssetsTooLarge.selector, currentBacking, currentBacking + 1)
        );
        vm.prank(owner);
        wETHConverter.migrateGasBackingToLayerX(currentBacking + 1);
    }
}
