// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
pragma solidity 0.8.29;

import {VbETH} from "src/vault-bridge-tokens/vbETH/VbETH.sol";
import {VaultBridgeToken, PausableUpgradeable} from "src/VaultBridgeToken.sol";
import {ILxLyBridge} from "src/etc/ILxLyBridge.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IWETH9} from "src/etc/IWETH9.sol";
import {
    GenericVaultBridgeTokenTest,
    GenericVaultBridgeToken,
    VaultBridgeTokenPart2,
    IERC20,
    SafeERC20
} from "test/GenericVaultBridgeToken.t.sol";
import {VaultBridgeTokenInitializer} from "src/VaultBridgeTokenInitializer.sol";
import {TestVault} from "test/etc/TestVault.sol";
import {ILxLyBridge as _ILxLyBridge} from "test/interfaces/ILxLyBridge.sol";
import {WETHNativeConverter} from "src/custom-tokens/WETH/WETHNativeConverter.sol";

contract LXLYBridgeMock {
    address public gasTokenAddress;
    uint32 public gasTokenNetwork;

    function setGasTokenAddress(address _gasTokenAddress) external {
        gasTokenAddress = _gasTokenAddress;
    }

    function setGasTokenNetwork(uint32 _gasTokenNetwork) external {
        gasTokenNetwork = _gasTokenNetwork;
    }

    function networkID() external pure returns (uint32) {
        return 1;
    }

    function wrappedAddressIsNotMintable(address wrappedAddress) external pure returns (bool isNotMintable) {
        (wrappedAddress);
        return true;
    }
}

