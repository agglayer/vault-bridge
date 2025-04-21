// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {VbETH} from "src/vault-bridge-tokens/vbETH/VbETH.sol";
import {VaultBridgeToken, PausableUpgradeable} from "src/VaultBridgeToken.sol";
import {ILxLyBridge} from "src/etc/ILxLyBridge.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IWETH9} from "src/etc/IWETH9.sol";
import {GenericVaultBridgeTokenTest, GenericVaultBridgeToken, IERC20, SafeERC20} from "test/GenericVaultBridgeToken.t.sol";
import {VaultBridgeTokenInitializer} from "src/VaultBridgeTokenInitializer.sol";
import {TestVault} from "test/etc/TestVault.sol";
import {ILxLyBridge as _ILxLyBridge} from "test/interfaces/ILxLyBridge.sol";
import {WETHNativeConverter} from "src/custom-tokens/WETH/WETHNativeConverter.sol";

contract VbETHTest is GenericVaultBridgeTokenTest {
    using SafeERC20 for IERC20;

    VbETH public vbETH;
    address public morphoVault;

    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint32 constant ZKEVM_NETWORK_ID = 1; // zkEVM

    function setUp() public override {
        mainnetFork = vm.createSelectFork("mainnet");

        asset = WETH;
        vbTokenVault = new TestVault(asset);
        version = "1.0.0";
        name = "Vault Bridge ETH";
        symbol = "vbETH";
        decimals = 18;
        vbTokenMetaData = abi.encode(name, symbol, decimals);
        minimumReservePercentage = 1e17;
        initializer = address(new VaultBridgeTokenInitializer());

        vbTokenVault.setMaxDeposit(MAX_DEPOSIT);
        vbTokenVault.setMaxWithdraw(MAX_WITHDRAW);

        // Deploy implementation
        vbToken = GenericVaultBridgeToken(address(new VbETH()));
        vbTokenImplementation = address(vbToken);
        stateBeforeInitialize = vm.snapshotState();

        // prepare calldata
        VaultBridgeToken.InitializationParameters memory initParams = VaultBridgeToken.InitializationParameters({
            owner: owner,
            name: name,
            symbol: symbol,
            underlyingToken: asset,
            minimumReservePercentage: minimumReservePercentage,
            yieldVault: address(vbTokenVault),
            yieldRecipient: yieldRecipient,
            lxlyBridge: LXLY_BRIDGE,
            nativeConverters: nativeConverter,
            minimumYieldVaultDeposit: MINIMUM_YIELD_VAULT_DEPOSIT,
            transferFeeCalculator: address(0)
        });
        bytes memory initData = abi.encodeCall(
            vbETH.initialize,
            (initializer, initParams)
        );

        // deploy proxy and initialize implementation
        vbToken = GenericVaultBridgeToken(_proxify(address(vbTokenImplementation), address(this), initData));
        vbETH = VbETH(address(vbToken));

        vm.label(address(vbTokenVault), "WETH Vault");
        vm.label(address(vbToken), "vbETH");
        vm.label(address(vbTokenImplementation), "vbETH Implementation");
        vm.label(address(this), "Default Address");
        vm.label(asset, "Underlying Asset");
        vm.label(nativeConverterAddress, "Native Converter");
        vm.label(owner, "Owner");
        vm.label(recipient, "Recipient");
        vm.label(sender, "Sender");
        vm.label(yieldRecipient, "Yield Recipient");
        vm.label(LXLY_BRIDGE, "Lxly Bridge");
    }

    function test_depositWithPermit() public override {
        // WETH has no permit function.
    }
    function test_depositAndBridgePermit() public override {
        // WETH has no permit function.
    }

    function test_basicFunctions() public view {
        assertEq(vbETH.name(), "Vault Bridge ETH");
        assertEq(vbETH.symbol(), "vbETH");
        assertEq(vbETH.asset(), WETH);
    }

    function test_depositGasToken(address receiver, uint256 depositAmount) public {
        vm.assume(receiver != address(0));
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

    function test_depositGasTokenAndBridge(address receiver, uint256 depositAmount) public {
        vm.assume(receiver != address(0));
        vm.assume(depositAmount > 0 && depositAmount < 100 ether);

        // Deposit ETH
        vm.deal(address(this), depositAmount);
        uint256 shares = vbETH.depositGasTokenAndBridge{value: depositAmount}(receiver, ZKEVM_NETWORK_ID, true);

        assertGt(shares, 0, "Should receive shares for deposit");
    }

    function test_depositWETH(address receiver, uint256 depositAmount) public {
        vm.assume(receiver != address(0));
        vm.assume(depositAmount > 0 && depositAmount < 100 ether);

        // Deposit ETH
        vm.deal(address(this), depositAmount);

        // convert and approve
        IWETH9 weth = IWETH9(WETH);
        weth.deposit{value: depositAmount}();
        weth.approve(address(vbETH), depositAmount);

        uint256 shares = vbETH.deposit(depositAmount, receiver);

        assertEq(vbETH.balanceOf(receiver), shares, "Receiver should get correct shares");
    }

    function test_mint() public override {
        uint256 amount = 100 ether;
        vm.deal(address(this), amount + 1 ether);

        uint256 initialBalance = IWETH9(WETH).balanceOf(address(this));

        // sending a bit more to test refund func
        vbETH.mintWithGasToken{value: amount + 1 ether}(amount, address(this));

        // check refund
        assertEq(IWETH9(WETH).balanceOf(address(this)), initialBalance + 1 ether);

        assertEq(vbETH.balanceOf(address(this)), amount); // shares minted to the sender
        assertApproxEqAbs(vbETH.totalAssets(), amount, 2); // allow for rounding

        uint256 reserveAmount = _calculateReserveAssets(amount, vbTokenVault.maxDeposit(address(vbToken)));
        assertApproxEqAbs(vbETH.reservedAssets(), reserveAmount, 2); // allow for rounding
    }

    function test_withdraw_from_reserve() public override {
        uint256 amount = 100 ether;
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));

        // Deposit ETH
        vm.deal(address(this), amount);
        uint256 shares = vbETH.depositGasToken{value: amount}(address(this));
        assertEq(vbETH.balanceOf(address(this)), shares); // sender gets 100 shares

        uint256 reserveAssetsAfterDeposit = _calculateReserveAssets(amount, vaultMaxDeposit);

        uint256 reserveWithdrawAmount = (reserveAssetsAfterDeposit * 90) / 100; // withdraw 90% of reserve assets
        uint256 reserveAfterWithdraw = reserveAssetsAfterDeposit - reserveWithdrawAmount;

        uint256 initialBalance = IWETH9(WETH).balanceOf(address(this));

        vm.expectEmit();
        emit IERC4626.Withdraw(
            address(this), address(this), address(this), reserveWithdrawAmount, reserveWithdrawAmount
        );
        vbETH.withdraw(reserveWithdrawAmount, address(this), address(this));
        assertEq(IWETH9(WETH).balanceOf(address(vbETH)), reserveAfterWithdraw); // reserve assets reduced
        assertEq(IWETH9(WETH).balanceOf(address(this)), initialBalance + reserveWithdrawAmount); // assets returned to sender
        assertEq(vbETH.balanceOf(address(this)), amount - reserveWithdrawAmount); // shares reduced
    }

    function test_withdraw_from_stake() public override {
        uint256 amount = 100 ether;

        // Deposit ETH
        vm.deal(address(this), amount);
        uint256 shares = vbETH.depositGasToken{value: amount}(address(this));
        assertEq(vbETH.balanceOf(address(this)), shares); // sender gets 100 shares

        uint256 amountToWithdraw = amount - 1;
        uint256 initialBalance = IWETH9(WETH).balanceOf(address(this));

        vm.expectEmit();
        emit IERC4626.Withdraw(address(this), address(this), address(this), amountToWithdraw, amountToWithdraw);
        vbToken.withdraw(amountToWithdraw, address(this), address(this));
        assertEq(IWETH9(WETH).balanceOf(address(vbETH)), 0); // reserve assets reduced
        assertEq(IWETH9(WETH).balanceOf(address(this)), initialBalance + amountToWithdraw); // assets returned to sender
        assertEq(vbETH.balanceOf(address(this)), amount - amountToWithdraw); // shares reduced
    }

    function test_rebalanceReserve_above() public override {
        // TODO: Find a way to test this
        // Disabled due to external vault slippage on deposit
    }

    function test_onMessageReceived_CUSTOM_no_discrepancy() public {
        uint256 amount = 100 ether;
        uint256 shares = 100 ether;

        // make sure the amount is less than the max deposit limit
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));
        if (amount > vaultMaxDeposit) {
            amount = vaultMaxDeposit / 2;
            shares = vaultMaxDeposit / 2;
        }

        bytes memory data = abi.encode(
            VaultBridgeToken.CrossNetworkInstruction.CUSTOM,
            abi.encode(
                WETHNativeConverter.CustomCrossNetworkInstruction.WRAP_COIN_AND_COMPLETE_MIGRATION,
                abi.encode(shares, amount)
            )
        );

        bytes memory callData = abi.encodeCall(vbETH.onMessageReceived, (nativeConverterAddress, NETWORK_ID_L2, data));
        _testPauseUnpause(owner, address(vbETH), callData);

        deal(address(vbToken), amount);

        vm.expectRevert(VaultBridgeToken.Unauthorized.selector);
        vbToken.onMessageReceived(nativeConverterAddress, NETWORK_ID_L2, data);

        vm.expectRevert(VaultBridgeToken.Unauthorized.selector);
        vm.prank(LXLY_BRIDGE);
        vbToken.onMessageReceived(address(0), NETWORK_ID_L2, data);

        vm.expectRevert(VaultBridgeToken.Unauthorized.selector);
        vm.prank(LXLY_BRIDGE);
        vbToken.onMessageReceived(nativeConverterAddress, NETWORK_ID_L1, data);

        bytes memory invalidSharesData = abi.encode(
            VaultBridgeToken.CrossNetworkInstruction.COMPLETE_MIGRATION,
            abi.encode(
                WETHNativeConverter.CustomCrossNetworkInstruction.WRAP_COIN_AND_COMPLETE_MIGRATION,
                abi.encode(0, amount)
            )
        );

        vm.expectRevert(VaultBridgeToken.InvalidShares.selector);
        vm.prank(LXLY_BRIDGE);
        vbToken.onMessageReceived(nativeConverterAddress, NETWORK_ID_L2, invalidSharesData);

        uint256 stakedAssetsBefore = vbToken.stakedAssets();

        vm.expectEmit();
        emit BridgeEvent(
            LEAF_TYPE_ASSET,
            NETWORK_ID_L1,
            address(vbToken),
            NETWORK_ID_L2,
            address(0),
            shares,
            vbTokenMetaData,
            _ILxLyBridge(LXLY_BRIDGE).depositCount()
        );
        vm.expectEmit();
        emit IERC4626.Deposit(LXLY_BRIDGE, address(vbToken), amount, shares);
        vm.expectEmit();
        emit VaultBridgeToken.MigrationCompleted(NETWORK_ID_L2, shares, amount, amount, 0);
        vm.prank(LXLY_BRIDGE);
        vbToken.onMessageReceived(nativeConverterAddress, NETWORK_ID_L2, data);

        assertEq(
            vbToken.reservedAssets(),
            vbToken.convertToAssets(shares) * minimumReservePercentage / MAX_MINIMUM_RESERVE_PERCENTAGE
        );
        assertGt(vbToken.stakedAssets(), stakedAssetsBefore);
    }

    function test_onMessageReceived_CUSTOM_with_discrepancy() public {
        uint256 amount = 100 ether;
        uint256 shares = 110 ether;

        // make sure the amount is less than the max deposit limit
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));
        if (amount > vaultMaxDeposit) {
            amount = vaultMaxDeposit / 2;
            shares = (vaultMaxDeposit / 2) + 10;
        }

        bytes memory data = abi.encode(
            VaultBridgeToken.CrossNetworkInstruction.CUSTOM,
            abi.encode(
                WETHNativeConverter.CustomCrossNetworkInstruction.WRAP_COIN_AND_COMPLETE_MIGRATION,
                abi.encode(shares, amount)
            )
        );

        deal(address(vbToken), amount);

        vm.expectRevert(abi.encodeWithSelector(VaultBridgeToken.CannotCompleteMigration.selector, shares, amount, 0));
        vm.prank(LXLY_BRIDGE);
        vbToken.onMessageReceived(nativeConverterAddress, NETWORK_ID_L2, data);

        // fund the migration fees
        deal(asset, address(this), amount);
        IERC20(asset).forceApprove(address(vbToken), amount);
        vm.expectEmit();
        emit VaultBridgeToken.DonatedForCompletingMigration(address(this), amount);
        vbToken.donateForCompletingMigration(amount);

        uint256 stakedAssetsBefore = vbToken.stakedAssets();

        vm.expectEmit();
        emit BridgeEvent(
            LEAF_TYPE_ASSET,
            NETWORK_ID_L1,
            address(vbToken),
            NETWORK_ID_L2,
            address(0),
            shares,
            vbTokenMetaData,
            _ILxLyBridge(LXLY_BRIDGE).depositCount()
        );
        vm.expectEmit();
        emit IERC4626.Deposit(LXLY_BRIDGE, address(vbToken), amount, shares);
        vm.expectEmit();
        emit VaultBridgeToken.MigrationCompleted(NETWORK_ID_L2, shares, amount, amount, shares - amount);
        vm.prank(LXLY_BRIDGE);
        vbToken.onMessageReceived(nativeConverterAddress, NETWORK_ID_L2, data);

        assertEq(
            vbToken.reservedAssets(),
            vbToken.convertToAssets(shares) * minimumReservePercentage / MAX_MINIMUM_RESERVE_PERCENTAGE
        );
        assertGt(vbToken.stakedAssets(), stakedAssetsBefore);
    }
}
