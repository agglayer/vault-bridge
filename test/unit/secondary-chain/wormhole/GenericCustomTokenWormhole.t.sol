// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test Base
import {
    GenericCustomTokenWormholeTestBase,
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "test/base/secondary-chain/GenericCustomTokenWormholeTestBase.sol";

// Core contracts
import {GenericCustomTokenWormhole} from "src/secondary-chain/wormhole/GenericCustomTokenWormhole.sol";
import {CustomToken} from "src/secondary-chain/CustomToken.sol";
import {InitializationCounterUpgradeable} from "src/etc/InitializationCounterUpgradeable.sol";

// OpenZeppelin
import {IAccessControl} from "@openzeppelin-contracts/access/IAccessControl.sol";

/// @dev GenericCustomTokenWormhole tests
/// @notice Comprehensive tests for GenericCustomTokenWormhole which also cover CustomTokenWormhole functionality
contract GenericCustomTokenWormholeTest is GenericCustomTokenWormholeTestBase {
    function setUp() public virtual {
        deployGenericCustomTokenWormholeInfrastructure();
    }

    /// @notice Helper function to test initialization reverts with different parameters
    function _testInitializationRevert(
        bytes4 expectedError,
        address owner_,
        string memory name_,
        string memory symbol_,
        uint8 originalUnderlyingTokenDecimals_,
        address nttManager_
    ) internal {
        bytes[] memory reinitializeCallData = new bytes[](1);
        reinitializeCallData[0] = abi.encodeCall(
            GenericCustomTokenWormhole.reinitialize1,
            (owner_, name_, symbol_, originalUnderlyingTokenDecimals_, nttManager_)
        );

        bytes memory genericCustomTokenWormholeInitData =
            abi.encodeCall(GenericCustomTokenWormhole.reinitialize, (reinitializeCallData));

        vm.expectRevert(expectedError);
        TransparentUpgradeableProxy(
            payable(_proxify(genericCustomTokenWormholeImpl, proxyAdmin, genericCustomTokenWormholeInitData))
        );
    }

    function test_initialize_revert_zeroOwner() public {
        _testInitializationRevert(
            CustomToken.InvalidOwner.selector,
            address(0),
            customTokenName,
            customTokenSymbol,
            originalUnderlyingTokenDecimals,
            nttManager
        );
    }

    function test_initialize_revert_emptyName() public {
        _testInitializationRevert(
            CustomToken.InvalidName.selector, owner, "", customTokenSymbol, originalUnderlyingTokenDecimals, nttManager
        );
    }

    function test_initialize_revert_emptySymbol() public {
        _testInitializationRevert(
            CustomToken.InvalidSymbol.selector, owner, customTokenName, "", originalUnderlyingTokenDecimals, nttManager
        );
    }

    function test_initialize_revert_zeroDecimals() public {
        _testInitializationRevert(
            CustomToken.InvalidOriginalUnderlyingTokenDecimals.selector,
            owner,
            customTokenName,
            customTokenSymbol,
            0,
            nttManager
        );
    }

    function test_initialize_revert_zeroNttManager() public {
        _testInitializationRevert(
            CustomToken.InvalidBridge.selector,
            owner,
            customTokenName,
            customTokenSymbol,
            originalUnderlyingTokenDecimals,
            address(0)
        );
    }

    function test_mint_success_fromNttManager() public {
        uint256 amount = 1000e18;

        vm.prank(nttManager);
        genericCustomTokenWormhole.mint(sender, amount);

        assertEq(genericCustomTokenWormhole.balanceOf(sender), amount);
        assertEq(genericCustomTokenWormhole.totalSupply(), amount);
    }

    function test_mint_revert_unauthorized() public {
        uint256 amount = 1000e18;

        vm.prank(sender);
        vm.expectRevert(abi.encodeWithSelector(CustomToken.Unauthorized.selector));
        genericCustomTokenWormhole.mint(sender, amount);
    }

    function test_burn_success_fromNttManager() public {
        uint256 amount = 1000e18;

        // First mint tokens
        vm.prank(nttManager);
        genericCustomTokenWormhole.mint(nttManager, amount);

        // Then burn them
        vm.prank(nttManager);
        genericCustomTokenWormhole.burn(amount);

        assertEq(genericCustomTokenWormhole.balanceOf(nttManager), 0);
        assertEq(genericCustomTokenWormhole.totalSupply(), 0);
    }

    function test_burn_revert_unauthorized() public {
        uint256 amount = 1000e18;

        // First mint tokens to sender
        vm.prank(nttManager);
        genericCustomTokenWormhole.mint(sender, amount);

        // Try to burn from sender (should fail)
        vm.prank(sender);
        vm.expectRevert(abi.encodeWithSelector(CustomToken.Unauthorized.selector));
        genericCustomTokenWormhole.burn(amount);
    }

    function test_mint_and_burn_multipleUsers() public {
        address user2 = makeAddr("user2");
        uint256 amount1 = 500e18;
        uint256 amount2 = 1000e18;

        // Mint to sender
        vm.prank(nttManager);
        genericCustomTokenWormhole.mint(sender, amount1);

        // Mint to user2
        vm.prank(nttManager);
        genericCustomTokenWormhole.mint(user2, amount2);

        assertEq(genericCustomTokenWormhole.balanceOf(sender), amount1);
        assertEq(genericCustomTokenWormhole.balanceOf(user2), amount2);
        assertEq(genericCustomTokenWormhole.totalSupply(), amount1 + amount2);

        // Transfer from user2 to nttManager, then burn
        vm.prank(user2);
        genericCustomTokenWormhole.transfer(nttManager, amount2);

        vm.prank(nttManager);
        genericCustomTokenWormhole.burn(amount2);

        assertEq(genericCustomTokenWormhole.balanceOf(sender), amount1);
        assertEq(genericCustomTokenWormhole.balanceOf(user2), 0);
        assertEq(genericCustomTokenWormhole.balanceOf(nttManager), 0);
        assertEq(genericCustomTokenWormhole.totalSupply(), amount1);
    }

    function test_setNativeConverter_revert() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                genericCustomTokenWormhole.DEFAULT_ADMIN_ROLE()
            )
        );
        genericCustomTokenWormhole.setNativeConverter(address(1));

        vm.prank(owner);
        vm.expectRevert(CustomToken.FunctionNotSupportedWithThisBridgeProvider.selector);
        genericCustomTokenWormhole.setNativeConverter(address(1));
    }
}
