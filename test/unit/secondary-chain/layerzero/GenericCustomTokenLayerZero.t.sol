// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test Base
import {
    GenericCustomTokenLayerZeroTestBase,
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "test/base/secondary-chain/GenericCustomTokenLayerZeroTestBase.sol";

// Core contracts
import {GenericCustomTokenLayerZero} from "src/secondary-chain/layerzero/GenericCustomTokenLayerZero.sol";
import {CustomToken} from "src/secondary-chain/CustomToken.sol";

import {InitializationCounterUpgradeable} from "src/etc/InitializationCounterUpgradeable.sol";

/// @dev GenericCustomTokenLayerZero tests
/// @notice Comprehensive tests for GenericCustomTokenLayerZero which also cover CustomTokenLayerZero functionality
contract GenericCustomTokenLayerZeroTest is GenericCustomTokenLayerZeroTestBase {
    function setUp() public virtual {
        deployGenericCustomTokenLayerZeroInfrastructure();
    }

    /// @notice Helper function to test initialization reverts with different parameters
    function _testInitializationRevert(
        bytes4 expectedError,
        address owner_,
        string memory name_,
        string memory symbol_,
        uint8 originalUnderlyingTokenDecimals_,
        address oftAdapter_
    ) internal {
        vm.revertToState(stateBeforeInitialize);

        bytes[] memory reinitializeCallData = new bytes[](1);
        reinitializeCallData[0] = abi.encodeCall(
            GenericCustomTokenLayerZero.reinitialize1,
            (owner_, name_, symbol_, originalUnderlyingTokenDecimals_, oftAdapter_)
        );

        bytes memory genericCustomTokenLayerZeroInitData =
            abi.encodeCall(GenericCustomTokenLayerZero.reinitialize, (reinitializeCallData));

        vm.expectRevert(expectedError);
        TransparentUpgradeableProxy(
            payable(_proxify(genericCustomTokenLayerZeroImpl, proxyAdmin, genericCustomTokenLayerZeroInitData))
        );
    }

    function test_initialize_revert_zeroOwner() public {
        _testInitializationRevert(
            CustomToken.InvalidOwner.selector,
            address(0),
            customTokenName,
            customTokenSymbol,
            originalUnderlyingTokenDecimals,
            oftAdapter
        );
    }

    function test_initialize_revert_emptyName() public {
        _testInitializationRevert(
            CustomToken.InvalidName.selector, owner, "", customTokenSymbol, originalUnderlyingTokenDecimals, oftAdapter
        );
    }

    function test_initialize_revert_emptySymbol() public {
        _testInitializationRevert(
            CustomToken.InvalidSymbol.selector, owner, customTokenName, "", originalUnderlyingTokenDecimals, oftAdapter
        );
    }

    function test_initialize_revert_zeroDecimals() public {
        _testInitializationRevert(
            CustomToken.InvalidOriginalUnderlyingTokenDecimals.selector,
            owner,
            customTokenName,
            customTokenSymbol,
            0,
            oftAdapter
        );
    }

    function test_initialize_revert_zeroOftAdapter() public {
        _testInitializationRevert(
            CustomToken.InvalidBridge.selector,
            owner,
            customTokenName,
            customTokenSymbol,
            originalUnderlyingTokenDecimals,
            address(0)
        );
    }

    function test_mint_success_fromOftAdapter() public {
        uint256 amount = 1000e18;

        vm.prank(oftAdapter);
        genericCustomTokenLayerZero.mint(sender, amount);

        assertEq(genericCustomTokenLayerZero.balanceOf(sender), amount);
        assertEq(genericCustomTokenLayerZero.totalSupply(), amount);
    }

    function test_mint_revert_unauthorized() public {
        uint256 amount = 1000e18;

        vm.prank(sender);
        vm.expectRevert(abi.encodeWithSelector(CustomToken.Unauthorized.selector));
        genericCustomTokenLayerZero.mint(sender, amount);
    }

    function test_burn_success_fromOftAdapter() public {
        uint256 amount = 1000e18;

        // First mint tokens
        vm.prank(oftAdapter);
        genericCustomTokenLayerZero.mint(sender, amount);

        // Then burn them
        vm.prank(oftAdapter);
        genericCustomTokenLayerZero.burn(sender, amount);

        assertEq(genericCustomTokenLayerZero.balanceOf(sender), 0);
        assertEq(genericCustomTokenLayerZero.totalSupply(), 0);
    }

    function test_burn_revert_unauthorized() public {
        uint256 amount = 1000e18;

        // First mint tokens to sender
        vm.prank(oftAdapter);
        genericCustomTokenLayerZero.mint(sender, amount);

        // Try to burn from sender (should fail)
        vm.prank(sender);
        vm.expectRevert(abi.encodeWithSelector(CustomToken.Unauthorized.selector));
        genericCustomTokenLayerZero.burn(sender, amount);
    }

    function test_mint_and_burn_multipleUsers() public {
        address user2 = makeAddr("user2");
        uint256 amount1 = 500e18;
        uint256 amount2 = 1000e18;

        // Mint to sender
        vm.prank(oftAdapter);
        genericCustomTokenLayerZero.mint(sender, amount1);

        // Mint to user2
        vm.prank(oftAdapter);
        genericCustomTokenLayerZero.mint(user2, amount2);

        assertEq(genericCustomTokenLayerZero.balanceOf(sender), amount1);
        assertEq(genericCustomTokenLayerZero.balanceOf(user2), amount2);
        assertEq(genericCustomTokenLayerZero.totalSupply(), amount1 + amount2);

        // Burn from user2
        vm.prank(oftAdapter);
        genericCustomTokenLayerZero.burn(user2, amount2);

        assertEq(genericCustomTokenLayerZero.balanceOf(sender), amount1);
        assertEq(genericCustomTokenLayerZero.balanceOf(user2), 0);
        assertEq(genericCustomTokenLayerZero.totalSupply(), amount1);
    }
}
