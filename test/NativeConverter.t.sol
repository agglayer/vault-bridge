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
    uint256 internal constant NON_MIGRATABLE_BACKING_PERCENTAGE = 1e17;
    uint256 internal constant MINIMUM_BACKING_AFTER_MIGRATION = 5;
    bytes internal constant WUSDC_METADATA = abi.encode("Wrapped USDC", "wUSDC", 18);
    uint256 constant MAX_NON_MIGRATABLE_BACKING_PERCENTAGE = 1e18;
    uint256 constant DUMMY_AMOUNT = 100 ether;

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

    event BridgeEvent(
        uint8 leafType,
        uint32 originNetwork,
        address originAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        bytes metadata,
        uint32 depositCount
    );
    event NonMigratableBackingPercentageSet(uint256 nonMigratableBackingPercentage);
    event MigrationStarted(address indexed sender, uint256 indexed customTokenAmount, uint256 backingAmount);

    error InvalidOwner();
    error InvalidCustomToken();
    error InvalidUnderlyingToken();
    error InvalidNonMigratableBackingPercentage();
    error InvalidLxLyBridge();
    error InvalidMigrationManager();
    error NonMatchingCustomTokenDecimals(uint8 customTokenDecimals, uint8 originalUnderlyingTokenDecimals);
    error NonMatchingUnderlyingTokenDecimals(uint8 underlyingTokenDecimals, uint8 originalUnderlyingTokenDecimals);
    error InvalidAssets();
    error InvalidReceiver();
    error InvalidPermitData();
    error InvalidShares();
    error AssetsTooLarge(uint256 availableAssets, uint256 requestedAssets);
    error InvalidDestinationNetworkId();

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
        vm.revertToState(beforeInit);

        bytes memory initData;
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
        vm.expectRevert(InvalidOwner.selector);
        USDCNativeConverter(_proxify(address(uSDCNativeConverter), address(this), initData));
        vm.revertToState(beforeInit);

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
        vm.expectRevert(InvalidCustomToken.selector);
        USDCNativeConverter(_proxify(address(uSDCNativeConverter), address(this), initData));
        vm.revertToState(beforeInit);

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
        vm.expectRevert(InvalidUnderlyingToken.selector);
        USDCNativeConverter(_proxify(address(uSDCNativeConverter), address(this), initData));
        vm.revertToState(beforeInit);

        initData = abi.encodeCall(
            uSDCNativeConverter.initialize,
            (
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(uSDCe),
                address(wUSDC),
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE + 1,
                MINIMUM_BACKING_AFTER_MIGRATION,
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                migrationManager
            )
        );
        vm.expectRevert(InvalidNonMigratableBackingPercentage.selector);
        USDCNativeConverter(_proxify(address(uSDCNativeConverter), address(this), initData));
        vm.revertToState(beforeInit);

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
        vm.expectRevert(InvalidLxLyBridge.selector);
        USDCNativeConverter(_proxify(address(uSDCNativeConverter), address(this), initData));
        vm.revertToState(beforeInit);

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
        vm.expectRevert(InvalidMigrationManager.selector);
        USDCNativeConverter(_proxify(address(uSDCNativeConverter), address(this), initData));
        vm.revertToState(beforeInit);

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
        vm.expectRevert(abi.encodeWithSelector(NonMatchingCustomTokenDecimals.selector, 6, 18));
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
        vm.expectRevert(abi.encodeWithSelector(NonMatchingUnderlyingTokenDecimals.selector, 6, 18));
        USDCNativeConverter(_proxify(address(uSDCNativeConverter), address(this), initData));
    }

    function test_convert() public {
        vm.startPrank(owner);
        uSDCNativeConverter.pause();
        vm.expectRevert(EnforcedPause.selector);
        uSDCNativeConverter.convert(DUMMY_AMOUNT, recipient);
        uSDCNativeConverter.unpause();
        vm.stopPrank();

        vm.startPrank(sender);
        vm.expectRevert(InvalidAssets.selector);
        uSDCNativeConverter.convert(0, recipient);

        vm.expectRevert(InvalidReceiver.selector);
        uSDCNativeConverter.convert(DUMMY_AMOUNT, address(0));

        deal(address(wUSDC), sender, amount);

        vm.expectRevert("ERC20: subtraction underflow");
        uSDCNativeConverter.convert(DUMMY_AMOUNT, recipient);

        deal(address(wUSDC), sender, DUMMY_AMOUNT);

        wUSDC.approve(address(uSDCNativeConverter), DUMMY_AMOUNT);
        uSDCNativeConverter.convert(DUMMY_AMOUNT, recipient);

        assertEq(wUSDC.balanceOf(sender), 0);
        assertEq(wUSDC.balanceOf(address(uSDCNativeConverter)), DUMMY_AMOUNT);
        assertEq(uSDCe.balanceOf(recipient), DUMMY_AMOUNT);
        assertEq(uSDCNativeConverter.backingOnLayerY(), DUMMY_AMOUNT);
        vm.stopPrank();
    }

    function test_convertWithPermit() public {
        vm.startPrank(owner);
        uSDCNativeConverter.pause();
        vm.expectRevert(EnforcedPause.selector);
        uSDCNativeConverter.convertWithPermit(DUMMY_AMOUNT, "", recipient);
        uSDCNativeConverter.unpause();
        vm.stopPrank();

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
                            DUMMY_AMOUNT,
                            vm.getNonce(sender),
                            block.timestamp
                        )
                    )
                )
            )
        );
        bytes memory permitData = abi.encodeWithSelector(
            PERMIT_SIGNATURE, sender, address(uSDCNativeConverter), DUMMY_AMOUNT, block.timestamp, v, r, s
        );

        vm.startPrank(sender);
        vm.expectRevert(InvalidPermitData.selector);
        uSDCNativeConverter.convertWithPermit(0, "", recipient);

        vm.expectRevert(InvalidAssets.selector);
        uSDCNativeConverter.convertWithPermit(0, permitData, recipient);

        vm.expectRevert(InvalidReceiver.selector);
        uSDCNativeConverter.convertWithPermit(DUMMY_AMOUNT, permitData, address(0));

        vm.expectRevert("ERC20: subtraction underflow");
        uSDCNativeConverter.convertWithPermit(DUMMY_AMOUNT, permitData, recipient);

        deal(address(wUSDC), sender, DUMMY_AMOUNT);

        uSDCNativeConverter.convertWithPermit(DUMMY_AMOUNT, permitData, recipient);

        assertEq(wUSDC.balanceOf(sender), 0);
        assertEq(wUSDC.balanceOf(address(uSDCNativeConverter)), DUMMY_AMOUNT);
        assertEq(uSDCe.balanceOf(recipient), DUMMY_AMOUNT);
        assertEq(uSDCNativeConverter.backingOnLayerY(), DUMMY_AMOUNT);
        vm.stopPrank();
    }

    function test_maxDeconvert() public {
        vm.startPrank(owner);
        uSDCNativeConverter.pause();
        vm.assertEq(uSDCNativeConverter.maxDeconvert(sender), 0);
        uSDCNativeConverter.unpause();

        vm.assertEq(uSDCNativeConverter.maxDeconvert(sender), 0); // owner has 0 shares

        deal(address(uSDCe), sender, DUMMY_AMOUNT); // mint shares

        uint256 backingOnLayerY = 0;
        assertEq(uSDCNativeConverter.maxDeconvert(sender), backingOnLayerY);

        // create backing on layer Y
        deal(address(wUSDC), owner, DUMMY_AMOUNT);

        wUSDC.approve(address(uSDCNativeConverter), DUMMY_AMOUNT);
        backingOnLayerY += uSDCNativeConverter.convert(DUMMY_AMOUNT, recipient);
        vm.stopPrank();

        deal(address(uSDCe), sender, DUMMY_AMOUNT); // mint shares
        assertEq(uSDCNativeConverter.maxDeconvert(sender), backingOnLayerY);

        deal(address(uSDCe), sender, DUMMY_AMOUNT); // mint additional shares
        assertLe(uSDCNativeConverter.maxDeconvert(sender), backingOnLayerY); // sender has more shares than the backing on layer Y
    }

    function test_simulateDeconvertWithForce() public {
        vm.startPrank(sender);
        vm.expectRevert(InvalidShares.selector);
        uSDCNativeConverter.exposeSimulateDeconvertWithForce(0);

        deal(address(uSDCe), sender, DUMMY_AMOUNT); // mint shares

        // create backing on layer Y
        uint256 backingOnLayerY = 0;
        deal(address(wUSDC), owner, DUMMY_AMOUNT);
        vm.startPrank(owner);
        wUSDC.approve(address(uSDCNativeConverter), DUMMY_AMOUNT);
        backingOnLayerY += uSDCNativeConverter.convert(DUMMY_AMOUNT, recipient);
        vm.stopPrank();

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(AssetsTooLarge.selector, DUMMY_AMOUNT, DUMMY_AMOUNT + 1));
        uSDCNativeConverter.exposeSimulateDeconvertWithForce(DUMMY_AMOUNT + 1);

        assertEq(uSDCNativeConverter.exposeSimulateDeconvertWithForce(DUMMY_AMOUNT), backingOnLayerY);
    }

    function test_deconvert() public {
        vm.startPrank(owner);
        uSDCNativeConverter.pause();
        vm.expectRevert(EnforcedPause.selector);
        uSDCNativeConverter.deconvert(DUMMY_AMOUNT, recipient);
        uSDCNativeConverter.unpause();
        vm.stopPrank();

        vm.startPrank(sender);
        vm.expectRevert(InvalidShares.selector);
        uSDCNativeConverter.deconvert(0, recipient);

        vm.expectRevert(InvalidReceiver.selector);
        uSDCNativeConverter.deconvert(DUMMY_AMOUNT, address(0));

        vm.expectRevert(abi.encodeWithSelector(AssetsTooLarge.selector, 0, DUMMY_AMOUNT));
        uSDCNativeConverter.deconvert(DUMMY_AMOUNT, recipient); // no backing on layer Y

        // create backing on layer Y
        uint256 backingOnLayerY = 0;
        deal(address(wUSDC), owner, DUMMY_AMOUNT);
        vm.startPrank(owner);
        wUSDC.approve(address(uSDCNativeConverter), DUMMY_AMOUNT);
        backingOnLayerY = uSDCNativeConverter.convert(DUMMY_AMOUNT, recipient);
        vm.stopPrank();

        vm.startPrank(sender);
        vm.expectRevert("ERC20: subtraction underflow");
        uSDCNativeConverter.deconvert(DUMMY_AMOUNT, recipient); // sender has 0 shares

        deal(address(uSDCe), sender, DUMMY_AMOUNT); // mint shares

        uint256 returnedAssets = uSDCNativeConverter.deconvert(DUMMY_AMOUNT, recipient);
        vm.stopPrank();

        assertEq(returnedAssets, backingOnLayerY);
        assertEq(wUSDC.balanceOf(recipient), DUMMY_AMOUNT);
        assertEq(wUSDC.balanceOf(address(uSDCNativeConverter)), 0);
        assertEq(uSDCe.balanceOf(sender), 0);
        assertEq(uSDCNativeConverter.backingOnLayerY(), 0);
    }

    function test_deconvertAndBridge() public {
        vm.startPrank(owner);
        uSDCNativeConverter.pause();
        vm.expectRevert(EnforcedPause.selector);
        uSDCNativeConverter.deconvertAndBridge(DUMMY_AMOUNT, NETWORK_ID_L1, recipient, true);
        uSDCNativeConverter.unpause();
        vm.stopPrank();

        vm.startPrank(sender);
        vm.expectRevert(InvalidDestinationNetworkId.selector);
        uSDCNativeConverter.deconvertAndBridge(DUMMY_AMOUNT, NETWORK_ID_L2, recipient, true);

        // create backing on layer Y
        uint256 backingOnLayerY = 0;
        deal(address(wUSDC), owner, DUMMY_AMOUNT);
        vm.startPrank(owner);
        wUSDC.approve(address(uSDCNativeConverter), DUMMY_AMOUNT);
        backingOnLayerY = uSDCNativeConverter.convert(DUMMY_AMOUNT, recipient);
        vm.stopPrank();

        deal(address(uSDCe), sender, DUMMY_AMOUNT); // mint shares

        vm.startPrank(sender);
        vm.expectEmit();
        emit BridgeEvent(
            LEAF_TYPE_ASSET,
            NETWORK_ID_L2,
            address(wUSDC),
            NETWORK_ID_L1,
            recipient,
            DUMMY_AMOUNT,
            WUSDC_METADATA,
            55413
        );
        uint256 returnedAssets = uSDCNativeConverter.deconvertAndBridge(DUMMY_AMOUNT, NETWORK_ID_L1, recipient, true);

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

        vm.expectRevert(InvalidAssets.selector);
        uSDCNativeConverter.migrateBackingToLayerX(); // try with 0 backing

        // create backing on layer Y

        uint256 backingOnLayerY = 0;
        deal(address(wUSDC), owner, DUMMY_AMOUNT);
        vm.startPrank(owner);
        wUSDC.approve(address(uSDCNativeConverter), DUMMY_AMOUNT);
        backingOnLayerY = uSDCNativeConverter.convert(DUMMY_AMOUNT, recipient);
        vm.stopPrank();

        uint256 amountToMigrate =
            DUMMY_AMOUNT - (backingOnLayerY * NON_MIGRATABLE_BACKING_PERCENTAGE) / MAX_NON_MIGRATABLE_BACKING_PERCENTAGE;

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

        vm.expectRevert(InvalidAssets.selector);
        uSDCNativeConverter.migrateBackingToLayerX(); // backing is less than the non migratable backing percentage

        // Try to migrate as the owner with a specific amount
        vm.expectRevert(); // only owner can call this function
        uSDCNativeConverter.migrateBackingToLayerX(DUMMY_AMOUNT);

        vm.startPrank(owner);
        vm.expectRevert(InvalidAssets.selector);
        uSDCNativeConverter.migrateBackingToLayerX(0);

        uint256 currentBacking = uSDCNativeConverter.backingOnLayerY();

        vm.expectRevert(abi.encodeWithSelector(AssetsTooLarge.selector, currentBacking, currentBacking + 1));
        uSDCNativeConverter.migrateBackingToLayerX(currentBacking + 1);
    }

    function test_setNonMigratableBackingPercentage() public {
        uint256 newPercentage = 2e17;

        vm.expectRevert(); // only owner can call this function
        uSDCNativeConverter.setNonMigratableBackingPercentage(0);

        vm.startPrank(owner);
        uSDCNativeConverter.pause();
        vm.expectRevert(EnforcedPause.selector);
        uSDCNativeConverter.setNonMigratableBackingPercentage(0);
        uSDCNativeConverter.unpause();

        vm.expectRevert(InvalidNonMigratableBackingPercentage.selector);
        uSDCNativeConverter.setNonMigratableBackingPercentage(MAX_NON_MIGRATABLE_BACKING_PERCENTAGE + 1);

        vm.expectEmit();
        emit NonMigratableBackingPercentageSet(newPercentage);
        uSDCNativeConverter.setNonMigratableBackingPercentage(newPercentage);
        vm.stopPrank();

        assertEq(uSDCNativeConverter.nonMigratableBackingPercentage(), newPercentage);
    }

    function test_version() public view {
        assertEq(uSDCNativeConverter.version(), NATIVE_CONVERTER_VERSION);
    }

    function _proxify(address logic, address admin, bytes memory initData) internal returns (address proxy) {
        proxy = address(new TransparentUpgradeableProxy(logic, admin, initData));
    }
}