contract VbETHTest is GenericVaultBridgeTokenTest {
    using SafeERC20 for IERC20;

    VbETH public vbETH;
    LXLYBridgeMock public lxlyBridgeMock;
    address public morphoVault;

    address constant DUMMY_ADDRESS = 0xAd1490c248c5d3CbAE399Fd529b79B42984277DF;
    uint32 constant DUMMY_NETWORK_ID = 2;

    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint32 constant ZKEVM_NETWORK_ID = 1; // zkEVM

    function setUp() public override {
        mainnetFork = vm.createSelectFork("mainnet");

        lxlyBridgeMock = new LXLYBridgeMock();
        asset = WETH;
        vbTokenVault = new TestVault(asset);
        version = "0.5.0";
        name = "Vault Bridge ETH";
        symbol = "vbETH";
        decimals = 18;
        vbTokenMetaData = abi.encode(name, symbol, decimals);
        minimumReservePercentage = 1e17;
        initializer = address(new VaultBridgeTokenInitializer());

        vbTokenVault.setMaxDeposit(MAX_DEPOSIT);
        vbTokenVault.setMaxWithdraw(MAX_WITHDRAW);

        // Deploy implementation
        vbToken = GenericVaultBridgeToken(payable(address(new VbETH())));
        vbTokenImplementation = address(vbToken);

        vbTokenPart2 = new VaultBridgeTokenPart2();

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
            minimumYieldVaultDeposit: MINIMUM_YIELD_VAULT_DEPOSIT,
            migrationManager: migrationManager,
            yieldVaultMaximumSlippagePercentage: YIELD_VAULT_ALLOWED_SLIPPAGE,
            vaultBridgeTokenPart2: address(vbTokenPart2)
        });
        bytes memory initData = abi.encodeCall(vbETH.initialize, (initializer, initParams));

        // deploy proxy and initialize implementation
        vbToken = GenericVaultBridgeToken(payable(_proxify(address(vbTokenImplementation), address(this), initData)));
        vbTokenPart2 = VaultBridgeTokenPart2(payable(address(vbToken)));
        vbETH = VbETH(payable(address(vbToken)));

        // fund the migration manager manually since the test is not using the actual migration manager
        deal(asset, migrationManager, 10000000 ether);
        vm.prank(migrationManager);
        IERC20(asset).forceApprove(address(vbToken), 10000000 ether);

        vm.label(address(vbTokenVault), "WETH Vault");
        vm.label(address(vbToken), "vbETH");
        vm.label(address(vbTokenImplementation), "vbETH Implementation");
        vm.label(address(this), "Default Address");
        vm.label(asset, "Underlying Asset");
        vm.label(migrationManager, "Migration Manager");
        vm.label(owner, "Owner");
        vm.label(recipient, "Recipient");
        vm.label(sender, "Sender");
        vm.label(yieldRecipient, "Yield Recipient");
        vm.label(LXLY_BRIDGE, "Lxly Bridge");
    }

    function test_initialize() public override {
        vm.revertToState(stateBeforeInitialize);

        bytes memory initData;
        VaultBridgeToken.InitializationParameters memory initParams = VaultBridgeToken.InitializationParameters({
            owner: address(0),
            name: name,
            symbol: symbol,
            underlyingToken: asset,
            minimumReservePercentage: minimumReservePercentage,
            yieldVault: address(vbTokenVault),
            yieldRecipient: yieldRecipient,
            lxlyBridge: LXLY_BRIDGE,
            minimumYieldVaultDeposit: MINIMUM_YIELD_VAULT_DEPOSIT,
            migrationManager: migrationManager,
            yieldVaultMaximumSlippagePercentage: YIELD_VAULT_ALLOWED_SLIPPAGE,
            vaultBridgeTokenPart2: address(vbTokenPart2)
        });

        initData = abi.encodeCall(vbToken.initialize, (address(0), initParams));
        vm.expectRevert(VaultBridgeToken.InvalidInitializer.selector);
        vbToken = GenericVaultBridgeToken(payable(_proxify(vbTokenImplementation, address(this), initData)));

        initData = abi.encodeCall(vbToken.initialize, (initializer, initParams));
        vm.expectRevert(VaultBridgeToken.InvalidOwner.selector);
        vbToken = GenericVaultBridgeToken(payable(_proxify(vbTokenImplementation, address(this), initData)));
        vm.revertToState(stateBeforeInitialize);

        initParams.owner = owner;
        initParams.name = "";
        initData = abi.encodeCall(vbToken.initialize, (initializer, initParams));
        vm.expectRevert(VaultBridgeToken.InvalidName.selector);
        vbToken = GenericVaultBridgeToken(payable(_proxify(vbTokenImplementation, address(this), initData)));

        initParams.name = name;
        initParams.symbol = "";
        initData = abi.encodeCall(vbToken.initialize, (initializer, initParams));
        vm.expectRevert(VaultBridgeToken.InvalidSymbol.selector);
        vbToken = GenericVaultBridgeToken(payable(_proxify(vbTokenImplementation, address(this), initData)));

        initParams.symbol = symbol;
        initParams.underlyingToken = address(0);
        initData = abi.encodeCall(vbToken.initialize, (initializer, initParams));
        /// forge-config: default.allow_internal_expect_revert = true
        vm.expectRevert(VaultBridgeToken.InvalidUnderlyingToken.selector);
        vbToken = GenericVaultBridgeToken(payable(_proxify(vbTokenImplementation, address(this), initData)));

        initParams.underlyingToken = asset;
        initParams.minimumReservePercentage = 1e19;
        initData = abi.encodeCall(vbToken.initialize, (initializer, initParams));
        vm.expectRevert(VaultBridgeToken.InvalidMinimumReservePercentage.selector);
        vbToken = GenericVaultBridgeToken(payable(_proxify(vbTokenImplementation, address(this), initData)));

        initParams.minimumReservePercentage = minimumReservePercentage;
        initParams.yieldVault = address(0);
        initData = abi.encodeCall(vbToken.initialize, (initializer, initParams));
        vm.expectRevert(VaultBridgeToken.InvalidYieldVault.selector);
        vbToken = GenericVaultBridgeToken(payable(_proxify(vbTokenImplementation, address(this), initData)));

        initParams.yieldVault = address(vbTokenVault);
        initParams.yieldRecipient = address(0);
        initData = abi.encodeCall(vbToken.initialize, (initializer, initParams));
        vm.expectRevert(VaultBridgeToken.InvalidYieldRecipient.selector);
        vbToken = GenericVaultBridgeToken(payable(_proxify(vbTokenImplementation, address(this), initData)));

        initParams.yieldRecipient = yieldRecipient;
        initParams.lxlyBridge = address(0);
        initData = abi.encodeCall(vbToken.initialize, (initializer, initParams));
        vm.expectRevert(VaultBridgeToken.InvalidLxLyBridge.selector);
        vbToken = GenericVaultBridgeToken(payable(_proxify(vbTokenImplementation, address(this), initData)));

        initParams.lxlyBridge = address(lxlyBridgeMock);
        initParams.migrationManager = address(0);
        initData = abi.encodeCall(vbToken.initialize, (initializer, initParams));
        vm.expectRevert(VaultBridgeToken.InvalidMigrationManager.selector);
        vbToken = GenericVaultBridgeToken(payable(_proxify(vbTokenImplementation, address(this), initData)));

        initParams.migrationManager = migrationManager;
        initParams.yieldVaultMaximumSlippagePercentage = 1e19;
        initData = abi.encodeCall(vbToken.initialize, (initializer, initParams));
        vm.expectRevert(VaultBridgeToken.InvalidYieldVaultMaximumSlippagePercentage.selector);
        vbToken = GenericVaultBridgeToken(payable(_proxify(vbTokenImplementation, address(this), initData)));

        initParams.yieldVaultMaximumSlippagePercentage = YIELD_VAULT_ALLOWED_SLIPPAGE;
        initParams.vaultBridgeTokenPart2 = address(0);
        initData = abi.encodeCall(vbToken.initialize, (initializer, initParams));
        vm.expectRevert(VaultBridgeToken.InvalidVaultBridgeTokenPart2.selector);
        vbToken = GenericVaultBridgeToken(payable(_proxify(vbTokenImplementation, address(this), initData)));

        lxlyBridgeMock.setGasTokenAddress(address(0));
        lxlyBridgeMock.setGasTokenNetwork(DUMMY_NETWORK_ID);

        initParams.vaultBridgeTokenPart2 = address(vbTokenPart2);
        initParams.lxlyBridge = address(lxlyBridgeMock);
        initData = abi.encodeCall(vbToken.initialize, (initializer, initParams));
        vm.expectRevert(VbETH.ContractNotSupportedOnThisNetwork.selector);
        vbToken = GenericVaultBridgeToken(payable(_proxify(vbTokenImplementation, address(this), initData)));

        lxlyBridgeMock.setGasTokenAddress(DUMMY_ADDRESS);
        lxlyBridgeMock.setGasTokenNetwork(0);

        initParams.lxlyBridge = address(lxlyBridgeMock);
        initData = abi.encodeCall(vbToken.initialize, (initializer, initParams));
        vm.expectRevert(VbETH.ContractNotSupportedOnThisNetwork.selector);
        vbToken = GenericVaultBridgeToken(payable(_proxify(vbTokenImplementation, address(this), initData)));
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

    function test_depositGasTokenAndBridge(address receiver, uint256 depositAmount) public {
        vm.assume(receiver != address(0));
        vm.assume(receiver != address(vbETH));
        vm.assume(depositAmount > 0 && depositAmount < 100 ether);

        // Deposit ETH
        vm.deal(address(this), depositAmount);
        uint256 shares = vbETH.depositGasTokenAndBridge{value: depositAmount}(receiver, ZKEVM_NETWORK_ID, true);

        assertGt(shares, 0, "Should receive shares for deposit");
    }

    function test_depositWETH(address receiver, uint256 depositAmount) public {
        vm.assume(receiver != address(0));
        vm.assume(receiver != address(vbETH));
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
        uint256 amount = 1 ether;
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
        uint256 amount = 1 ether;
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
        uint256 amount = 1 ether;

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

    function test_completeMigration_CUSTOM_no_discrepancy() public {
        uint256 assets = 100 ether;
        uint256 shares = 100 ether;

        // make sure the assets is less than the max deposit limit
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));
        if (assets > vaultMaxDeposit) {
            assets = vaultMaxDeposit / 2;
            shares = vaultMaxDeposit / 2;
        }

        bytes memory callData = abi.encodeCall(vbTokenPart2.completeMigration, (NETWORK_ID_L2, shares, assets));
        _testPauseUnpause(owner, address(vbETH), callData);

        deal(address(vbToken), assets);

        vm.expectRevert(VaultBridgeToken.Unauthorized.selector);
        vbTokenPart2.completeMigration(NETWORK_ID_L2, shares, assets);

        vm.startPrank(migrationManager);

        vm.expectRevert(VaultBridgeToken.InvalidOriginNetwork.selector);
        vbTokenPart2.completeMigration(NETWORK_ID_L1, 0, assets);

        vm.expectRevert(VaultBridgeToken.InvalidShares.selector);
        vbTokenPart2.completeMigration(NETWORK_ID_L2, 0, assets);

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
        emit IERC4626.Deposit(migrationManager, address(vbToken), assets, shares);
        vm.expectEmit();
        emit VaultBridgeToken.MigrationCompleted(NETWORK_ID_L2, shares, assets, 0);
        vbTokenPart2.completeMigration(NETWORK_ID_L2, shares, assets);

        vm.stopPrank();

        assertEq(
            vbToken.reservedAssets(),
            vbToken.convertToAssets(shares) * minimumReservePercentage / MAX_RESERVE_PERCENTAGE
        );
        assertGt(vbToken.stakedAssets(), stakedAssetsBefore);
    }

    function test_completeMigration_CUSTOM_with_discrepancy() public {
        uint256 assets = 100 ether;
        uint256 shares = 110 ether;

        // make sure the assets is less than the max deposit limit
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));
        if (assets > vaultMaxDeposit) {
            assets = vaultMaxDeposit / 2;
            shares = (vaultMaxDeposit / 2) + 10;
        }

        deal(address(vbToken), assets);

        vm.expectRevert(abi.encodeWithSelector(VaultBridgeToken.CannotCompleteMigration.selector, shares, assets, 0));
        vm.prank(migrationManager);
        vbTokenPart2.completeMigration(NETWORK_ID_L2, shares, assets);

        // fund the migration fees
        deal(asset, address(this), assets);
        IERC20(asset).forceApprove(address(vbToken), assets);
        vm.expectEmit();
        emit VaultBridgeToken.DonatedForCompletingMigration(address(this), assets);
        vbTokenPart2.donateForCompletingMigration(assets);

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
        emit IERC4626.Deposit(migrationManager, address(vbToken), assets, shares);
        vm.expectEmit();
        emit VaultBridgeToken.MigrationCompleted(NETWORK_ID_L2, shares, assets, shares - assets);
        vm.prank(migrationManager);
        vbTokenPart2.completeMigration(NETWORK_ID_L2, shares, assets);

        assertEq(
            vbToken.reservedAssets(),
            vbToken.convertToAssets(shares) * minimumReservePercentage / MAX_RESERVE_PERCENTAGE
        );
        assertGt(vbToken.stakedAssets(), stakedAssetsBefore);
    }
}
