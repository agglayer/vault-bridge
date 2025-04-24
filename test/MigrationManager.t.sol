// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.29;

import "forge-std/Test.sol";

import {MigrationManager, PausableUpgradeable} from "../src/MigrationManager.sol";

import {ERC20} from "@openzeppelin-contracts/token/ERC20/ERC20.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {IAccessControl} from "@openzeppelin-contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

contract MockLxlyBridge {
    function networkID() external pure returns (uint32) {
        return 0;
    }
}

contract MockVbToken {
    IERC20 public underlyingToken;

    function setUnderlyingToken(address _underlyingToken) external {
        underlyingToken = IERC20(_underlyingToken);
    }

    function completeMigration(uint32 originNetwork, uint256 shares, uint256 assets) external {}
}

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
}

contract MockERC20WithDeposit is ERC20 {
    bool public canDeposit;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function setCanDeposit(bool _canDeposit) external {
        canDeposit = _canDeposit;
    }

    function deposit() external payable {
        if (canDeposit) {
            _mint(msg.sender, msg.value);
        }
    }
}

contract MigrationManagerTest is Test {
    MigrationManager internal migrationManager;
    address internal migrationManagerImpl;
    MockERC20 internal underlyingToken;
    MockLxlyBridge lxlyBridge;
    MockVbToken vbToken;

    uint32 constant NETWORK_ID_X = 0; // mainnet/sepolia
    uint32 constant NETWORK_ID_Y = 29; // katana-apex

    address internal owner = makeAddr("owner");
    address internal nativeConverter = makeAddr("nativeConverter");

    uint256 stateBeforeInitialize;

    function setUp() public {
        // deploy migration manager
        migrationManagerImpl = address(new MigrationManager());

        // deploy mock lxly bridge
        lxlyBridge = new MockLxlyBridge();

        // deploy mock underlying token
        underlyingToken = new MockERC20("Underlying Token", "UT");

        // deploy mock vbToken
        vbToken = new MockVbToken();
        vbToken.setUnderlyingToken(address(underlyingToken));

        stateBeforeInitialize = vm.snapshotState();

        // initialize migration manager
        _initialize(migrationManagerImpl, owner, address(lxlyBridge));

        vm.label(address(lxlyBridge), "LxlyBridgeX");
        vm.label(address(migrationManager), "Migration Manager");
        vm.label(address(owner), "Owner");
        vm.label(address(underlyingToken), "Underlying Token");
        vm.label(address(vbToken), "VbToken");
        vm.label(migrationManagerImpl, "Migration Manager Impl");
        vm.label(nativeConverter, "Native Converter");
    }

    function test_setup() public view {
        assertEq(address(migrationManager.lxlyBridge()), address(lxlyBridge));
    }

    function test_initialize() public {
        vm.revertToState(stateBeforeInitialize);

        bytes memory initData;
        initData = abi.encodeCall(MigrationManager.initialize, (address(0), address(lxlyBridge)));
        vm.expectRevert(MigrationManager.InvalidOwner.selector);
        _initialize(migrationManagerImpl, address(0), address(lxlyBridge));

        initData = abi.encodeCall(MigrationManager.initialize, (owner, address(0)));
        vm.expectRevert(MigrationManager.InvalidLxLyBridge.selector);
        _initialize(migrationManagerImpl, owner, address(0));
    }

    function test_configureNativeConverters_reverts() public {
        uint32[] memory layerYLxlyIds = new uint32[](1);
        layerYLxlyIds[0] = NETWORK_ID_Y;
        address[] memory nativeConverters = new address[](1);
        nativeConverters[0] = nativeConverter;

        // test pause and unpause
        bytes memory callData = abi.encodeCall(
            migrationManager.configureNativeConverters, (layerYLxlyIds, nativeConverters, address(vbToken))
        );
        _testPauseUnpause(owner, address(migrationManager), callData);

        // test only callable by the default admin
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                migrationManager.DEFAULT_ADMIN_ROLE()
            )
        );
        migrationManager.configureNativeConverters(layerYLxlyIds, nativeConverters, address(vbToken));

        vm.startPrank(owner);

        // test mismatched inputs: layerYLxlyIds
        vm.expectRevert(MigrationManager.MismatchedInputsLengths.selector);
        migrationManager.configureNativeConverters(new uint32[](2), nativeConverters, address(vbToken));

        // test mismatched inputs: nativeConverters
        vm.expectRevert(MigrationManager.MismatchedInputsLengths.selector);
        migrationManager.configureNativeConverters(layerYLxlyIds, new address[](2), address(vbToken));

        // test invalid layerYLxlyId
        layerYLxlyIds[0] = NETWORK_ID_X;
        vm.expectRevert(MigrationManager.InvalidLayerYLxLyId.selector);
        migrationManager.configureNativeConverters(layerYLxlyIds, nativeConverters, address(vbToken));

        // test invalid native converter
        layerYLxlyIds[0] = NETWORK_ID_Y;
        nativeConverters[0] = address(0);
        vm.expectRevert(MigrationManager.InvalidNativeConverter.selector);
        migrationManager.configureNativeConverters(layerYLxlyIds, nativeConverters, address(vbToken));

        // test invalid underlying token
        nativeConverters[0] = nativeConverter;
        vbToken.setUnderlyingToken(address(0));
        vm.expectRevert(MigrationManager.InvalidUnderlyingToken.selector);
        migrationManager.configureNativeConverters(layerYLxlyIds, nativeConverters, address(vbToken));

        vbToken.setUnderlyingToken(address(underlyingToken));

        vm.stopPrank();
    }

    function test_configureNativeConverters() public {
        uint32[] memory layerYLxlyIds = new uint32[](1);
        layerYLxlyIds[0] = NETWORK_ID_Y;
        address[] memory nativeConverters = new address[](1);
        nativeConverters[0] = nativeConverter;

        // configure native converter
        vm.expectEmit();
        emit MigrationManager.NativeConverterConfigured(NETWORK_ID_Y, nativeConverter, address(vbToken));
        vm.startPrank(owner);
        migrationManager.configureNativeConverters(layerYLxlyIds, nativeConverters, address(vbToken));

        MigrationManager.TokenPair memory tokenPair =
            migrationManager.nativeConvertersConfiguration(NETWORK_ID_Y, nativeConverter);

        assertEq(address(tokenPair.vbToken), address(vbToken));
        assertEq(address(tokenPair.underlyingToken), address(underlyingToken));
        assertEq(underlyingToken.allowance(address(migrationManager), address(vbToken)), type(uint256).max);

        // change vbToken
        MockERC20 newUnderlyingToken = new MockERC20("New Underlying Token", "NUT");
        MockVbToken newVbToken = new MockVbToken();
        newVbToken.setUnderlyingToken(address(newUnderlyingToken));

        vm.expectEmit();
        emit MigrationManager.NativeConverterConfigured(NETWORK_ID_Y, nativeConverter, address(newVbToken));
        migrationManager.configureNativeConverters(layerYLxlyIds, nativeConverters, address(newVbToken));

        tokenPair = migrationManager.nativeConvertersConfiguration(NETWORK_ID_Y, nativeConverter);

        assertEq(address(tokenPair.vbToken), address(newVbToken));
        assertEq(address(tokenPair.underlyingToken), address(newUnderlyingToken));
        assertEq(underlyingToken.allowance(address(migrationManager), address(vbToken)), 0);
        assertEq(newUnderlyingToken.allowance(address(migrationManager), address(newVbToken)), type(uint256).max);

        // unset vbToken
        vm.expectEmit();
        emit MigrationManager.NativeConverterConfigured(NETWORK_ID_Y, nativeConverter, address(0));
        migrationManager.configureNativeConverters(layerYLxlyIds, nativeConverters, address(0));

        tokenPair = migrationManager.nativeConvertersConfiguration(NETWORK_ID_Y, nativeConverter);
        assertEq(address(tokenPair.vbToken), address(0));
        assertEq(address(tokenPair.underlyingToken), address(0));
        assertEq(newUnderlyingToken.allowance(address(migrationManager), address(newVbToken)), 0);

        vm.stopPrank();
    }

    function test_onMessageReceived_reverts() public {
        uint32[] memory layerYLxlyIds = new uint32[](1);
        layerYLxlyIds[0] = NETWORK_ID_Y;
        address[] memory nativeConverters = new address[](1);
        nativeConverters[0] = nativeConverter;

        // test pause and unpause
        bytes memory callData =
            abi.encodeCall(migrationManager.onMessageReceived, (nativeConverter, NETWORK_ID_Y, bytes("")));
        _testPauseUnpause(owner, address(migrationManager), callData);

        // test only callable by the lxly bridge
        vm.expectRevert(MigrationManager.Unauthorized.selector);
        migrationManager.onMessageReceived(nativeConverter, NETWORK_ID_Y, bytes(""));

        bytes memory data =
            abi.encode(MigrationManager.CrossNetworkInstruction.WRAP_COIN_AND_COMPLETE_MIGRATION, abi.encode(100, 100));

        // test unset vbToken
        vm.expectRevert(MigrationManager.Unauthorized.selector);
        vm.prank(address(lxlyBridge));
        migrationManager.onMessageReceived(nativeConverter, NETWORK_ID_Y, data);

        vm.prank(owner);
        migrationManager.configureNativeConverters(layerYLxlyIds, nativeConverters, address(vbToken));

        // test unwrapped native token
        vm.prank(address(lxlyBridge));
        vm.expectRevert(MigrationManager.CannotWrapCoin.selector);
        migrationManager.onMessageReceived(nativeConverter, NETWORK_ID_Y, data);

        // test wrapped native token with insufficient balance (balance does not match after receiving native token)
        MockERC20WithDeposit mockERC20WithDeposit = new MockERC20WithDeposit("Mock ERC20", "MERC20");
        vbToken.setUnderlyingToken(address(mockERC20WithDeposit));
        vm.prank(owner);
        migrationManager.configureNativeConverters(layerYLxlyIds, nativeConverters, address(vbToken));
        deal(address(lxlyBridge), 100);

        bytes memory onMessageReceivedCallData =
            abi.encodeCall(migrationManager.onMessageReceived, (nativeConverter, NETWORK_ID_Y, data));
        vm.expectRevert(
            abi.encodeWithSelector(MigrationManager.InsufficientUnderlyingTokenBalanceAfterWrapping.selector, 0, 100)
        );
        vm.prank(address(lxlyBridge));
        (bool _ignored,) = address(migrationManager).call{value: 100}(onMessageReceivedCallData);
        _ignored = _ignored; // silence unused variable warning
    }

    function test_onMessageReceived_working() public {
        uint32[] memory layerYLxlyIds = new uint32[](1);
        layerYLxlyIds[0] = NETWORK_ID_Y;
        address[] memory nativeConverters = new address[](1);
        nativeConverters[0] = nativeConverter;

        vm.prank(owner);
        migrationManager.configureNativeConverters(layerYLxlyIds, nativeConverters, address(vbToken));

        MockERC20WithDeposit mockERC20WithDeposit = new MockERC20WithDeposit("Mock ERC20", "MERC20");
        mockERC20WithDeposit.setCanDeposit(true);
        vbToken.setUnderlyingToken(address(mockERC20WithDeposit));
        vm.prank(owner);
        migrationManager.configureNativeConverters(layerYLxlyIds, nativeConverters, address(vbToken));

        deal(address(lxlyBridge), 100);

        bytes memory data =
            abi.encode(MigrationManager.CrossNetworkInstruction.WRAP_COIN_AND_COMPLETE_MIGRATION, abi.encode(100, 100));

        vm.prank(address(lxlyBridge));
        (bool success,) = address(migrationManager).call{value: 100}(
            abi.encodeCall(migrationManager.onMessageReceived, (nativeConverter, NETWORK_ID_Y, data))
        );
        assertTrue(success);

        data = abi.encode(MigrationManager.CrossNetworkInstruction.COMPLETE_MIGRATION, abi.encode(100, 100));

        vm.prank(address(lxlyBridge));
        (success,) = address(migrationManager).call(
            abi.encodeCall(migrationManager.onMessageReceived, (nativeConverter, NETWORK_ID_Y, data))
        );
        assertTrue(success);
    }

    function _initialize(address _migrationManagerImpl, address _owner, address _lxlyBridge) internal {
        bytes memory migrationManagerInitData = abi.encodeCall(MigrationManager.initialize, (_owner, _lxlyBridge));
        migrationManager =
            MigrationManager(_proxify(address(_migrationManagerImpl), address(this), migrationManagerInitData));
    }

    function _testPauseUnpause(address caller, address callee, bytes memory callData) internal {
        vm.startPrank(caller);
        (bool success, /* bytes memory data */ ) = callee.call(abi.encodeCall(migrationManager.pause, ()));

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        (success, /* bytes memory data */ ) = callee.call(callData);

        (success, /* bytes memory data */ ) = callee.call(abi.encodeCall(migrationManager.unpause, ()));
        vm.stopPrank();
    }

    function _proxify(address logic, address admin, bytes memory initData) internal returns (address proxy) {
        proxy = address(new TransparentUpgradeableProxy(logic, admin, initData));
    }
}
