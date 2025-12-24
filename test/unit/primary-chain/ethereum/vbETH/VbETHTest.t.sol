// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity 0.8.29;

import {VbETHTestBase} from "test/base/primary-chain/VbETHTestBase.sol";
import {VaultBridgeToken, PausableUpgradeable} from "src/primary-chain/VaultBridgeToken.sol";
import {IAgglayerBridge} from "src/etc/IAgglayerBridge.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IWETH9} from "src/etc/IWETH9.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MockAgglayerBridge} from "test/utils/mocks/MockAgglayerBridge.sol";

import {InitializationCounterUpgradeable} from "src/etc/InitializationCounterUpgradeable.sol";

/**
 * @title VbEth Unit Tests
 * @notice Comprehensive unit tests for VbEth contract
 */
contract VbETHTest is VbETHTestBase {
    using SafeERC20 for IERC20;

    function setUp() public virtual {
        deployVbETHInfrastructure();
    }

    function test_depositGasToken(address receiver, uint256 depositAmount) public {
        vm.assume(receiver != address(0));
        vm.assume(receiver != address(vbETH));
        vm.assume(depositAmount > 0 && depositAmount < 100 ether);

        // Get initial balance
        uint256 initialReceiverBalance = vbETH.balanceOf(receiver);

        // Deposit ETH
        vm.deal(address(this), depositAmount);
        uint256 shares = vbETH.depositGasToken{value: depositAmount}(receiver);

        // Verify
        assertGt(shares, 0, "Should receive shares for deposit");
        assertEq(vbETH.balanceOf(receiver), initialReceiverBalance + shares, "Receiver should get correct shares");
    }

    function test_Revert_depositGasTokenAndBridge_invalidNetworkID() public {
        uint256 depositAmount = 1 ether;

        // Deposit ETH
        vm.deal(address(this), depositAmount);

        vm.expectRevert(VaultBridgeToken.InvalidDestinationNetworkId.selector);
        vbETH.depositGasTokenAndBridge{value: depositAmount}(address(this), 0, true);
    }

    function test_depositGasTokenAndBridge(address receiver, uint256 depositAmount) public {
        vm.assume(receiver != address(0));
        vm.assume(receiver != address(vbETH));
        vm.assume(depositAmount > 0 && depositAmount < 100 ether);

        // Deposit ETH
        vm.deal(address(this), depositAmount);
        uint256 shares = vbETH.depositGasTokenAndBridge{value: depositAmount}(receiver, NETWORK_ID_L2, true);

        assertGt(shares, 0, "Should receive shares for deposit");
    }

    function test_depositWETH(address receiver, uint256 depositAmount) public {
        vm.assume(receiver != address(0));
        vm.assume(receiver != address(vbETH));
        vm.assume(depositAmount > 0 && depositAmount < 100 ether);

        // Deal WETH directly
        _dealWETH(address(this), depositAmount);

        // Approve and deposit WETH
        IERC20(underlyingToken).forceApprove(address(vbETH), depositAmount);
        uint256 shares = vbETH.deposit(depositAmount, receiver);

        assertEq(vbETH.balanceOf(receiver), shares, "Receiver should get correct shares");
    }

    function test_mint() public {
        uint256 amount = 1 ether;

        // Deal ETH to test contract (with extra for refund test)
        vm.deal(address(this), amount + 1 ether);

        uint256 initialBalance = IWETH9(underlyingToken).balanceOf(address(this));

        // Mint with extra ETH to test refund functionality
        vbETH.mintWithGasToken{value: amount + 1 ether}(amount, address(this));

        // Check refund
        assertEq(IWETH9(underlyingToken).balanceOf(address(this)), initialBalance + 1 ether);

        assertEq(vbETH.balanceOf(address(this)), amount); // shares minted to the sender
        assertApproxEqAbs(vbETH.totalAssets(), amount, 2); // allow for rounding

        uint256 reserveAmount = calculateReserveAssets(amount, yieldVault.maxDeposit(address(vbETH)));
        assertApproxEqAbs(vbETH.reservedAssets(), reserveAmount, 2); // allow for rounding
    }

    function test_withdraw_from_reserve() public {
        uint256 amount = 1 ether;
        uint256 vaultMaxDeposit = yieldVault.maxDeposit(address(vbETH));

        // Deal ETH and deposit
        vm.deal(address(this), amount);
        uint256 shares = vbETH.depositGasToken{value: amount}(address(this));
        assertEq(vbETH.balanceOf(address(this)), shares); // sender gets shares

        uint256 reserveAssetsAfterDeposit = calculateReserveAssets(amount, vaultMaxDeposit);

        uint256 reserveWithdrawAmount = (reserveAssetsAfterDeposit * 90) / 100; // withdraw 90% of reserve assets
        uint256 reserveAfterWithdraw = reserveAssetsAfterDeposit - reserveWithdrawAmount;

        uint256 initialBalance = IWETH9(underlyingToken).balanceOf(address(this));

        vm.expectEmit();
        emit IERC4626.Withdraw(
            address(this), address(this), address(this), reserveWithdrawAmount, reserveWithdrawAmount
        );
        vbETH.withdraw(reserveWithdrawAmount, address(this), address(this));
        assertEq(IWETH9(underlyingToken).balanceOf(address(vbETH)), reserveAfterWithdraw); // reserve assets reduced
        assertEq(IWETH9(underlyingToken).balanceOf(address(this)), initialBalance + reserveWithdrawAmount); // assets returned to sender
        assertEq(vbETH.balanceOf(address(this)), amount - reserveWithdrawAmount); // shares reduced
    }

    function test_withdraw_from_stake() public {
        uint256 amount = 1 ether;

        // Deal ETH and deposit
        vm.deal(address(this), amount);
        uint256 shares = vbETH.depositGasToken{value: amount}(address(this));
        assertEq(vbETH.balanceOf(address(this)), shares); // sender gets shares

        uint256 amountToWithdraw = amount - 1;
        uint256 initialBalance = IWETH9(underlyingToken).balanceOf(address(this));

        vm.expectEmit();
        emit IERC4626.Withdraw(address(this), address(this), address(this), amountToWithdraw, amountToWithdraw);
        vbETH.withdraw(amountToWithdraw, address(this), address(this));
        assertEq(IWETH9(underlyingToken).balanceOf(address(vbETH)), 1); // reserve assets reduced (minimum reserve is 1 due to rounding)
        assertEq(IWETH9(underlyingToken).balanceOf(address(this)), initialBalance + amountToWithdraw); // assets returned to sender
        assertEq(vbETH.balanceOf(address(this)), amount - amountToWithdraw); // shares reduced
    }

    function test_completeMigration_CUSTOM_no_discrepancy() public {
        uint256 assets = 100 ether;
        uint256 shares = 100 ether;

        // Make sure the assets is less than the max deposit limit
        uint256 vaultMaxDeposit = yieldVault.maxDeposit(address(vbETH));
        if (assets > vaultMaxDeposit) {
            assets = vaultMaxDeposit / 2;
            shares = vaultMaxDeposit / 2;
        }

        bytes memory callData = abi.encodeCall(vbETHPart2.completeMigration, (NETWORK_ID_L2, shares, assets));
        _testPauseUnpause(owner, address(vbETH), callData);

        // For VbEth, deal WETH tokens instead of ETH
        _dealWETH(address(vbETH), assets);

        vm.expectRevert(VaultBridgeToken.Unauthorized.selector);
        vbETHPart2.completeMigration(NETWORK_ID_L2, shares, assets);

        vm.startPrank(migrationManagerAddr);

        vm.expectRevert(VaultBridgeToken.InvalidOriginNetwork.selector);
        vbETHPart2.completeMigration(NETWORK_ID_L1, 0, assets);

        vm.expectRevert(VaultBridgeToken.InvalidShares.selector);
        vbETHPart2.completeMigration(NETWORK_ID_L2, 0, assets);

        uint256 stakedAssetsBefore = vbETH.stakedAssets();

        vm.expectEmit();
        emit MockAgglayerBridge.BridgeEvent(
            LEAF_TYPE_ASSET,
            NETWORK_ID_L1,
            address(vbETH),
            NETWORK_ID_L2,
            address(0),
            shares,
            tokenMetadata,
            MockAgglayerBridge(agglayerBridge).depositCount()
        );
        vm.expectEmit();
        emit IERC4626.Deposit(migrationManagerAddr, address(vbETH), assets, shares);
        vm.expectEmit();
        emit VaultBridgeToken.MigrationCompleted(NETWORK_ID_L2, shares, assets, 0);
        vbETHPart2.completeMigration(NETWORK_ID_L2, shares, assets);

        vm.stopPrank();

        assertEq(
            vbETH.reservedAssets(), vbETH.convertToAssets(shares) * minimumReservePercentage / MAX_RESERVE_PERCENTAGE
        );
        assertGt(vbETH.stakedAssets(), stakedAssetsBefore);
    }

    function test_completeMigration_CUSTOM_with_discrepancy() public {
        uint256 assets = 100 ether;
        uint256 shares = 110 ether;

        // Make sure the assets is less than the max deposit limit
        uint256 vaultMaxDeposit = yieldVault.maxDeposit(address(vbETH));
        if (assets > vaultMaxDeposit) {
            assets = vaultMaxDeposit / 2;
            shares = (vaultMaxDeposit / 2) + 10;
        }

        // For VbEth, deal WETH tokens instead of ETH
        _dealWETH(address(vbETH), assets);

        vm.expectRevert(abi.encodeWithSelector(VaultBridgeToken.CannotCompleteMigration.selector, shares, assets, 0));
        vm.prank(migrationManagerAddr);
        vbETHPart2.completeMigration(NETWORK_ID_L2, shares, assets);

        // Fund the migration fees
        _dealWETH(address(this), assets);
        IERC20(underlyingToken).forceApprove(address(vbETH), assets);
        vm.expectEmit();
        emit VaultBridgeToken.DonatedForCompletingMigration(address(this), assets);
        vbETHPart2.donateForCompletingMigration(assets);

        uint256 stakedAssetsBefore = vbETH.stakedAssets();

        vm.expectEmit();
        emit MockAgglayerBridge.BridgeEvent(
            LEAF_TYPE_ASSET,
            NETWORK_ID_L1,
            address(vbETH),
            NETWORK_ID_L2,
            address(0),
            shares,
            tokenMetadata,
            MockAgglayerBridge(agglayerBridge).depositCount()
        );
        vm.expectEmit();
        emit IERC4626.Deposit(migrationManagerAddr, address(vbETH), assets, shares);
        vm.expectEmit();
        emit VaultBridgeToken.MigrationCompleted(NETWORK_ID_L2, shares, assets, shares - assets);
        vm.prank(migrationManagerAddr);
        vbETHPart2.completeMigration(NETWORK_ID_L2, shares, assets);

        assertEq(
            vbETH.reservedAssets(), vbETH.convertToAssets(shares) * minimumReservePercentage / MAX_RESERVE_PERCENTAGE
        );
        assertGt(vbETH.stakedAssets(), stakedAssetsBefore);
    }
}
