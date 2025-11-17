// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test base
import "test/base/primary-chain/MigrationManagerTestBase.sol";

// Core contracts
import {MigrationManager, PausableUpgradeable} from "src/primary-chain/MigrationManager.sol";

// OpenZeppelin
import {IAccessControl} from "@openzeppelin-contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

/// @dev Tests for MigrationManager
contract MigrationManagerTest is MigrationManagerTestBase {
    function setUp() public virtual {
        deployMigrationManagerInfrastructure();
    }

    function test_reinitialize1() public {
        vm.revertToState(stateBeforeInitialize);

        // Test reinitialize1 with invalid owner
        bytes memory migrationManagerInitData =
            abi.encodeCall(MigrationManager.reinitialize1, (address(0), address(agglayerBridge)));
        vm.expectRevert(MigrationManager.InvalidOwner.selector);
        _proxify(migrationManagerImpl, address(this), migrationManagerInitData);

        // Test reinitialize1 with invalid agglayer bridge
        migrationManagerInitData = abi.encodeCall(MigrationManager.reinitialize1, (owner, address(0)));
        vm.expectRevert(MigrationManager.InvalidAgglayerBridge.selector);
        _proxify(migrationManagerImpl, address(this), migrationManagerInitData);

        // Test reinitialize2 with invalid wrapped gas token
        migrationManagerInitData = abi.encodeCall(MigrationManager.reinitialize1, (owner, address(agglayerBridge)));
        MigrationManager testManager =
            MigrationManager(payable(_proxify(migrationManagerImpl, address(this), migrationManagerInitData)));
        vm.expectRevert(MigrationManager.InvalidWrappedGasToken.selector);
        testManager.reinitialize2(address(0));
    }

    function test_configureNativeConverters_reverts() public {
        uint32[] memory secondaryChainAgglayerIds = new uint32[](1);
        secondaryChainAgglayerIds[0] = NETWORK_ID_L2;
        address[] memory nativeConverters = new address[](1);
        nativeConverters[0] = nativeConverter;

        // test pause and unpause
        bytes memory callData = abi.encodeCall(
            migrationManager.configureNativeConverters,
            (secondaryChainAgglayerIds, nativeConverters, payable(address(vbToken)))
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
        migrationManager.configureNativeConverters(
            secondaryChainAgglayerIds, nativeConverters, payable(address(vbToken))
        );

        vm.startPrank(owner);

        // test mismatched inputs: secondaryChainAgglayerIds
        vm.expectRevert(MigrationManager.NonMatchingInputLengths.selector);
        migrationManager.configureNativeConverters(new uint32[](2), nativeConverters, payable(address(vbToken)));

        // test mismatched inputs: nativeConverters
        vm.expectRevert(MigrationManager.NonMatchingInputLengths.selector);
        migrationManager.configureNativeConverters(
            secondaryChainAgglayerIds, new address[](2), payable(address(vbToken))
        );

        // test invalid secondaryChainAgglayerId
        secondaryChainAgglayerIds[0] = NETWORK_ID_L1;
        vm.expectRevert(MigrationManager.InvalidSecondaryChainAgglayerId.selector);
        migrationManager.configureNativeConverters(
            secondaryChainAgglayerIds, nativeConverters, payable(address(vbToken))
        );

        // test invalid native converter
        secondaryChainAgglayerIds[0] = NETWORK_ID_L2;
        nativeConverters[0] = address(0);
        vm.expectRevert(MigrationManager.InvalidNativeConverter.selector);
        migrationManager.configureNativeConverters(
            secondaryChainAgglayerIds, nativeConverters, payable(address(vbToken))
        );

        // test invalid underlying token
        nativeConverters[0] = nativeConverter;
        vbToken.setUnderlyingToken(address(0));
        vm.expectRevert(MigrationManager.InvalidUnderlyingToken.selector);
        migrationManager.configureNativeConverters(
            secondaryChainAgglayerIds, nativeConverters, payable(address(vbToken))
        );

        vbToken.setUnderlyingToken(address(underlyingToken));

        vm.stopPrank();
    }

    function test_configureNativeConverters() public {
        uint32[] memory secondaryChainAgglayerIds = new uint32[](1);
        secondaryChainAgglayerIds[0] = NETWORK_ID_L2;
        address[] memory nativeConverters = new address[](1);
        nativeConverters[0] = nativeConverter;

        // configure native converter
        vm.expectEmit();
        emit MigrationManager.NativeConverterConfigured(NETWORK_ID_L2, nativeConverter, (address(vbToken)));
        vm.startPrank(owner);
        migrationManager.configureNativeConverters(
            secondaryChainAgglayerIds, nativeConverters, payable(address(vbToken))
        );

        MigrationManager.TokenPair memory tokenPair =
            migrationManager.nativeConvertersConfiguration(NETWORK_ID_L2, nativeConverter);

        assertEq(address(tokenPair.vbToken), address(vbToken));
        assertEq(address(tokenPair.underlyingToken), address(underlyingToken));
        assertEq(IERC20(underlyingToken).allowance(address(migrationManager), address(vbToken)), type(uint256).max);

        // change vbToken
        MockERC20 newUnderlyingToken = new MockERC20("New Underlying Token", "NUT", 18);
        MockVbToken newVbToken = new MockVbToken();
        newVbToken.setUnderlyingToken(address(newUnderlyingToken));

        vm.expectEmit();
        emit MigrationManager.NativeConverterConfigured(NETWORK_ID_L2, nativeConverter, payable(address(newVbToken)));
        migrationManager.configureNativeConverters(
            secondaryChainAgglayerIds, nativeConverters, payable(address(newVbToken))
        );

        tokenPair = migrationManager.nativeConvertersConfiguration(NETWORK_ID_L2, nativeConverter);

        assertEq(address(tokenPair.vbToken), address(newVbToken));
        assertEq(address(tokenPair.underlyingToken), address(newUnderlyingToken));
        assertEq(IERC20(underlyingToken).allowance(address(migrationManager), payable(address(vbToken))), 0);
        assertEq(
            newUnderlyingToken.allowance(address(migrationManager), payable(address(newVbToken))), type(uint256).max
        );

        // unset vbToken
        vm.expectEmit();
        emit MigrationManager.NativeConverterConfigured(NETWORK_ID_L2, nativeConverter, address(0));
        migrationManager.configureNativeConverters(secondaryChainAgglayerIds, nativeConverters, payable(address(0)));

        tokenPair = migrationManager.nativeConvertersConfiguration(NETWORK_ID_L2, nativeConverter);
        assertEq(address(tokenPair.vbToken), address(0));
        assertEq(address(tokenPair.underlyingToken), address(0));
        assertEq(newUnderlyingToken.allowance(address(migrationManager), address(newVbToken)), 0);

        vm.stopPrank();
    }

    function test_onMessageReceived_reverts() public {
        uint32[] memory secondaryChainAgglayerIds = new uint32[](1);
        secondaryChainAgglayerIds[0] = NETWORK_ID_L2;
        address[] memory nativeConverters = new address[](1);
        nativeConverters[0] = nativeConverter;

        // test pause and unpause
        bytes memory callData =
            abi.encodeCall(migrationManager.onMessageReceived, (nativeConverter, NETWORK_ID_L2, bytes("")));
        _testPauseUnpause(owner, address(migrationManager), callData);

        // test only callable by the agglayer bridge
        vm.expectRevert(MigrationManager.Unauthorized.selector);
        migrationManager.onMessageReceived(nativeConverter, NETWORK_ID_L2, bytes(""));

        bytes memory data = abi.encode(
            MigrationManager.CrossChainInstruction._1_WRAP_GAS_TOKEN_AND_COMPLETE_MIGRATION, abi.encode(100, 100)
        );

        // test unset vbToken
        vm.expectRevert(MigrationManager.Unauthorized.selector);
        vm.prank(address(agglayerBridge));
        migrationManager.onMessageReceived(nativeConverter, NETWORK_ID_L2, data);

        vm.prank(owner);
        migrationManager.configureNativeConverters(
            secondaryChainAgglayerIds, nativeConverters, payable(address(vbToken))
        );

        // test wrapped native token with insufficient balance (balance does not match after receiving native token)
        MockWETH mockERC20WithDeposit = new MockWETH();
        vbToken.setUnderlyingToken(address(mockERC20WithDeposit));
        vm.prank(owner);
        migrationManager.configureNativeConverters(
            secondaryChainAgglayerIds, nativeConverters, payable(address(vbToken))
        );
        deal(address(agglayerBridge), 100);

        bytes memory onMessageReceivedCallData =
            abi.encodeCall(migrationManager.onMessageReceived, (nativeConverter, NETWORK_ID_L2, data));
        vm.expectRevert(
            abi.encodeWithSelector(MigrationManager.InsufficientUnderlyingTokenBalanceAfterWrapping.selector, 0, 100)
        );
        vm.prank(address(agglayerBridge));
        (bool _ignored,) = address(migrationManager).call{value: 100}(onMessageReceivedCallData);
        _ignored = _ignored; // silence unused variable warning
    }

    function test_onMessageReceived() public {
        uint32[] memory secondaryChainAgglayerIds = new uint32[](1);
        secondaryChainAgglayerIds[0] = NETWORK_ID_L2;
        address[] memory nativeConverters = new address[](1);
        nativeConverters[0] = nativeConverter;

        vm.prank(owner);
        migrationManager.configureNativeConverters(
            secondaryChainAgglayerIds, nativeConverters, payable(address(vbToken))
        );

        MockWETH mockERC20WithDeposit = new MockWETH();
        vbToken.setUnderlyingToken(address(mockERC20WithDeposit));
        vm.prank(owner);
        migrationManager.configureNativeConverters(
            secondaryChainAgglayerIds, nativeConverters, payable(address(vbToken))
        );

        deal(address(agglayerBridge), 100);

        // test regular migration
        bytes memory data =
            abi.encode(MigrationManager.CrossChainInstruction._0_COMPLETE_MIGRATION, abi.encode(100, 100));

        vm.prank(address(agglayerBridge));
        (bool success,) = address(migrationManager).call(
            abi.encodeCall(migrationManager.onMessageReceived, (nativeConverter, NETWORK_ID_L2, data))
        );
        assertTrue(success);

        // test migration with wrapped gas token
        MockVbToken wrappedGasTokenVbToken = new MockVbToken();
        wrappedGasTokenVbToken.setUnderlyingToken(address(wrappedGasToken));

        vm.prank(owner);
        migrationManager.configureNativeConverters(
            secondaryChainAgglayerIds, nativeConverters, payable(address(wrappedGasTokenVbToken))
        );

        data = abi.encode(
            MigrationManager.CrossChainInstruction._1_WRAP_GAS_TOKEN_AND_COMPLETE_MIGRATION, abi.encode(100, 100)
        );

        vm.prank(address(agglayerBridge));
        (success,) = address(migrationManager).call{value: 100}(
            abi.encodeCall(migrationManager.onMessageReceived, (nativeConverter, NETWORK_ID_L2, data))
        );
        assertTrue(success);
    }
}
