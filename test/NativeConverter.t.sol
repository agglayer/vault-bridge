// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "src/NativeConverter.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// MOCKS
contract USDCNativeConverter is NativeConverter {
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        uint8 originalUnderlyingTokenDecimals_,
        address customToken_,
        address underlyingToken_,
        uint256 nonMigratableBackingPercentage_,
        uint256 minimumBackingAfterMigration_,
        address lxlyBridge_,
        uint32 layerXNetworkId_,
        address migrationManager_
    ) external initializer {
        // Initialize the base implementation.
        __NativeConverter_init(
            owner_,
            originalUnderlyingTokenDecimals_,
            customToken_,
            underlyingToken_,
            nonMigratableBackingPercentage_,
            minimumBackingAfterMigration_,
            lxlyBridge_,
            layerXNetworkId_,
            migrationManager_
        );
    }
}

contract MockERC20MintableBurnable is MockERC20 {
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}

contract NativeConverterTest is Test {
    uint8 internal constant LEAF_TYPE_ASSET = 0;
    address internal constant LXLY_BRIDGE = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
    string internal constant NATIVE_CONVERTER_VERSION = "1.0.0";
    uint32 internal constant NETWORK_ID_L1 = 0;
    uint32 internal constant NETWORK_ID_L2 = 1;
    uint8 internal constant ORIGINAL_UNDERLYING_TOKEN_DECIMALS = 18;
    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes4 internal constant PERMIT_SIGNATURE = 0xd505accf;
    uint256 internal constant NON_MIGRATABLE_BACKING_PERCENTAGE = 10;
    uint256 internal constant MINIMUM_BACKING_AFTER_MIGRATION = 5;
    bytes internal constant WUSDC_METADATA = abi.encode("Wrapped USDC", "wUSDC", 18);

    MockERC20MintableBurnable internal uSDCe;
    MockERC20 internal wUSDC;
    uint256 internal zkevmFork;
    USDCNativeConverter internal uSDCNativeConverter;
    uint256 internal beforeInit;

    // initialization arguments
    address internal migrationManager = makeAddr("migrationManager");
    address internal owner = makeAddr("owner");
    address internal recipient = makeAddr("recipient");

    uint256 internal senderPrivateKey = 0xBEEF;
    address internal sender = vm.addr(senderPrivateKey);

    error EnforcedPause();

    event NonMigratableBackingPercentageChanged(uint256 nonMigratableBackingPercentage);

    function setUp() public {
        zkevmFork = vm.createSelectFork("polygon_zkevm", 19164969);
        uSDCe = new MockERC20MintableBurnable();
        uSDCe.initialize("USDC Native", "USDCe", 18);
        wUSDC = new MockERC20();
        wUSDC.initialize("Wrapped USDC", "wUSDC", 18);

        uSDCNativeConverter = new USDCNativeConverter();
        beforeInit = vm.snapshotState();
        bytes memory initData = abi.encodeCall(
            USDCNativeConverter.initialize,
            (
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(uSDCe),
                address(wUSDC),
                NON_MIGRATABLE_BACKING_PERCENTAGE,
                MINIMUM_BACKING_AFTER_MIGRATION,
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                migrationManager
            )
        );
        uSDCNativeConverter = USDCNativeConverter(_proxify(address(uSDCNativeConverter), address(this), initData));

        vm.label(address(uSDCe), "USDCe");
        vm.label(address(this), "defaultAddress");
        vm.label(LXLY_BRIDGE, "lxlyBridge");
        vm.label(migrationManager, "migrationManager");
        vm.label(owner, "owner");
        vm.label(recipient, "recipient");
        vm.label(sender, "sender");
        vm.label(address(uSDCNativeConverter), "USDCNativeConverter");
        vm.label(address(wUSDC), "wUSDC");
    }

    function test_setup() public view {
        assertEq(uSDCNativeConverter.layerXLxlyId(), NETWORK_ID_L1);
        assertEq(uSDCNativeConverter.migrationManager(), migrationManager);
        assertEq(uSDCNativeConverter.nonMigratableBackingPercentage(), NON_MIGRATABLE_BACKING_PERCENTAGE);
        assertEq(uSDCNativeConverter.owner(), owner);
        assertEq(address(uSDCNativeConverter.customToken()), address(uSDCe));
        assertEq(address(uSDCNativeConverter.lxlyBridge()), LXLY_BRIDGE);
        assertEq(address(uSDCNativeConverter.underlyingToken()), address(wUSDC));
    }

    function test_initialize() public {
        uint256 totalInitParams = 6;
        vm.revertToState(beforeInit);

        bytes memory initData;
        for (uint256 paramNum = 0; paramNum < totalInitParams; paramNum++) {
            if (paramNum == 0) {
                initData = abi.encodeCall(
                    uSDCNativeConverter.initialize,
                    (
                        address(0),
                        ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                        address(uSDCe),
                        address(wUSDC),
                        NON_MIGRATABLE_BACKING_PERCENTAGE,
                        MINIMUM_BACKING_AFTER_MIGRATION,
                        LXLY_BRIDGE,
                        NETWORK_ID_L1,
                        migrationManager
                    )
                );
                vm.expectRevert("INVALID_OWNER");
                USDCNativeConverter(_proxify(address(uSDCNativeConverter), address(this), initData));
                vm.revertToState(beforeInit);
            } else if (paramNum == 1) {
                initData = abi.encodeCall(
                    uSDCNativeConverter.initialize,
                    (
                        owner,
                        ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                        address(0),
                        address(wUSDC),
                        NON_MIGRATABLE_BACKING_PERCENTAGE,
                        MINIMUM_BACKING_AFTER_MIGRATION,
                        LXLY_BRIDGE,
                        NETWORK_ID_L1,
                        migrationManager
                    )
                );
                vm.expectRevert("INVALID_CUSTOM_TOKEN");
                USDCNativeConverter(_proxify(address(uSDCNativeConverter), address(this), initData));
                vm.revertToState(beforeInit);
            } else if (paramNum == 2) {
                initData = abi.encodeCall(
                    uSDCNativeConverter.initialize,
                    (
                        owner,
                        ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                        address(uSDCe),
                        address(0),
                        NON_MIGRATABLE_BACKING_PERCENTAGE,
                        MINIMUM_BACKING_AFTER_MIGRATION,
                        LXLY_BRIDGE,
                        NETWORK_ID_L1,
                        migrationManager
                    )
                );
                vm.expectRevert("INVALID_UNDERLYING_TOKEN");
                USDCNativeConverter(_proxify(address(uSDCNativeConverter), address(this), initData));
                vm.revertToState(beforeInit);
            } else if (paramNum == 3) {
                initData = abi.encodeCall(
                    uSDCNativeConverter.initialize,
                    (
                        owner,
                        ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                        address(uSDCe),
                        address(wUSDC),
                        101,
                        MINIMUM_BACKING_AFTER_MIGRATION,
                        LXLY_BRIDGE,
                        NETWORK_ID_L1,
                        migrationManager
                    )
                );
                vm.expectRevert("INVALID_MINIMUM_BACKING_PERCENTAGE");
                USDCNativeConverter(_proxify(address(uSDCNativeConverter), address(this), initData));
                vm.revertToState(beforeInit);
            } else if (paramNum == 4) {
                initData = abi.encodeCall(
                    uSDCNativeConverter.initialize,
                    (
                        owner,
                        ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                        address(uSDCe),
                        address(wUSDC),
                        NON_MIGRATABLE_BACKING_PERCENTAGE,
                        MINIMUM_BACKING_AFTER_MIGRATION,
                        address(0),
                        NETWORK_ID_L1,
                        migrationManager
                    )
                );
                vm.expectRevert("INVALID_BRIDGE");
                USDCNativeConverter(_proxify(address(uSDCNativeConverter), address(this), initData));
                vm.revertToState(beforeInit);
            } else if (paramNum == 5) {
                initData = abi.encodeCall(
                    uSDCNativeConverter.initialize,
                    (
                        owner,
                        ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                        address(uSDCe),
                        address(wUSDC),
                        NON_MIGRATABLE_BACKING_PERCENTAGE,
                        MINIMUM_BACKING_AFTER_MIGRATION,
                        LXLY_BRIDGE,
                        NETWORK_ID_L1,
                        address(0)
                    )
                );
                vm.expectRevert("INVALID_MIGRATION_MANAGER");
                USDCNativeConverter(_proxify(address(uSDCNativeConverter), address(this), initData));
                vm.revertToState(beforeInit);
            }
        }

        MockERC20 dummyToken = new MockERC20();
        dummyToken.initialize("Dummy Token", "DT", 6);

        initData = abi.encodeCall(
            uSDCNativeConverter.initialize,
            (
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(dummyToken),
                address(wUSDC),
                NON_MIGRATABLE_BACKING_PERCENTAGE,
                MINIMUM_BACKING_AFTER_MIGRATION,
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                migrationManager
            )
        );
        vm.expectRevert("INVALID_CUSTOM_TOKEN_DECIMALS");
        USDCNativeConverter(_proxify(address(uSDCNativeConverter), address(this), initData));
        vm.revertToState(beforeInit);

        dummyToken = new MockERC20();
        dummyToken.initialize("Dummy Token", "DT", 6);

        initData = abi.encodeCall(
            uSDCNativeConverter.initialize,
            (
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(uSDCe),
                address(dummyToken),
                NON_MIGRATABLE_BACKING_PERCENTAGE,
                MINIMUM_BACKING_AFTER_MIGRATION,
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                migrationManager
            )
        );
        vm.expectRevert("INVALID_UNDERLYING_TOKEN_DECIMALS");
        USDCNativeConverter(_proxify(address(uSDCNativeConverter), address(this), initData));
    }

    function test_convert() public {
        uint256 amount = 100;

        vm.startPrank(owner);
        uSDCNativeConverter.pause();
        vm.expectRevert(EnforcedPause.selector);
        uSDCNativeConverter.convert(amount, recipient);
        uSDCNativeConverter.unpause();
        vm.stopPrank();

        vm.startPrank(sender);
        vm.expectRevert("INVALID_AMOUNT");
        uSDCNativeConverter.convert(0, recipient);

        vm.expectRevert("INVALID_ADDRESS");
        uSDCNativeConverter.convert(amount, address(0));

        deal(address(wUSDC), sender, amount);

        vm.expectRevert("ERC20: subtraction underflow");
        uSDCNativeConverter.convert(amount, recipient);

        wUSDC.approve(address(uSDCNativeConverter), amount);
        uSDCNativeConverter.convert(amount, recipient);

        assertEq(wUSDC.balanceOf(sender), 0);
        assertEq(wUSDC.balanceOf(address(uSDCNativeConverter)), amount);
        assertEq(uSDCe.balanceOf(recipient), amount);
        assertEq(uSDCNativeConverter.backingOnLayerY(), amount);
        vm.stopPrank();
    }

    function test_convertWithPermit() public {
        uint256 amount = 100;

        vm.startPrank(owner);
        uSDCNativeConverter.pause();
        vm.expectRevert(EnforcedPause.selector);
        uSDCNativeConverter.convertWithPermit(amount, recipient, "");
        uSDCNativeConverter.unpause();
        vm.stopPrank();

        vm.startPrank(sender);
        vm.expectRevert("INVALID_AMOUNT");
        uSDCNativeConverter.convertWithPermit(0, recipient, "");

        vm.expectRevert("INVALID_ADDRESS");
        uSDCNativeConverter.convertWithPermit(amount, address(0), "");

        vm.expectRevert("ERC20: subtraction underflow");
        uSDCNativeConverter.convertWithPermit(amount, recipient, "");

        deal(address(wUSDC), sender, amount);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            senderPrivateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    wUSDC.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            sender,
                            address(uSDCNativeConverter),
                            amount,
                            vm.getNonce(sender),
                            block.timestamp
                        )
                    )
                )
            )
        );
        bytes memory permitData = abi.encodeWithSelector(
            PERMIT_SIGNATURE, sender, address(uSDCNativeConverter), amount, block.timestamp, v, r, s
        );
        uSDCNativeConverter.convertWithPermit(amount, recipient, permitData);

        assertEq(wUSDC.balanceOf(sender), 0);
        assertEq(wUSDC.balanceOf(address(uSDCNativeConverter)), amount);
        assertEq(uSDCe.balanceOf(recipient), amount);
        assertEq(uSDCNativeConverter.backingOnLayerY(), amount);
        vm.stopPrank();
    }

    function test_maxDeconvert() public {
        uint256 amount = 100;

        vm.startPrank(owner);
        uSDCNativeConverter.pause();
        vm.assertEq(uSDCNativeConverter.maxDeconvert(sender), 0);
        uSDCNativeConverter.unpause();

        vm.assertEq(uSDCNativeConverter.maxDeconvert(sender), 0); // owner has 0 shares

        deal(address(uSDCe), sender, amount); // mint shares

        uint256 backingOnLayerY = 0;
        assertEq(uSDCNativeConverter.maxDeconvert(sender), backingOnLayerY);

        // create backing on layer Y
        deal(address(wUSDC), owner, amount);

        wUSDC.approve(address(uSDCNativeConverter), amount);
        backingOnLayerY += uSDCNativeConverter.convert(amount, recipient);
        vm.stopPrank();

        deal(address(uSDCe), sender, amount); // mint shares
        assertEq(uSDCNativeConverter.maxDeconvert(sender), backingOnLayerY);

        deal(address(uSDCe), sender, amount); // mint additional shares
        assertLe(uSDCNativeConverter.maxDeconvert(sender), backingOnLayerY); // sender has more shares than the backing on layer Y
    }

    function test_simulateDeconvertWithForce() public {
        uint256 amount = 100;

        vm.startPrank(sender);
        vm.expectRevert("INVALID_AMOUNT");
        uSDCNativeConverter.exposeSimulateDeconvertWithForce(0);

        deal(address(uSDCe), sender, amount); // mint shares

        // create backing on layer Y
        uint256 backingOnLayerY = 0;
        deal(address(wUSDC), owner, amount);
        vm.startPrank(owner);
        wUSDC.approve(address(uSDCNativeConverter), amount);
        backingOnLayerY += uSDCNativeConverter.convert(amount, recipient);
        vm.stopPrank();

        vm.startPrank(sender);
        vm.expectRevert("AMOUNT_TOO_LARGE");
        uSDCNativeConverter.exposeSimulateDeconvertWithForce(amount + 1);

        assertEq(uSDCNativeConverter.exposeSimulateDeconvertWithForce(amount), backingOnLayerY);
    }

    function test_deconvert() public {
        uint256 amount = 100;

        vm.startPrank(owner);
        uSDCNativeConverter.pause();
        vm.expectRevert(EnforcedPause.selector);
        uSDCNativeConverter.deconvert(amount, recipient);
        uSDCNativeConverter.unpause();
        vm.stopPrank();

        vm.startPrank(sender);
        vm.expectRevert("INVALID_AMOUNT");
        uSDCNativeConverter.deconvert(0, recipient);

        vm.expectRevert("INVALID_ADDRESS");
        uSDCNativeConverter.deconvert(amount, address(0));

        vm.expectRevert("AMOUNT_TOO_LARGE");
        uSDCNativeConverter.deconvert(amount, recipient); // no backing on layer Y

        // create backing on layer Y
        uint256 backingOnLayerY = 0;
        deal(address(wUSDC), owner, amount);
        vm.startPrank(owner);
        wUSDC.approve(address(uSDCNativeConverter), amount);
        backingOnLayerY = uSDCNativeConverter.convert(amount, recipient);
        vm.stopPrank();

        vm.startPrank(sender);
        vm.expectRevert("ERC20: subtraction underflow");
        uSDCNativeConverter.deconvert(amount, recipient); // sender has 0 shares

        deal(address(uSDCe), sender, amount); // mint shares

        uint256 returnedAssets = uSDCNativeConverter.deconvert(amount, recipient);
        vm.stopPrank();

        assertEq(returnedAssets, backingOnLayerY);
        assertEq(wUSDC.balanceOf(recipient), amount);
        assertEq(wUSDC.balanceOf(address(uSDCNativeConverter)), 0);
        assertEq(uSDCe.balanceOf(sender), 0);
        assertEq(uSDCNativeConverter.backingOnLayerY(), 0);
    }

    function test_deconvertAndBridge() public {
        uint256 amount = 100;

        vm.startPrank(owner);
        uSDCNativeConverter.pause();
        vm.expectRevert(EnforcedPause.selector);
        uSDCNativeConverter.deconvertAndBridge(amount, NETWORK_ID_L1, recipient, true);
        uSDCNativeConverter.unpause();
        vm.stopPrank();

        vm.startPrank(sender);
        vm.expectRevert("INVALID_NETWORK");
        uSDCNativeConverter.deconvertAndBridge(amount, NETWORK_ID_L2, recipient, true);

        // create backing on layer Y
        uint256 backingOnLayerY = 0;
        deal(address(wUSDC), owner, amount);
        vm.startPrank(owner);
        wUSDC.approve(address(uSDCNativeConverter), amount);
        backingOnLayerY = uSDCNativeConverter.convert(amount, recipient);
        vm.stopPrank();

        deal(address(uSDCe), sender, amount); // mint shares

        vm.startPrank(sender);
        vm.expectEmit();
        emit BridgeEvent(
            LEAF_TYPE_ASSET, NETWORK_ID_L2, address(wUSDC), NETWORK_ID_L1, recipient, amount, WUSDC_METADATA, 55413
        );
        uint256 returnedAssets = uSDCNativeConverter.deconvertAndBridge(amount, NETWORK_ID_L1, recipient, true);

        assertEq(returnedAssets, backingOnLayerY);
        assertEq(wUSDC.balanceOf(address(uSDCNativeConverter)), 0);
        assertEq(uSDCe.balanceOf(sender), 0);
        assertEq(uSDCNativeConverter.backingOnLayerY(), 0);
    }

    function test_migrateBackingToLayerX() public {
        vm.startPrank(owner);
        uSDCNativeConverter.pause();
        vm.expectRevert(EnforcedPause.selector);
        uSDCNativeConverter.migrateBackingToLayerX();
        uSDCNativeConverter.unpause();
        vm.stopPrank();

        vm.expectRevert("INVALID_AMOUNT");
        uSDCNativeConverter.migrateBackingToLayerX(); // try with 0 backing

        // create backing on layer Y
        uint256 amount = 100;
        uint256 backingOnLayerY = 0;
        deal(address(wUSDC), owner, amount);
        vm.startPrank(owner);
        wUSDC.approve(address(uSDCNativeConverter), amount);
        backingOnLayerY = uSDCNativeConverter.convert(amount, recipient);
        vm.stopPrank();

        uint256 amountToMigrate = amount - (backingOnLayerY * NON_MIGRATABLE_BACKING_PERCENTAGE) / 100;

        vm.expectEmit();
        emit BridgeEvent(
            LEAF_TYPE_ASSET,
            NETWORK_ID_L2,
            address(wUSDC),
            NETWORK_ID_L1,
            migrationManager,
            amountToMigrate,
            WUSDC_METADATA,
            55413
        );
        vm.expectEmit();
        emit BridgeEvent(
            LEAF_TYPE_MESSAGE,
            NETWORK_ID_L2,
            address(uSDCNativeConverter),
            NETWORK_ID_L1,
            migrationManager,
            0,
            abi.encode(CrossNetworkInstruction.COMPLETE_MIGRATION, amountToMigrate, amountToMigrate),
            55414
        );
        vm.expectEmit();
        emit MigrationStarted(address(this), amountToMigrate, amountToMigrate);
        uSDCNativeConverter.migrateBackingToLayerX();
        assertEq(wUSDC.balanceOf(address(uSDCNativeConverter)), backingOnLayerY - amountToMigrate);

        // mint extra shares
        uSDCe.mint(sender, 1000);

        vm.expectRevert("INVALID_AMOUNT");
        uSDCNativeConverter.migrateBackingToLayerX(); // backing is less than the non migratable backing percentage

        // Try to migrate as the owner with a specific amount
        vm.expectRevert(); // only owner can call this function
        uSDCNativeConverter.migrateBackingToLayerX(amount);

        vm.startPrank(owner);
        vm.expectRevert("INVALID_AMOUNT");
        uSDCNativeConverter.migrateBackingToLayerX(0);

        uint256 currentBacking = uSDCNativeConverter.backingOnLayerY();

        vm.expectRevert("AMOUNT_TOO_LARGE");
        uSDCNativeConverter.migrateBackingToLayerX(currentBacking + 1);
    }

    function test_setNonMigratableBackingPercentage() public {
        vm.expectRevert(); // only owner can call this function
        uSDCNativeConverter.changeNonMigratableBackingPercentage(0);

        vm.startPrank(owner);
        uSDCNativeConverter.pause();
        vm.expectRevert(EnforcedPause.selector);
        uSDCNativeConverter.changeNonMigratableBackingPercentage(0);
        uSDCNativeConverter.unpause();

        vm.expectRevert("INVALID_BACKING_PERCENTAGE");
        uSDCNativeConverter.changeNonMigratableBackingPercentage(101);

        vm.expectEmit();
        emit NonMigratableBackingPercentageChanged(20);
        uSDCNativeConverter.changeNonMigratableBackingPercentage(20);
        vm.stopPrank();

        assertEq(uSDCNativeConverter.nonMigratableBackingPercentage(), 20);
    }

    function test_version() public view {
        assertEq(uSDCNativeConverter.version(), NATIVE_CONVERTER_VERSION);
    }

    function _proxify(address logic, address admin, bytes memory initData) internal returns (address proxy) {
        proxy = address(new TransparentUpgradeableProxy(logic, admin, initData));
    }
}
