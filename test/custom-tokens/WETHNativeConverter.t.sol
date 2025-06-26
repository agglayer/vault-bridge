// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {MockERC20MintableBurnable} from "../GenericNativeConverter.t.sol";
import {WETH} from "src/custom-tokens/WETH/WETH.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {PausableUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";

import {GenericNativeConverterTest} from "../GenericNativeConverter.t.sol";
import {WETHNativeConverter} from "../../src/custom-tokens/WETH/WETHNativeConverter.sol";
import {GenericNativeConverter, NativeConverter} from "../../src/custom-tokens/GenericNativeConverter.sol";
import {MigrationManager} from "../../src/MigrationManager.sol";

contract LXLYBridgeMock {
    address public gasTokenAddress;
    uint32 public gasTokenNetwork;

    function setGasTokenAddress(address _gasTokenAddress) external {
        gasTokenAddress = _gasTokenAddress;
    }

    function setGasTokenNetwork(uint32 _gasTokenNetwork) external {
        gasTokenNetwork = _gasTokenNetwork;
    }

    function networkID() external pure returns (uint32) {
        return 1;
    }

    function wrappedAddressIsNotMintable(address wrappedAddress) external pure returns (bool isNotMintable) {
        (wrappedAddress);
        return true;
    }
}

contract WETHNativeConverterTest is Test, GenericNativeConverterTest {
    uint256 constant MAX_NON_MIGRATABLE_GAS_BACKING_PERCENTAGE = 1e17;

    MockERC20MintableBurnable internal wWETH;
    WETH internal wETH;
    LXLYBridgeMock internal lxlyBridgeMock;
    address internal migrationManager_ = makeAddr("migrationManager");

    WETHNativeConverter internal wETHConverter;

    function setUp() public override {
        zkevmFork = vm.createSelectFork("polygon_zkevm", 19164969);

        // Setup tokens
        wWETH = new MockERC20MintableBurnable();
        wWETH.initialize("Wrapped WETH", "wWETH", 18);
        wETH = new WETH();
        address calculatedNativeConverterAddr = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 2);
        vm.etch(LXLY_BRIDGE, SOVEREIGN_BRIDGE_BYTECODE);
        bytes memory initData = abi.encodeCall(
            WETH.reinitialize, (address(this), "wETH", "wETH", 18, LXLY_BRIDGE, calculatedNativeConverterAddr)
        );
        wETH = WETH(payable(address(new TransparentUpgradeableProxy(address(wETH), address(this), initData))));

        // assign variables for generic testing
        customToken = MockERC20MintableBurnable(address(wETH));
        underlyingToken = MockERC20MintableBurnable(address(wWETH));
        migrationManager = migrationManager_;
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
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE,
                migrationManager,
                MAX_NON_MIGRATABLE_GAS_BACKING_PERCENTAGE
            )
        );
        nativeConverter = GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
        assertEq(address(nativeConverter), calculatedNativeConverterAddr);

        _mapCustomToken(originUnderlyingToken, address(wWETH), false);

        wETHConverter = WETHNativeConverter(payable(address(nativeConverter)));

        lxlyBridgeMock = new LXLYBridgeMock();

        vm.label(address(wETH), "wETH");
        vm.label(address(this), "testerAddress");
        vm.label(LXLY_BRIDGE, "lxlyBridge");
        vm.label(migrationManager, "migrationManager");
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
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE,
                migrationManager,
                MAX_NON_MIGRATABLE_GAS_BACKING_PERCENTAGE
            )
        );
        vm.expectRevert(NativeConverter.InvalidOwner.selector);
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(0),
                address(underlyingToken),
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE,
                migrationManager,
                MAX_NON_MIGRATABLE_GAS_BACKING_PERCENTAGE
            )
        );
        vm.expectRevert(NativeConverter.InvalidCustomToken.selector);
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(customToken),
                address(0),
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE,
                migrationManager,
                MAX_NON_MIGRATABLE_GAS_BACKING_PERCENTAGE
            )
        );
        vm.expectRevert(NativeConverter.InvalidUnderlyingToken.selector);
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(customToken),
                address(underlyingToken),
                address(0),
                NETWORK_ID_L1,
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE,
                migrationManager,
                MAX_NON_MIGRATABLE_GAS_BACKING_PERCENTAGE
            )
        );
        vm.expectRevert(NativeConverter.InvalidLxLyBridge.selector);
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));

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
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE,
                migrationManager,
                MAX_NON_MIGRATABLE_GAS_BACKING_PERCENTAGE
            )
        );
        vm.expectRevert(abi.encodeWithSelector(NativeConverter.NonMatchingCustomTokenDecimals.selector, 6, 18));
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));

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
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE,
                migrationManager,
                MAX_NON_MIGRATABLE_GAS_BACKING_PERCENTAGE
            )
        );
        vm.expectRevert(abi.encodeWithSelector(NativeConverter.NonMatchingUnderlyingTokenDecimals.selector, 6, 18));
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(customToken),
                address(dummyToken),
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                1e19,
                migrationManager,
                MAX_NON_MIGRATABLE_GAS_BACKING_PERCENTAGE
            )
        );
        vm.expectRevert(abi.encodeWithSelector(NativeConverter.InvalidNonMigratableBackingPercentage.selector));
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(customToken),
                address(underlyingToken),
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE,
                address(0),
                MAX_NON_MIGRATABLE_GAS_BACKING_PERCENTAGE
            )
        );
        vm.expectRevert(NativeConverter.InvalidMigrationManager.selector);
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(customToken),
                address(underlyingToken),
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE,
                migrationManager,
                1e19
            )
        );
        vm.expectRevert(NativeConverter.InvalidNonMigratableBackingPercentage.selector);
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

        vm.expectRevert(NativeConverter.InvalidAssets.selector);
        wETHConverter.migrateGasBackingToLayerX(0); // try with 0 backing

        // create backing on layer Y
        uint256 backingOnLayerY = 0;
        deal(address(underlyingToken), owner, amount);
        underlyingToken.approve(address(nativeConverter), amount);
        backingOnLayerY = wETHConverter.convert(amount, recipient);

        deal(address(wETH), amount);

        vm.expectEmit();
        emit BridgeEvent(
            LEAF_TYPE_ASSET, NETWORK_ID_L1, address(0x00), NETWORK_ID_L1, migrationManager, amountToMigrate, "", 55413
        );
        vm.expectEmit();
        emit BridgeEvent(
            LEAF_TYPE_MESSAGE,
            NETWORK_ID_L2,
            address(wETHConverter),
            NETWORK_ID_L1,
            migrationManager,
            0,
            abi.encode(
                MigrationManager.CrossNetworkInstruction.WRAP_GAS_TOKEN_AND_COMPLETE_MIGRATION,
                abi.encode(amountToMigrate, amountToMigrate)
            ),
            55414
        );
        vm.expectEmit();
        emit NativeConverter.MigrationStarted(amountToMigrate, amountToMigrate);
        wETHConverter.migrateGasBackingToLayerX(amountToMigrate);
        assertEq(address(wETH).balance, amountToMigrate);

        uint256 currentBacking = address(wETH).balance;
        uint256 nonMigratableGasBacking = Math.mulDiv(amount, MAX_NON_MIGRATABLE_GAS_BACKING_PERCENTAGE, 1e18); // since the non-migratable gas backing is calculated as the percentage of the total supply of the custom token we take the original amount

        vm.expectRevert(
            abi.encodeWithSelector(
                NativeConverter.AssetsTooLarge.selector, currentBacking - nonMigratableGasBacking, currentBacking + 1
            )
        );
        wETHConverter.migrateGasBackingToLayerX(currentBacking + 1);

        vm.stopPrank();
    }

    function test_onlyIfGasTokenIsEth() public {
        uint256 amount = 100;
        deal(address(this), amount);

        lxlyBridgeMock.setGasTokenAddress(address(this));
        lxlyBridgeMock.setGasTokenNetwork(0);
        _deployWETHNativeConverter(address(lxlyBridgeMock));
        vm.expectRevert(WETHNativeConverter.FunctionNotSupportedOnThisNetwork.selector);
        (address(wETHConverter).call{value: amount}(""));

        lxlyBridgeMock.setGasTokenAddress(address(0));
        lxlyBridgeMock.setGasTokenNetwork(1);
        _deployWETHNativeConverter(address(lxlyBridgeMock));
        vm.expectRevert(WETHNativeConverter.FunctionNotSupportedOnThisNetwork.selector);
        (address(wETHConverter).call{value: amount}(""));

        lxlyBridgeMock.setGasTokenAddress(address(0));
        lxlyBridgeMock.setGasTokenNetwork(0);
        _deployWETHNativeConverter(address(lxlyBridgeMock));
        (address(wETHConverter).call{value: amount}(""));
        assertEq(address(wETHConverter).balance, amount);
    }

    function _deployWETHNativeConverter(address _lxlyBridge) internal {
        wETHConverter = new WETHNativeConverter();
        bytes memory initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(customToken),
                address(underlyingToken),
                _lxlyBridge,
                NETWORK_ID_L1,
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE,
                migrationManager,
                MAX_NON_MIGRATABLE_GAS_BACKING_PERCENTAGE
            )
        );
        wETHConverter = WETHNativeConverter(payable(_proxify(address(wETHConverter), address(this), initData)));
    }
}
