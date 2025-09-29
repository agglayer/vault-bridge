// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test Base
import {
    GenericCustomTokenAgglayerTestBase,
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy,
    MockERC20Upgradeable
} from "test/base/secondary-chain/GenericCustomTokenAgglayerTestBase.sol";

// Core contracts
import {GenericCustomTokenAgglayer} from "src/secondary-chain/agglayer/GenericCustomTokenAgglayer.sol";
import {CustomToken} from "src/secondary-chain/CustomToken.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev GenericCustomTokenAgglayer tests
contract GenericCustomTokenAgglayerTest is GenericCustomTokenAgglayerTestBase {
    function setUp() public virtual {
        deployGenericCustomTokenAgglayerInfrastructure();
    }

    function test_mint_success_fromBridge() public {
        uint256 amount = 1000e18;

        vm.prank(address(mockAgglayerBridge));
        genericCustomTokenAgglayer.mint(recipient, amount);

        assertEq(genericCustomTokenAgglayer.balanceOf(recipient), amount);
        assertEq(genericCustomTokenAgglayer.totalSupply(), amount);
    }

    function test_mint_success_fromNativeConverter() public {
        uint256 amount = 1000e18;

        vm.prank(dummyNativeConverter);
        genericCustomTokenAgglayer.mint(recipient, amount);

        assertEq(genericCustomTokenAgglayer.balanceOf(recipient), amount);
        assertEq(genericCustomTokenAgglayer.totalSupply(), amount);
    }

    // @todo Update.
    /*
    function test_mint_success_toAddressZero_emitsTransfer() public {
        uint256 amount = 1000e18;

        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), address(0), amount);

        vm.prank(address(mockAgglayerBridge));
        genericCustomTokenAgglayer.mint(address(0), amount);

        assertEq(genericCustomTokenAgglayer.totalSupply(), 0);
    }
    */

    function test_mint_revertsWithUnauthorized() public {
        uint256 amount = 1000e18;

        vm.expectRevert(CustomToken.Unauthorized.selector);
        vm.prank(makeAddr("unauthorized"));
        genericCustomTokenAgglayer.mint(recipient, amount);
    }

    function test_mint_revertsWhenPaused() public {
        uint256 amount = 1000e18;

        vm.prank(owner);
        genericCustomTokenAgglayer.pause();

        vm.expectRevert();
        vm.prank(address(mockAgglayerBridge));
        genericCustomTokenAgglayer.mint(recipient, amount);
    }

    function test_burn_success_fromBridge() public {
        uint256 amount = 1000e18;

        // First mint tokens
        vm.prank(address(mockAgglayerBridge));
        genericCustomTokenAgglayer.mint(sender, amount);

        assertEq(genericCustomTokenAgglayer.balanceOf(sender), amount);

        // Then burn them
        vm.prank(address(mockAgglayerBridge));
        genericCustomTokenAgglayer.burn(sender, amount);

        assertEq(genericCustomTokenAgglayer.balanceOf(sender), 0);
        assertEq(genericCustomTokenAgglayer.totalSupply(), 0);
    }

    function test_burn_success_fromNativeConverter() public {
        uint256 amount = 1000e18;

        // First mint tokens
        vm.prank(dummyNativeConverter);
        genericCustomTokenAgglayer.mint(sender, amount);

        assertEq(genericCustomTokenAgglayer.balanceOf(sender), amount);

        // Then burn them
        vm.prank(dummyNativeConverter);
        genericCustomTokenAgglayer.burn(sender, amount);

        assertEq(genericCustomTokenAgglayer.balanceOf(sender), 0);
        assertEq(genericCustomTokenAgglayer.totalSupply(), 0);
    }

    function test_burn_revertsWithUnauthorized() public {
        uint256 amount = 1000e18;

        // First mint tokens
        vm.prank(address(mockAgglayerBridge));
        genericCustomTokenAgglayer.mint(sender, amount);

        vm.expectRevert(CustomToken.Unauthorized.selector);
        vm.prank(makeAddr("unauthorized"));
        genericCustomTokenAgglayer.burn(sender, amount);
    }

    function test_burn_revertsWhenPaused() public {
        uint256 amount = 1000e18;

        // First mint tokens
        vm.prank(address(mockAgglayerBridge));
        genericCustomTokenAgglayer.mint(sender, amount);

        vm.prank(owner);
        genericCustomTokenAgglayer.pause();

        vm.expectRevert();
        vm.prank(address(mockAgglayerBridge));
        genericCustomTokenAgglayer.burn(sender, amount);
    }

    function test_burn_revertsWithInsufficientBalance() public {
        uint256 mintAmount = 500e18;
        uint256 burnAmount = 1000e18;

        // Mint less than we try to burn
        vm.prank(address(mockAgglayerBridge));
        genericCustomTokenAgglayer.mint(sender, mintAmount);

        vm.expectRevert();
        vm.prank(address(mockAgglayerBridge));
        genericCustomTokenAgglayer.burn(sender, burnAmount);
    }

    function test_mintAndBurn_multipleUsers() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        uint256 amount1 = 1000e18;
        uint256 amount2 = 2000e18;

        // Mint to both users
        vm.prank(address(mockAgglayerBridge));
        genericCustomTokenAgglayer.mint(user1, amount1);

        vm.prank(dummyNativeConverter);
        genericCustomTokenAgglayer.mint(user2, amount2);

        assertEq(genericCustomTokenAgglayer.balanceOf(user1), amount1);
        assertEq(genericCustomTokenAgglayer.balanceOf(user2), amount2);
        assertEq(genericCustomTokenAgglayer.totalSupply(), amount1 + amount2);

        // Burn from user1
        vm.prank(address(mockAgglayerBridge));
        genericCustomTokenAgglayer.burn(user1, amount1);

        assertEq(genericCustomTokenAgglayer.balanceOf(user1), 0);
        assertEq(genericCustomTokenAgglayer.balanceOf(user2), amount2);
        assertEq(genericCustomTokenAgglayer.totalSupply(), amount2);
    }
}
