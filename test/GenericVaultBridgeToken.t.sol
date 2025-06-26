// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import "forge-std/Test.sol";

import {GenericVaultBridgeToken} from "src/vault-bridge-tokens/GenericVaultBridgeToken.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {VaultBridgeToken, PausableUpgradeable, Initializable} from "src/VaultBridgeToken.sol";
import {VaultBridgeTokenInitializer} from "src/VaultBridgeTokenInitializer.sol";
import {VaultBridgeTokenPart2} from "src/VaultBridgeTokenPart2.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {TestVault} from "test/etc/TestVault.sol";
import {ILxLyBridge as _ILxLyBridge} from "test/interfaces/ILxLyBridge.sol";

contract GenericVaultBridgeTokenTest is Test {
    using SafeERC20 for IERC20;
    using SafeERC20 for GenericVaultBridgeToken;

    // constants
    address constant LXLY_BRIDGE = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
    uint32 constant NETWORK_ID_L1 = 0;
    uint32 constant NETWORK_ID_L2 = 1;
    uint8 constant LEAF_TYPE_ASSET = 0;
    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes4 constant PERMIT_SIGNATURE = 0xd505accf;
    address internal constant TEST_TOKEN = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 internal constant MAX_RESERVE_PERCENTAGE = 1e18;
    uint256 internal constant MAX_DEPOSIT = 10e18;
    uint256 internal constant MAX_WITHDRAW = 10e18;
    uint256 internal constant MINIMUM_YIELD_VAULT_DEPOSIT = 1e12;
    uint256 internal constant YIELD_VAULT_ALLOWED_SLIPPAGE = 1e16; // 1%
    bytes32 internal constant RESERVE_ASSET_STORAGE =
        hex"f082fbc4cfb4d172ba00d34227e208a31ceb0982bc189440d519185302e44702";

    uint256 stateBeforeInitialize;
    uint256 mainnetFork;
    TestVault vbTokenVault;
    GenericVaultBridgeToken vbToken;
    VaultBridgeTokenPart2 vbTokenPart2;
    address vbTokenImplementation;
    address asset;

    address migrationManager = makeAddr("migrationManager");
    address owner = makeAddr("owner");
    address recipient = makeAddr("recipient");
    uint256 senderPrivateKey = 0xBEEF;
    address sender = vm.addr(senderPrivateKey);
    address yieldRecipient = makeAddr("yieldRecipient");

    // events
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

    // vbToken metadata
    string version;
    string name;
    string symbol;
    uint256 decimals;
    uint256 minimumReservePercentage;
    bytes vbTokenMetaData;
    address initializer;

    function setUp() public virtual {
        mainnetFork = vm.createSelectFork("mainnet");

        asset = TEST_TOKEN;
        vbTokenVault = new TestVault(asset);
        version = "0.5.0";
        name = "Vault Bridge USDC";
        symbol = "vbUSDC";
        decimals = 6;
        vbTokenMetaData = abi.encode(name, symbol, decimals);
        minimumReservePercentage = 1e17;
        initializer = address(new VaultBridgeTokenInitializer());

        vbTokenVault.setMaxDeposit(MAX_DEPOSIT);
        vbTokenVault.setMaxWithdraw(MAX_WITHDRAW);

        // deploy the vbToken part 2
        vbTokenPart2 = new VaultBridgeTokenPart2();

        vbToken = new GenericVaultBridgeToken();
        vbTokenImplementation = address(vbToken);
        stateBeforeInitialize = vm.snapshotState();
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
        bytes memory initData = abi.encodeCall(vbToken.initialize, (initializer, initParams));
        vbToken = GenericVaultBridgeToken(payable(_proxify(address(vbTokenImplementation), address(this), initData)));
        vbTokenPart2 = VaultBridgeTokenPart2(payable(address(vbToken)));

        // fund the migration manager manually since the test is not using the actual migration manager
        deal(asset, migrationManager, 10000000 ether);
        vm.prank(migrationManager);
        IERC20(asset).forceApprove(address(vbToken), 10000000 ether);

        vm.label(address(vbTokenVault), "vbToken Vault");
        vm.label(address(vbToken), "vbToken");
        vm.label(address(vbTokenImplementation), "vbToken Implementation");
        vm.label(address(this), "Default Address");
        vm.label(asset, "Underlying Asset");
        vm.label(migrationManager, "Migration Manager");
        vm.label(owner, "Owner");
        vm.label(recipient, "Recipient");
        vm.label(sender, "Sender");
        vm.label(yieldRecipient, "Yield Recipient");
        vm.label(LXLY_BRIDGE, "Lxly Bridge");
        vm.label(initializer, "Initializer");
        vm.label(address(vbTokenPart2), "vbToken Part 2");
    }

    function test_setup() public view {
        assert(vbToken.hasRole(vbToken.DEFAULT_ADMIN_ROLE(), owner));
        assertEq(vbToken.name(), name);
        assertEq(vbToken.symbol(), symbol);
        assertEq(vbToken.decimals(), decimals);
        assertEq(vbToken.asset(), asset);
        assertEq(vbToken.minimumReservePercentage(), minimumReservePercentage);
        assertEq(address(vbToken.yieldVault()), address(vbTokenVault));
        assertEq(vbToken.yieldRecipient(), yieldRecipient);
        assertEq(address(vbToken.lxlyBridge()), LXLY_BRIDGE);
        assertEq(vbToken.migrationManager(), migrationManager);
        assertEq(vbToken.allowance(address(vbToken), LXLY_BRIDGE), type(uint256).max);
        assertEq(IERC20(asset).allowance(address(vbToken), address(vbToken.yieldVault())), type(uint256).max);
    }

    function test_initialize_twice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
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
        vbToken.initialize(initializer, initParams);
    }

    function test_initialize() public virtual {
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

        initParams.lxlyBridge = LXLY_BRIDGE;
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
    }

    function test_deposit_revert() public {
        uint256 amount = 1 ether;

        bytes memory callData = abi.encodeCall(vbToken.deposit, (amount, recipient));
        _testPauseUnpause(owner, address(vbToken), callData);

        deal(asset, sender, amount);

        vm.startPrank(sender);

        vm.expectRevert(VaultBridgeToken.InvalidAssets.selector);
        vbToken.deposit(0, recipient);

        vm.expectRevert(VaultBridgeToken.InvalidReceiver.selector);
        vbToken.deposit(amount, address(0));

        vm.expectRevert(VaultBridgeToken.InvalidReceiver.selector);
        vbToken.deposit(amount, address(vbToken));

        vm.stopPrank();
    }

    function test_deposit_amount_gt_max_deposit() public {
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));
        uint256 amount = (vaultMaxDeposit * 10) / 9 + 1; // account for the minimum reserve percentage and add to make the amount greater than the max deposit limit
        assertGt(amount, MINIMUM_YIELD_VAULT_DEPOSIT, "Amount should be greater than the minimum deposit.");

        deal(asset, sender, amount);

        vm.startPrank(sender);

        uint256 sharesToBeMinted = vbToken.previewDeposit(amount);
        IERC20(asset).forceApprove(address(vbToken), amount);
        vm.expectEmit();
        emit IERC4626.Deposit(sender, recipient, amount, sharesToBeMinted);
        vbToken.deposit(amount, recipient);

        vm.stopPrank();

        // since max deposit is reached, the reserve amount should be calculated based on the max deposit limit
        uint256 reserveAssetsAfterDeposit = _calculateReserveAssets(amount, vaultMaxDeposit);

        assertEq(IERC20(asset).balanceOf(address(vbToken)), reserveAssetsAfterDeposit); // reserve assets increased
        assertGt(vbTokenVault.balanceOf(address(vbToken)), 0); // shares locked in the vault
        assertEq(vbToken.balanceOf(recipient), sharesToBeMinted); // shares minted to the recipient
    }

    function test_deposit_exceeds_max_and_reserve_above_threshold() public {
        uint256 amount = 100 ether; // use a large amount to ensure reserve exceeds the threshold
        assertGt(amount, MAX_DEPOSIT, "Amount should be greater than the max deposit.");

        uint256 reserveAssetsAfterDeposit = _calculateReserveAssets(amount, MAX_DEPOSIT);
        uint256 reserveThreshold = 3 * minimumReservePercentage; // the threshold is set to 3x the minimum reserve percentage according to the spec
        uint256 maxDepositPercentage = Math.mulDiv(reserveAssetsAfterDeposit, 1e18, amount);

        assertGt(
            maxDepositPercentage,
            reserveThreshold,
            "Max deposit percentage should be greater than the reserve threshold."
        );

        deal(asset, sender, amount);

        vm.startPrank(sender);

        uint256 sharesToBeMinted = vbToken.previewDeposit(amount);
        IERC20(asset).forceApprove(address(vbToken), amount);
        vm.expectEmit();
        emit IERC4626.Deposit(sender, recipient, amount, sharesToBeMinted);
        vbToken.deposit(amount, recipient);

        vm.stopPrank();

        // since the reserve percentage is above the threshold, the reserve amount should be calculated based on the rebalanced amount
        uint256 newAmount = reserveAssetsAfterDeposit;
        uint256 finalReserveAssets = _calculateReserveAssets(newAmount, MAX_DEPOSIT);

        assertEq(IERC20(asset).balanceOf(address(vbToken)), finalReserveAssets); // reserve assets increased
        assertGt(vbTokenVault.balanceOf(address(vbToken)), 0); // shares locked in the vault
        assertEq(vbToken.balanceOf(recipient), sharesToBeMinted); // shares minted to the recipient
    }

    function test_deposit_amount_lt_max_deposit() public {
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));
        uint256 amount = (vaultMaxDeposit * 10) / 9 - 1; // account for the minimum reserve percentage and subtract to make the amount less than the max deposit limit
        assertGt(amount, MINIMUM_YIELD_VAULT_DEPOSIT, "Amount should be greater than the minimum deposit.");

        deal(asset, sender, amount);

        vm.startPrank(sender);

        uint256 sharesToBeMinted = vbToken.previewDeposit(amount);
        IERC20(asset).forceApprove(address(vbToken), amount);
        vm.expectEmit();
        emit IERC4626.Deposit(sender, recipient, amount, sharesToBeMinted);
        vbToken.deposit(amount, recipient);

        vm.stopPrank();

        // since max deposit is not reached, the reserve amount should be calculated based on the deposit amount
        uint256 reserveAssets = (amount * minimumReservePercentage) / MAX_RESERVE_PERCENTAGE;

        assertEq(IERC20(asset).balanceOf(address(vbToken)), reserveAssets); // reserve assets increased
        assertGt(vbTokenVault.balanceOf(address(vbToken)), 0); // shares locked in the vault
        assertEq(vbToken.balanceOf(recipient), sharesToBeMinted); // shares minted to the recipient
    }

    function test_deposit_amount_lt_minimum_deposit() public {
        uint256 amount = MINIMUM_YIELD_VAULT_DEPOSIT - 1;

        deal(asset, sender, amount);

        vm.startPrank(sender);

        uint256 sharesToBeMinted = vbToken.previewDeposit(amount);
        IERC20(asset).forceApprove(address(vbToken), amount);
        vm.expectEmit();
        emit IERC4626.Deposit(sender, recipient, amount, sharesToBeMinted);
        vbToken.deposit(amount, recipient);

        vm.stopPrank();

        assertEq(IERC20(asset).balanceOf(address(vbToken)), amount); // All assets are reserved and non are deposited in the vault
        assertEq(vbTokenVault.balanceOf(address(vbToken)), 0); // No assets deposited in the vault
        assertEq(vbToken.balanceOf(recipient), sharesToBeMinted); // shares minted to the recipient
    }

    function test_depositWithPermit_revert() public {
        uint256 amount = 100 ether;

        deal(asset, sender, amount);
        vm.startPrank(sender);

        vm.expectRevert(VaultBridgeToken.InvalidPermitData.selector);
        vbToken.depositWithPermit(amount, recipient, bytes(""));

        vm.stopPrank();
    }

    function test_depositWithPermit() public virtual {
        uint256 amount = 1 ether;
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));

        deal(asset, sender, amount);

        bytes32 domainSeparator = IERC20Permit(asset).DOMAIN_SEPARATOR();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            senderPrivateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    domainSeparator, // remember to use the domain separator of the underlying token
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH, sender, address(vbToken), amount, vm.getNonce(sender), block.timestamp
                        )
                    )
                )
            )
        );
        bytes memory permitData =
            abi.encodeWithSelector(PERMIT_SIGNATURE, sender, address(vbToken), amount, block.timestamp, v, r, s);

        uint256 sharesToBeMinted = vbToken.previewDeposit(amount);

        vm.startPrank(sender);
        vm.expectEmit();
        emit IERC4626.Deposit(sender, recipient, amount, sharesToBeMinted);
        vbToken.depositWithPermit(amount, recipient, permitData);
        vm.stopPrank();

        uint256 reserveAssetsAfterDeposit = _calculateReserveAssets(amount, vaultMaxDeposit);

        assertEq(IERC20(asset).balanceOf(address(vbToken)), reserveAssetsAfterDeposit); // reserve assets increased
        assertEq(vbToken.balanceOf(recipient), sharesToBeMinted); // shares minted to the recipient
    }

    function test_depositAndBridge_revert() public {
        uint256 amount = 100 ether;

        vm.expectRevert(VaultBridgeToken.InvalidDestinationNetworkId.selector);
        vbToken.depositAndBridge(amount, recipient, 0, true);
    }

    function test_depositAndBridge() public {
        uint256 amount = 1 ether;
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));

        bytes memory callData = abi.encodeCall(vbToken.depositAndBridge, (amount, recipient, NETWORK_ID_L2, true));
        _testPauseUnpause(owner, address(vbToken), callData);

        deal(asset, sender, amount);

        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(vbToken), amount);
        vm.expectEmit();
        emit BridgeEvent(
            LEAF_TYPE_ASSET,
            NETWORK_ID_L1,
            address(vbToken),
            NETWORK_ID_L2,
            recipient,
            amount,
            vbTokenMetaData,
            _ILxLyBridge(LXLY_BRIDGE).depositCount()
        );
        vbToken.depositAndBridge(amount, recipient, NETWORK_ID_L2, true);
        vm.stopPrank();

        uint256 reserveAssetsAfterDeposit = _calculateReserveAssets(amount, vaultMaxDeposit);

        assertEq(IERC20(asset).balanceOf(address(vbToken)), reserveAssetsAfterDeposit); // reserve assets increased
        assertEq(vbToken.balanceOf(LXLY_BRIDGE), amount); // shares locked on bridge
    }

    function test_depositAndBridgePermit() public virtual {
        uint256 amount = 1 ether;
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));

        deal(asset, sender, amount);

        bytes32 domainSeparator = IERC20Permit(asset).DOMAIN_SEPARATOR();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            senderPrivateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    domainSeparator, // remember to use the domain separator of the underlying token
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH, sender, address(vbToken), amount, vm.getNonce(sender), block.timestamp
                        )
                    )
                )
            )
        );
        bytes memory permitData =
            abi.encodeWithSelector(PERMIT_SIGNATURE, sender, address(vbToken), amount, block.timestamp, v, r, s);

        vm.startPrank(sender);
        vm.expectEmit();
        emit BridgeEvent(
            LEAF_TYPE_ASSET,
            NETWORK_ID_L1,
            address(vbToken),
            NETWORK_ID_L2,
            recipient,
            amount,
            vbTokenMetaData,
            _ILxLyBridge(LXLY_BRIDGE).depositCount()
        );
        vbToken.depositWithPermitAndBridge(amount, recipient, NETWORK_ID_L2, true, permitData);
        vm.stopPrank();

        uint256 reserveAssetsAfterDeposit = _calculateReserveAssets(amount, vaultMaxDeposit);

        assertEq(IERC20(asset).balanceOf(address(vbToken)), reserveAssetsAfterDeposit);
        assertEq(vbToken.balanceOf(LXLY_BRIDGE), amount); // shares locked on bridge
    }

    function test_mint() public virtual {
        uint256 amount = 1 ether;
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));

        bytes memory callData = abi.encodeCall(vbToken.mint, (amount, recipient));
        _testPauseUnpause(owner, address(vbToken), callData);

        deal(asset, sender, amount);
        uint256 sharesToBeMinted = vbToken.previewMint(amount);

        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(vbToken), amount);
        vbToken.mint(amount, sender);
        vm.stopPrank();

        uint256 reserveAssetsAfterDeposit = _calculateReserveAssets(amount, vaultMaxDeposit);

        assertEq(IERC20(asset).balanceOf(address(vbToken)), reserveAssetsAfterDeposit);
        assertEq(vbToken.balanceOf(sender), sharesToBeMinted); // shares minted to the recipient
    }

    function test_withdraw_revert() public {
        uint256 amountGtMaxWithdraw = 100 ether;

        bytes memory callData = abi.encodeCall(vbToken.withdraw, (amountGtMaxWithdraw, recipient, sender));
        _testPauseUnpause(owner, address(vbToken), callData);

        vm.expectRevert(VaultBridgeToken.InvalidAssets.selector);
        vbToken.withdraw(0, recipient, sender);

        vm.expectRevert(VaultBridgeToken.InvalidReceiver.selector);
        vbToken.withdraw(amountGtMaxWithdraw, address(0), sender);

        vm.expectRevert(VaultBridgeToken.InvalidOwner.selector);
        vbToken.withdraw(amountGtMaxWithdraw, recipient, address(0));

        uint256 stateBeforeDeposit = vm.snapshotState();

        deal(asset, sender, amountGtMaxWithdraw);

        vm.startPrank(sender);

        IERC20(asset).forceApprove(address(vbToken), amountGtMaxWithdraw);
        vbToken.deposit(amountGtMaxWithdraw, sender);
        assertEq(IERC20(asset).balanceOf(sender), 0); // make sure sender has deposited all assets
        assertEq(vbToken.balanceOf(sender), amountGtMaxWithdraw);

        uint256 withdrawableAmount = _calculateWithdrawableAmount(amountGtMaxWithdraw);
        uint256 availableAmount = vbToken.reservedAssets() + withdrawableAmount;
        vm.expectRevert(
            abi.encodeWithSelector(VaultBridgeToken.AssetsTooLarge.selector, availableAmount, amountGtMaxWithdraw + 1)
        );
        vbToken.withdraw(amountGtMaxWithdraw + 1, sender, sender);

        vm.revertToState(stateBeforeDeposit);

        uint256 amountLtMaxWithdraw = MAX_WITHDRAW - 1;

        deal(asset, sender, amountLtMaxWithdraw);

        IERC20(asset).forceApprove(address(vbToken), amountLtMaxWithdraw);
        vbToken.deposit(amountLtMaxWithdraw, sender);
        assertEq(IERC20(asset).balanceOf(sender), 0); // make sure sender has deposited all assets
        assertEq(vbToken.balanceOf(sender), amountLtMaxWithdraw);

        vm.expectRevert("TestVault: Insufficient balance");
        vbToken.withdraw(amountLtMaxWithdraw + 1, sender, sender);

        vm.revertToState(stateBeforeDeposit);

        uint256 amount = 1 ether;

        deal(asset, sender, amount);

        IERC20(asset).forceApprove(address(vbToken), amount);
        vbToken.deposit(amount, sender);
        assertEq(IERC20(asset).balanceOf(sender), 0); // make sure sender has deposited all assets
        assertEq(vbToken.balanceOf(sender), amount);

        uint256 withdrawAmount = vbToken.stakedAssets();
        uint256 slippageAmount = Math.mulDiv(
            withdrawAmount, YIELD_VAULT_ALLOWED_SLIPPAGE + Math.mulDiv(YIELD_VAULT_ALLOWED_SLIPPAGE, 1, 100), 1e18
        );
        vbTokenVault.setSlippage(true, slippageAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                VaultBridgeToken.ExcessiveYieldVaultSharesBurned.selector,
                withdrawAmount + slippageAmount,
                withdrawAmount
            )
        );
        vbToken.withdraw(amount, sender, sender);

        vm.stopPrank();
    }

    function test_withdraw_from_reserve() public virtual {
        uint256 amount = 1 ether;
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));

        deal(asset, sender, amount);

        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(vbToken), amount);
        vbToken.deposit(amount, sender);
        assertEq(IERC20(asset).balanceOf(sender), 0); // make sure sender has deposited all assets
        assertEq(vbToken.balanceOf(sender), amount);

        uint256 reserveAssetsAfterDeposit = _calculateReserveAssets(amount, vaultMaxDeposit);
        uint256 reserveWithdrawAmount = (reserveAssetsAfterDeposit * 90) / 100; // withdraw 90% of reserve assets
        uint256 reserveAfterWithdraw = reserveAssetsAfterDeposit - reserveWithdrawAmount;

        vm.expectEmit();
        emit IERC4626.Withdraw(sender, sender, sender, reserveWithdrawAmount, reserveWithdrawAmount);
        vbToken.withdraw(reserveWithdrawAmount, sender, sender);
        assertEq(IERC20(asset).balanceOf(address(vbToken)), reserveAfterWithdraw); // reserve assets reduced
        assertEq(IERC20(asset).balanceOf(sender), reserveWithdrawAmount); // assets returned to sender
        assertEq(vbToken.balanceOf(sender), amount - reserveWithdrawAmount); // shares reduced

        vm.stopPrank();
    }

    function test_withdraw_from_stake() public virtual {
        uint256 amount = 1 ether;

        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(vbToken), amount);
        vbToken.deposit(amount, sender);
        assertEq(IERC20(asset).balanceOf(sender), 0); // make sure sender has deposited all assets
        assertEq(vbToken.balanceOf(sender), amount);

        uint256 amountToWithdraw = amount;

        vm.expectEmit();
        emit IERC4626.Withdraw(sender, sender, sender, amountToWithdraw, amountToWithdraw);
        vbToken.withdraw(amountToWithdraw, sender, sender);
        assertEq(IERC20(asset).balanceOf(sender), amountToWithdraw);
        assertEq(IERC20(asset).balanceOf(address(vbToken)), 0); // reserve assets reduced
        assertEq(IERC20(asset).balanceOf(sender), amountToWithdraw); // assets returned to sender
        assertEq(vbToken.balanceOf(sender), amount - amountToWithdraw); // shares reduced
        vm.stopPrank();
    }

    function test_rebalanceReserve_revert() public {
        vm.expectRevert(); // only owner can rebalance reserve
        (address(vbToken).call(abi.encodeCall(vbTokenPart2.rebalanceReserve, ())));

        bytes memory callData = abi.encodeCall(vbTokenPart2.rebalanceReserve, ());
        _testPauseUnpause(owner, address(vbToken), callData);
    }

    function test_rebalanceReserve_below() public virtual {
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));
        uint256 amount = (vaultMaxDeposit * 10) / 9 + 1; // account for the minimum reserve percentage and add to make the amount greater than the max deposit limit
        assertGt(amount, MINIMUM_YIELD_VAULT_DEPOSIT, "Amount should be greater than the minimum deposit.");

        uint256 totalSupply;
        deal(asset, sender, amount); // fund the sender

        uint256 reserveAmount = _calculateReserveAssets(amount, vaultMaxDeposit);

        // create reserve
        vm.startPrank(sender);

        IERC20(asset).forceApprove(address(vbToken), amount);
        vbToken.deposit(amount, recipient);
        totalSupply += amount;
        assertEq(vbToken.reservedAssets(), reserveAmount);

        uint256 stakedAssetsBefore = vbToken.stakedAssets();

        // offset the reserve by reducing the reserve assets
        vm.store(address(vbToken), RESERVE_ASSET_STORAGE, bytes32(uint256(reserveAmount - 100)));

        vm.stopPrank();

        uint256 finalReserveAmount = totalSupply * minimumReservePercentage / MAX_RESERVE_PERCENTAGE;
        uint256 finalPercentage = finalReserveAmount * 1e18 / totalSupply;
        vm.expectEmit();
        emit VaultBridgeToken.ReserveRebalanced(reserveAmount - 100, finalReserveAmount, finalPercentage);
        vm.prank(owner);
        (address(vbToken).call(abi.encodeCall(vbTokenPart2.rebalanceReserve, ())));

        assertEq(vbToken.reservedAssets(), finalReserveAmount);
        assertGt(stakedAssetsBefore, vbToken.stakedAssets()); // staked assets would be reduced as reserve is replinished from the vault
    }

    function test_rebalanceReserve_above() public virtual {
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));
        uint256 amount = vaultMaxDeposit / 2;
        assertGt(amount, MINIMUM_YIELD_VAULT_DEPOSIT, "Amount should be greater than the minimum deposit.");

        uint256 totalSupply;
        deal(asset, sender, amount); // fund the sender

        uint256 reserveAmount = _calculateReserveAssets(amount, vaultMaxDeposit);

        vm.startPrank(sender);

        IERC20(asset).forceApprove(address(vbToken), amount);
        vbToken.deposit(amount, recipient);
        totalSupply += amount;
        assertEq(vbToken.reservedAssets(), reserveAmount);

        uint256 stakedAssetsBefore = vbToken.stakedAssets();

        // offset the reserve by increasing the reserve assets
        vm.store(address(vbToken), RESERVE_ASSET_STORAGE, bytes32(uint256(reserveAmount + MINIMUM_YIELD_VAULT_DEPOSIT)));

        vm.stopPrank();

        uint256 finalReserveAmount = totalSupply * minimumReservePercentage / MAX_RESERVE_PERCENTAGE;
        uint256 finalPercentage = finalReserveAmount * 1e18 / totalSupply;
        vm.expectEmit();
        emit VaultBridgeToken.ReserveRebalanced(
            reserveAmount + MINIMUM_YIELD_VAULT_DEPOSIT, finalReserveAmount, finalPercentage
        );
        vm.prank(owner);
        vbTokenPart2.rebalanceReserve();

        assertEq(vbToken.reservedAssets(), finalReserveAmount);
        assertGt(vbToken.stakedAssets(), stakedAssetsBefore); //  staked assets would be increased as execess reserve is deposited in the vault
    }

    function test_collectYield() public {
        vm.expectRevert(); // only owner can claim yield
        vbTokenPart2.collectYield();

        vm.expectRevert(VaultBridgeToken.NoYield.selector); // no reserved and staked assets
        vm.prank(owner);
        vbTokenPart2.collectYield();

        uint256 amount = 100 ether;
        uint256 yieldInAssets = 500 ether;

        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(vbToken), amount);
        vbToken.mint(amount, sender);
        vm.stopPrank();

        uint256 sharesBalanceBefore = vbTokenVault.balanceOf(address(vbToken));
        uint256 yieldShares = vbTokenVault.convertToShares(yieldInAssets);

        deal(address(vbTokenVault), address(vbToken), sharesBalanceBefore + yieldShares); // add yield to the vault

        uint256 expectedYieldAssets = vbToken.yield();

        vm.expectEmit();
        emit VaultBridgeToken.YieldCollected(yieldRecipient, expectedYieldAssets);
        vm.prank(owner);
        vbTokenPart2.collectYield();

        vm.assertEq(vbToken.balanceOf(yieldRecipient), expectedYieldAssets);
    }

    function test_setYieldRecipient_no_yield() public {
        address newRecipient = makeAddr("newRecipient");
        vm.expectRevert(); // only owner can claim yield
        vbTokenPart2.setYieldRecipient(newRecipient);

        vm.expectRevert(VaultBridgeToken.InvalidYieldRecipient.selector);
        vm.prank(owner);
        vbTokenPart2.setYieldRecipient(address(0));

        assertEq(vbToken.yieldRecipient(), yieldRecipient);

        vm.expectEmit();
        emit VaultBridgeToken.YieldRecipientSet(newRecipient);
        vm.prank(owner);
        vbTokenPart2.setYieldRecipient(newRecipient);
        assertEq(vbToken.yieldRecipient(), newRecipient);
    }

    function test_setYieldRecipient_with_yield() public {
        uint256 amount = 100 ether;
        uint256 yieldInAssets = 500 ether;
        address newRecipient = makeAddr("newRecipient");

        // generate yield
        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(vbToken), amount);
        vbToken.mint(amount, sender);
        vm.stopPrank();

        uint256 sharesBalanceBefore = vbTokenVault.balanceOf(address(vbToken));
        uint256 yieldShares = vbTokenVault.convertToShares(yieldInAssets);

        deal(address(vbTokenVault), address(vbToken), sharesBalanceBefore + yieldShares); // add yield to the vault

        uint256 expectedYieldAssets = vbToken.yield();

        assertEq(vbToken.yieldRecipient(), yieldRecipient);

        vm.expectEmit();
        emit VaultBridgeToken.YieldCollected(yieldRecipient, expectedYieldAssets);
        vm.prank(owner);
        vbTokenPart2.setYieldRecipient(newRecipient);
        assertEq(vbToken.balanceOf(yieldRecipient), expectedYieldAssets); // yield collected to the old recipient
        assertEq(vbToken.yieldRecipient(), newRecipient);
    }

    function test_setMinimumReservePercentage_no_rebalance() public {
        uint256 newPercentage = 2e17;
        vm.expectRevert(); // only owner can set minimum reserve percentage
        vbTokenPart2.setMinimumReservePercentage(newPercentage);

        vm.expectRevert(VaultBridgeToken.InvalidMinimumReservePercentage.selector);
        vm.prank(owner);
        vbTokenPart2.setMinimumReservePercentage(MAX_RESERVE_PERCENTAGE + 1);

        assertEq(vbToken.minimumReservePercentage(), minimumReservePercentage); // sanity check

        vm.expectEmit();
        emit VaultBridgeToken.MinimumReservePercentageSet(newPercentage);
        vm.prank(owner);
        vbTokenPart2.setMinimumReservePercentage(newPercentage);
        assertEq(vbToken.minimumReservePercentage(), newPercentage);
    }

    function test_redeem_revert() public {
        bytes memory callData = abi.encodeCall(vbToken.redeem, (100 ether, sender, sender));
        _testPauseUnpause(owner, address(vbToken), callData);

        vm.expectRevert(VaultBridgeToken.InvalidShares.selector);
        vbToken.redeem(0, sender, sender);

        vm.stopPrank();
    }

    function test_redeem() public virtual {
        uint256 amount = 1 ether;

        deal(asset, sender, amount);

        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(vbToken), amount);
        vbToken.deposit(amount, sender);
        assertEq(IERC20(asset).balanceOf(sender), 0);
        assertEq(vbToken.balanceOf(sender), amount);

        uint256 redeemAmount = vbToken.totalAssets();

        vbToken.redeem(redeemAmount, sender, sender); // redeem from both staked and reserved assets
        assertEq(IERC20(asset).balanceOf(sender), redeemAmount);
        vm.stopPrank();
    }

    function test_completeMigration_revert() public {
        bytes memory callData = abi.encodeCall(vbTokenPart2.completeMigration, (NETWORK_ID_L1, 0, 0));
        _testPauseUnpause(owner, address(vbToken), callData);

        // Not Migration manager
        vm.expectRevert(VaultBridgeToken.Unauthorized.selector);
        vbTokenPart2.completeMigration(NETWORK_ID_L2, 100, 100);

        vm.startPrank(migrationManager);

        // Wrong network id
        vm.expectRevert(VaultBridgeToken.InvalidOriginNetwork.selector);
        vbTokenPart2.completeMigration(NETWORK_ID_L1, 100, 100);

        vm.expectRevert(VaultBridgeToken.InvalidShares.selector);
        vbTokenPart2.completeMigration(NETWORK_ID_L2, 0, 100);

        vm.stopPrank();
    }

    function test_completeMigration_no_discrepancy_shares_lt_max_deposit() public {
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));
        uint256 amount = (vaultMaxDeposit * 10) / 9 - 1;
        uint256 shares = vbToken.convertToShares(amount);

        deal(asset, address(vbToken), amount);

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
        emit IERC4626.Deposit(migrationManager, address(vbToken), amount, shares);
        vm.expectEmit();
        emit VaultBridgeToken.MigrationCompleted(NETWORK_ID_L2, shares, amount, 0);
        vm.prank(migrationManager);
        vbTokenPart2.completeMigration(NETWORK_ID_L2, shares, amount);

        uint256 reserveAssetsAfterDeposit =
            vbToken.convertToAssets(shares) * minimumReservePercentage / MAX_RESERVE_PERCENTAGE;

        assertEq(vbToken.reservedAssets(), reserveAssetsAfterDeposit);
        assertGt(vbToken.stakedAssets(), stakedAssetsBefore);
    }

    function test_completeMigration_no_discrepancy_shares_gt_max_deposit() public {
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));
        uint256 amount = (vaultMaxDeposit * 10) / 9 + 1;
        uint256 shares = vbToken.convertToShares(amount);

        deal(asset, address(vbToken), amount);

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
        emit IERC4626.Deposit(migrationManager, address(vbToken), amount, shares);
        vm.expectEmit();
        emit VaultBridgeToken.MigrationCompleted(NETWORK_ID_L2, shares, amount, 0);
        vm.prank(migrationManager);
        vbTokenPart2.completeMigration(NETWORK_ID_L2, shares, amount);

        // since max deposit is reached, the reserve amount should be calculated based on the max deposit limit
        uint256 reserveAssetsAfterDeposit = _calculateReserveAssets(amount, vaultMaxDeposit);

        assertEq(vbToken.reservedAssets(), reserveAssetsAfterDeposit);
        assertGt(vbToken.stakedAssets(), stakedAssetsBefore);
    }

    function test_completeMigration_with_discrepancy() public {
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));
        uint256 amount = (vaultMaxDeposit * 10) / 9 - 1;
        uint256 shares = vbToken.convertToShares(amount) + vbToken.convertToShares(1);

        // no migration fees funds
        vm.expectRevert(abi.encodeWithSelector(VaultBridgeToken.CannotCompleteMigration.selector, shares, amount, 0));
        vm.prank(migrationManager);
        vbTokenPart2.completeMigration(NETWORK_ID_L2, shares, amount);

        // fund the migration fees
        deal(asset, address(this), amount);
        IERC20(asset).forceApprove(address(vbToken), amount);
        vm.expectEmit();
        emit VaultBridgeToken.DonatedForCompletingMigration(address(this), amount);
        vbTokenPart2.donateForCompletingMigration(amount);

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
        emit IERC4626.Deposit(migrationManager, address(vbToken), amount, shares);
        vm.expectEmit();
        emit VaultBridgeToken.MigrationCompleted(NETWORK_ID_L2, shares, amount, shares - amount);
        vm.prank(migrationManager);
        vbTokenPart2.completeMigration(NETWORK_ID_L2, shares, amount);

        uint256 reserveAssetsAfterDeposit =
            vbToken.convertToAssets(shares) * minimumReservePercentage / MAX_RESERVE_PERCENTAGE;

        assertEq(vbToken.reservedAssets(), reserveAssetsAfterDeposit);
        assertGt(vbToken.stakedAssets(), stakedAssetsBefore);
    }

    function test_maxDeposit() public {
        assertEq(vbToken.maxDeposit(address(0)), type(uint256).max);

        vm.prank(owner);
        vbTokenPart2.pause();
        assertEq(vbToken.maxDeposit(address(0)), 0);
    }

    function test_previewDeposit() public {
        uint256 amount = 100 ether;

        bytes memory callData = abi.encodeCall(vbToken.previewDeposit, (amount));
        _testPauseUnpause(owner, address(vbToken), callData);

        vm.expectRevert(VaultBridgeToken.InvalidAssets.selector);
        vbToken.previewDeposit(0);

        vm.assertEq(vbToken.previewDeposit(amount), amount);
    }

    function test_maxMint() public virtual {
        assertEq(vbToken.maxMint(address(0)), type(uint256).max);

        vm.prank(owner);
        vbTokenPart2.pause();
        assertEq(vbToken.maxMint(address(0)), 0);
    }

    function test_previewMint() public virtual {
        uint256 amount = 100 ether;

        bytes memory callData = abi.encodeCall(vbToken.previewMint, (amount));
        _testPauseUnpause(owner, address(vbToken), callData);

        vm.expectRevert(VaultBridgeToken.InvalidShares.selector);
        vbToken.previewMint(0);

        vm.assertEq(vbToken.previewMint(amount), amount);
    }

    function test_maxWithdraw() public virtual {
        uint256 amount = 1 ether;

        vm.startPrank(owner);
        vbTokenPart2.pause();
        vm.assertEq(vbToken.maxWithdraw(address(0)), 0);
        vbTokenPart2.unpause();
        vm.stopPrank();

        assertEq(vbToken.maxWithdraw(address(0)), 0); // 0 if no shares

        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(vbToken), amount);
        vbToken.deposit(amount, sender);
        vm.stopPrank();

        assertEq(vbToken.maxWithdraw(sender), vbToken.totalAssets());
    }

    function test_previewWithdraw() public virtual {
        uint256 amount = 11 ether;
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));

        bytes memory callData = abi.encodeCall(vbToken.previewWithdraw, (amount));
        _testPauseUnpause(owner, address(vbToken), callData);

        vm.expectRevert(VaultBridgeToken.InvalidAssets.selector);
        vbToken.previewWithdraw(0);

        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(vbToken), amount);
        vbToken.deposit(amount, sender);
        vm.stopPrank();

        uint256 withdrawableAmount = _calculateWithdrawableAmount(amount + 1 ether);
        uint256 availableAmount = vbToken.reservedAssets() + withdrawableAmount;
        vm.expectRevert(
            abi.encodeWithSelector(VaultBridgeToken.AssetsTooLarge.selector, availableAmount, amount + 1 ether)
        );
        vbToken.previewWithdraw(amount + 1 ether);

        uint256 stakedAmount = vbTokenVault.convertToAssets(vbTokenVault.balanceOf(address(vbToken)));
        uint256 reserveAssetsAfterDeposit = _calculateReserveAssets(amount, vaultMaxDeposit);

        vm.assertEq(vbToken.previewWithdraw(reserveAssetsAfterDeposit), vbToken.reservedAssets()); // reserve assets
        vm.assertEq(vbToken.previewWithdraw(reserveAssetsAfterDeposit + stakedAmount), vbToken.totalAssets()); // reserve + staked assets
    }

    function test_maxRedeem() public virtual {
        uint256 amount = 1 ether;

        vm.startPrank(owner);
        vbTokenPart2.pause();
        vm.assertEq(vbToken.maxRedeem(sender), 0);
        vbTokenPart2.unpause();
        vm.stopPrank();

        assertEq(vbToken.maxRedeem(sender), 0); // 0 if no shares

        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(vbToken), amount);
        vbToken.deposit(amount, sender);
        vm.stopPrank();

        assertEq(vbToken.maxRedeem(sender), vbToken.totalAssets());
    }

    function test_previewRedeem() public virtual {
        uint256 amount = 1 ether;
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));
        uint256 reserveAmount = (amount * minimumReservePercentage) / MAX_RESERVE_PERCENTAGE;

        bytes memory callData = abi.encodeCall(vbToken.previewRedeem, (amount));
        _testPauseUnpause(owner, address(vbToken), callData);

        vm.expectRevert(VaultBridgeToken.InvalidShares.selector);
        vbToken.previewRedeem(0);

        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(vbToken), amount);
        vbToken.deposit(amount, sender);
        vm.stopPrank();

        uint256 stakedAmount = vbTokenVault.convertToAssets(vbTokenVault.balanceOf(address(vbToken)));
        uint256 assetsToDeposit = amount - reserveAmount;
        uint256 assetsToDepositMax = (assetsToDeposit > vaultMaxDeposit) ? vaultMaxDeposit : assetsToDeposit;
        uint256 reserveAssetsAfterDeposit = amount - assetsToDepositMax;

        vm.assertEq(vbToken.previewRedeem(reserveAssetsAfterDeposit), vbToken.reservedAssets()); // reserve assets
        vm.assertEq(vbToken.previewRedeem(reserveAssetsAfterDeposit + stakedAmount), vbToken.totalAssets()); // reserve + staked assets
    }

    function test_reservePercentage() public {
        uint256 amount = 1 ether;
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));

        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(vbToken), amount);
        vbToken.deposit(amount, sender);
        vm.stopPrank();

        uint256 reserveAssetsAfterDeposit = _calculateReserveAssets(amount, vaultMaxDeposit);

        uint256 expectedPercentage = (reserveAssetsAfterDeposit * MAX_RESERVE_PERCENTAGE) / vbToken.totalSupply();

        assertEq(vbToken.reservePercentage(), expectedPercentage);
    }

    function test_pause_unpause() public {
        vm.expectRevert();
        vbTokenPart2.pause();

        vm.expectRevert();
        vbTokenPart2.unpause();

        vm.startPrank(owner);
        vm.expectEmit();
        emit PausableUpgradeable.Paused(owner);
        vbTokenPart2.pause();

        vm.expectEmit();
        emit PausableUpgradeable.Unpaused(owner);
        vbTokenPart2.unpause();
        vm.stopPrank();
    }

    function test_version() public view {
        assertEq(vbToken.version(), version);
    }

    function test_approve() public {
        assertTrue(vbToken.approve(address(0xBEEF), 1e18));

        assertEq(vbToken.allowance(address(this), address(0xBEEF)), 1e18);
    }

    // ERC20 tests
    function test_transfer() public virtual {
        deal(address(vbToken), address(this), 1e18);

        assertTrue(vbToken.transfer(address(0xBEEF), 1e18));

        assertEq(vbToken.balanceOf(address(this)), 0);
        assertEq(vbToken.balanceOf(address(0xBEEF)), 1e18);
    }

    function test_transferFrom() public virtual {
        address from = address(0xABCD);
        deal(address(vbToken), from, 1e18);

        vm.prank(from);
        vbToken.forceApprove(address(this), 1e18);

        assertTrue(vbToken.transferFrom(from, address(0xBEEF), 1e18));

        assertEq(vbToken.allowance(from, address(this)), 0);

        assertEq(vbToken.balanceOf(from), 0);
        assertEq(vbToken.balanceOf(address(0xBEEF)), 1e18);
    }

    function test_infiniteApproveTransferFrom() public virtual {
        address from = address(0xABCD);
        deal(address(vbToken), from, 1e18);

        vm.prank(from);
        vbToken.forceApprove(address(this), type(uint256).max);

        assertTrue(vbToken.transferFrom(from, address(0xBEEF), 1e18));

        assertEq(vbToken.allowance(from, address(this)), type(uint256).max);

        assertEq(vbToken.balanceOf(from), 0);
        assertEq(vbToken.balanceOf(address(0xBEEF)), 1e18);
    }

    function test_failTransferInsufficientBalance() public {
        deal(address(vbToken), address(this), 0.9e18);
        vm.expectRevert();
        vbToken.transfer(address(0xBEEF), 1e18);
    }

    function test_failTransferFromInsufficientAllowance() public virtual {
        address from = address(0xABCD);

        deal(address(vbToken), address(this), 1e18);

        vm.prank(from);
        vbToken.forceApprove(address(this), 0.9e18);

        vm.expectRevert();
        vbToken.transferFrom(from, address(0xBEEF), 1e18);
    }

    function test_failTransferFromInsufficientBalance() public virtual {
        address from = address(0xABCD);

        deal(address(vbToken), address(this), 0.9e18);

        vm.prank(from);
        vbToken.forceApprove(address(this), 1e18);

        vm.expectRevert();
        vbToken.transferFrom(from, address(0xBEEF), 1e18);
    }

    function test_permit() public virtual {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            senderPrivateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    vbToken.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(PERMIT_TYPEHASH, sender, address(0xCAFE), 1e18, vm.getNonce(sender), block.timestamp)
                    )
                )
            )
        );

        vm.prank(sender);
        vbToken.permit(sender, address(0xCAFE), 1e18, block.timestamp, v, r, s);

        assertEq(vbToken.allowance(sender, address(0xCAFE)), 1e18);
        assertEq(vbToken.nonces(sender), 1);
    }

    function _calculateReserveAssets(uint256 amount, uint256 vaultMaxDeposit) internal view returns (uint256) {
        uint256 reserveAssets = (amount * minimumReservePercentage) / MAX_RESERVE_PERCENTAGE;
        uint256 assetsToDeposit = amount - reserveAssets;
        uint256 assetsToDepositMax = (assetsToDeposit > vaultMaxDeposit) ? vaultMaxDeposit : assetsToDeposit;
        return amount - assetsToDepositMax;
    }

    function _calculateWithdrawableAmount(uint256 amount) internal view returns (uint256) {
        return amount - vbToken.reservedAssets() > MAX_WITHDRAW ? MAX_WITHDRAW : amount - vbToken.reservedAssets();
    }

    function _testPauseUnpause(address caller, address callee, bytes memory callData) internal {
        vm.startPrank(caller);
        (bool success, /* bytes memory data */ ) = callee.call(abi.encodeCall(vbTokenPart2.pause, ()));

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        (success, /* bytes memory data */ ) = callee.call(callData);

        (success, /* bytes memory data */ ) = callee.call(abi.encodeCall(vbTokenPart2.unpause, ()));
        vm.stopPrank();
    }

    function _proxify(address logic, address admin, bytes memory initData) internal returns (address proxy) {
        proxy = address(new TransparentUpgradeableProxy(logic, admin, initData));
    }
}
