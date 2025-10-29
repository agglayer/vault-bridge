// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test Base
import {
    GenericCustomTokenPolygonTestBase,
    TransparentUpgradeableProxy
} from "test/base/secondary-chain/GenericCustomTokenPolygonTestBase.sol";

// Core contracts
import {GenericCustomTokenPolygon} from "src/secondary-chain/polygon/GenericCustomTokenPolygon.sol";
import {CustomToken} from "src/secondary-chain/CustomToken.sol";

import {InitializationCounterUpgradeable} from "src/etc/InitializationCounterUpgradeable.sol";

/// @dev GenericCustomTokenPolygon tests
/// @notice Comprehensive tests for GenericCustomTokenPolygon which also cover CustomTokenPolygon functionality
contract GenericCustomTokenPolygonTest is GenericCustomTokenPolygonTestBase {
    function setUp() public virtual {
        deployGenericCustomTokenPolygonInfrastructure();
    }

    /// @notice Helper function to test initialization reverts with different parameters
    function _testInitializationRevert(
        bytes4 expectedError,
        address owner_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address childChainManager_
    ) internal {
        bytes[] memory reinitializeCallData = new bytes[](1);
        reinitializeCallData[0] = abi.encodeCall(
            GenericCustomTokenPolygon.reinitialize1, (owner_, name_, symbol_, decimals_, childChainManager_)
        );

        bytes memory genericCustomTokenPolygonInitData =
            abi.encodeCall(GenericCustomTokenPolygon.reinitialize, (reinitializeCallData));

        vm.expectRevert(expectedError);
        existingGenericCustomTokenPolygonProxy = TransparentUpgradeableProxy(
            payable(_proxify(genericCustomTokenPolygonImpl, proxyAdmin, genericCustomTokenPolygonInitData))
        );
    }

    function test_initialize_revertsWhenCalledTwice() public {
        // Try to reinitialize again
        vm.expectRevert();
        genericCustomTokenPolygon.reinitialize1(owner, "Another Name", "ANT", 18, childChainManager);
    }

    function test_initialize_revertsWithInvalidOwner() public {
        _testInitializationRevert(
            CustomToken.InvalidOwner.selector,
            address(0), // Invalid owner
            customTokenName,
            customTokenSymbol,
            originalUnderlyingTokenDecimals,
            childChainManager
        );
    }

    function test_initialize_revertsWithInvalidName() public {
        _testInitializationRevert(
            CustomToken.InvalidName.selector,
            owner,
            "", // Invalid name
            customTokenSymbol,
            originalUnderlyingTokenDecimals,
            childChainManager
        );
    }

    function test_initialize_revertsWithInvalidSymbol() public {
        _testInitializationRevert(
            CustomToken.InvalidSymbol.selector,
            owner,
            customTokenName,
            "", // Invalid symbol
            originalUnderlyingTokenDecimals,
            childChainManager
        );
    }

    function test_initialize_revertsWithInvalidDecimals() public {
        _testInitializationRevert(
            CustomToken.InvalidOriginalUnderlyingTokenDecimals.selector,
            owner,
            customTokenName,
            customTokenSymbol,
            0, // Invalid decimals
            childChainManager
        );
    }

    function test_initialize_revertsWithInvalidBridge() public {
        _testInitializationRevert(
            CustomToken.InvalidBridge.selector,
            owner,
            customTokenName,
            customTokenSymbol,
            originalUnderlyingTokenDecimals,
            address(0) // Invalid bridge
        );
    }

    function test_deposit_success() public {
        uint256 amount = 1000e18;

        simulateDeposit(sender, amount);

        assertEq(genericCustomTokenPolygon.balanceOf(sender), amount);
        assertEq(genericCustomTokenPolygon.totalSupply(), amount);
    }

    function test_deposit_success_multipleUsers() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        uint256 amount1 = 1000e18;
        uint256 amount2 = 2000e18;

        simulateDeposit(user1, amount1);
        simulateDeposit(user2, amount2);

        assertEq(genericCustomTokenPolygon.balanceOf(user1), amount1);
        assertEq(genericCustomTokenPolygon.balanceOf(user2), amount2);
        assertEq(genericCustomTokenPolygon.totalSupply(), amount1 + amount2);
    }

    function test_deposit_success_toAddressZero_revertsWithInvalidReceiver() public {
        uint256 amount = 1000e18;

        bytes memory depositData = abi.encode(amount);

        // Deposit to address(0) should revert with ERC20InvalidReceiver
        vm.expectRevert();
        vm.prank(childChainManager);
        genericCustomTokenPolygon.deposit(address(0), depositData);

        assertEq(genericCustomTokenPolygon.totalSupply(), 0);
    }

    function test_deposit_revertsWithUnauthorized() public {
        uint256 amount = 1000e18;
        bytes memory depositData = abi.encode(amount);

        vm.expectRevert(CustomToken.Unauthorized.selector);
        vm.prank(makeAddr("unauthorized"));
        genericCustomTokenPolygon.deposit(sender, depositData);
    }

    function test_deposit_revertsWhenPaused() public {
        uint256 amount = 1000e18;
        bytes memory depositData = abi.encode(amount);

        vm.prank(owner);
        genericCustomTokenPolygon.pause();

        vm.expectRevert();
        vm.prank(childChainManager);
        genericCustomTokenPolygon.deposit(sender, depositData);
    }

    function test_deposit_revertsWithIncorrectDepositData() public {
        bytes memory invalidDepositData = hex"1234";

        vm.expectRevert();
        vm.prank(childChainManager);
        genericCustomTokenPolygon.deposit(sender, invalidDepositData);
    }

    function test_withdraw_success() public {
        uint256 amount = 1000e18;

        // First deposit tokens
        simulateDeposit(sender, amount);
        assertEq(genericCustomTokenPolygon.balanceOf(sender), amount);

        // Then withdraw them
        simulateWithdraw(sender, amount);

        assertEq(genericCustomTokenPolygon.balanceOf(sender), 0);
        assertEq(genericCustomTokenPolygon.totalSupply(), 0);
    }

    function test_withdraw_success_partialWithdraw() public {
        uint256 depositAmount = 1000e18;
        uint256 withdrawAmount = 300e18;

        // First deposit tokens
        simulateDeposit(sender, depositAmount);
        assertEq(genericCustomTokenPolygon.balanceOf(sender), depositAmount);

        // Then withdraw partial amount
        simulateWithdraw(sender, withdrawAmount);

        assertEq(genericCustomTokenPolygon.balanceOf(sender), depositAmount - withdrawAmount);
        assertEq(genericCustomTokenPolygon.totalSupply(), depositAmount - withdrawAmount);
    }

    function test_withdraw_success_multipleUsers() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        uint256 amount1 = 1000e18;
        uint256 amount2 = 2000e18;

        // Deposit to both users
        simulateDeposit(user1, amount1);
        simulateDeposit(user2, amount2);

        // User1 withdraws
        simulateWithdraw(user1, amount1);

        assertEq(genericCustomTokenPolygon.balanceOf(user1), 0);
        assertEq(genericCustomTokenPolygon.balanceOf(user2), amount2);
        assertEq(genericCustomTokenPolygon.totalSupply(), amount2);
    }

    function test_withdraw_revertsWithInsufficientBalance() public {
        uint256 depositAmount = 500e18;
        uint256 withdrawAmount = 1000e18;

        // Deposit less than we try to withdraw
        simulateDeposit(sender, depositAmount);

        vm.expectRevert();
        simulateWithdraw(sender, withdrawAmount);
    }

    function test_withdraw_revertsWhenPaused() public {
        uint256 amount = 1000e18;

        // First deposit tokens
        simulateDeposit(sender, amount);

        vm.prank(owner);
        genericCustomTokenPolygon.pause();

        vm.expectRevert();
        simulateWithdraw(sender, amount);
    }

    function test_onlyChildChainManager_allowsChildChainManager() public {
        uint256 amount = 1000e18;
        bytes memory depositData = abi.encode(amount);

        // Should succeed when called by child chain manager
        vm.prank(childChainManager);
        genericCustomTokenPolygon.deposit(sender, depositData);

        assertEq(genericCustomTokenPolygon.balanceOf(sender), amount);
    }

    function test_onlyChildChainManager_revertsForUnauthorized() public {
        uint256 amount = 1000e18;
        bytes memory depositData = abi.encode(amount);

        // Should revert when called by unauthorized address
        vm.expectRevert(CustomToken.Unauthorized.selector);
        vm.prank(makeAddr("unauthorized"));
        genericCustomTokenPolygon.deposit(sender, depositData);
    }
}
