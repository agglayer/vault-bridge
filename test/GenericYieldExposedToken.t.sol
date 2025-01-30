// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

import {GenericYeToken} from "src/yield-exposed-tokens/GenericYeToken.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IMetaMorpho} from "test/interfaces/IMetaMorpho.sol";
import {ILxLyBridge as _ILxLyBridge} from "test/interfaces/ILxLyBridge.sol";

contract GenericYieldExposedTokenTest is Test {
    using SafeERC20 for IERC20;
    using SafeERC20 for GenericYeToken;

    // constants
    address constant LXLY_BRIDGE = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
    uint32 constant NETWORK_ID_L1 = 0;
    uint32 constant NETWORK_ID_L2 = 1;
    uint8 constant LEAF_TYPE_ASSET = 0;
    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes4 constant PERMIT_SIGNATURE = 0xd505accf;
    address internal constant TEST_TOKEN = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant TEST_TOKEN_VAULT = 0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB;

    uint256 stateBeforeInitialize;
    uint256 mainnetFork;
    IMetaMorpho yeTokenVault;
    GenericYeToken yeToken;
    address yeTokenImplementation;
    address asset;

    address migrationManager = makeAddr("migrationManager");
    address recipient = makeAddr("recipient");
    address owner = makeAddr("owner");
    address yieldRecipient = makeAddr("yieldRecipient");
    uint256 senderPrivateKey = 0xBEEF;
    address sender = vm.addr(senderPrivateKey);

    // yeToken metadata
    string version;
    string name;
    string symbol;
    uint256 decimals;
    uint8 minimumReservePercentage;
    bytes yeTokenMetaData;

    // error messages
    error EnforcedPause();

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
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event ReserveRebalanced(uint256 reservedAssets);
    event YieldCollected(address indexed yieldRecipient, uint256 yeTokenAmount);
    event YieldRecipientChanged(address indexed yieldRecipient);
    event MinimumReservePercentageChanged(uint8 minimumReservePercentage);
    event MigrationCompleted(
        uint32 indexed destinationNetworkId,
        uint256 indexed shares,
        uint256 assetsBeforeTransferFee,
        uint256 assets,
        uint256 usedYield
    );
    event Paused(address account);
    event Unpaused(address account);

    function setUp() public virtual {
        mainnetFork = vm.createSelectFork("mainnet_test", 21590932);

        asset = TEST_TOKEN;
        yeTokenVault = IMetaMorpho(TEST_TOKEN_VAULT);
        version = "1.0.0";
        name = "Yield Exposed USDC";
        symbol = "yeUSDC";
        decimals = 6;
        yeTokenMetaData = abi.encode(name, symbol, decimals);
        minimumReservePercentage = 10;

        yeToken = new GenericYeToken();
        yeTokenImplementation = address(yeToken);
        stateBeforeInitialize = vm.snapshotState();
        bytes memory initData = abi.encodeCall(
            yeToken.initialize,
            (
                owner,
                name,
                symbol,
                asset,
                minimumReservePercentage,
                address(yeTokenVault),
                yieldRecipient,
                LXLY_BRIDGE,
                migrationManager
            )
        );
        yeToken = GenericYeToken(_proxify(address(yeTokenImplementation), address(this), initData));

        vm.label(address(yeTokenVault), "yeToken Vault");
        vm.label(address(yeToken), "yeToken");
        vm.label(address(yeTokenImplementation), "yeToken Implementation");
        vm.label(address(this), "Default Address");
        vm.label(asset, "Underlying Asset");
        vm.label(migrationManager, "Migration Manager");
        vm.label(owner, "Owner");
        vm.label(recipient, "Recipient");
        vm.label(sender, "Sender");
        vm.label(yieldRecipient, "Yield Recipient");
        vm.label(LXLY_BRIDGE, "Lxly Bridge");
    }

    function test_setup() public view {
        assertEq(yeToken.owner(), owner);
        assertEq(yeToken.name(), name);
        assertEq(yeToken.symbol(), symbol);
        assertEq(yeToken.decimals(), decimals);
        assertEq(yeToken.asset(), asset);
        assertEq(yeToken.minimumReservePercentage(), minimumReservePercentage);
        assertEq(address(yeToken.yieldVault()), address(yeTokenVault));
        assertEq(yeToken.yieldRecipient(), yieldRecipient);
        assertEq(yeToken.migrationManager(), migrationManager);
        assertEq(address(yeToken.lxlyBridge()), LXLY_BRIDGE);
        assertEq(yeToken.allowance(address(yeToken), LXLY_BRIDGE), type(uint256).max);
        assertEq(IERC20(asset).allowance(address(yeToken), address(yeToken.yieldVault())), type(uint256).max);
    }

    function test_initialize() public virtual {
        vm.revertToState(stateBeforeInitialize);

        bytes memory initData;

        initData = abi.encodeCall(
            yeToken.initialize,
            (
                address(0),
                name,
                symbol,
                asset,
                minimumReservePercentage,
                address(yeTokenVault),
                yieldRecipient,
                LXLY_BRIDGE,
                migrationManager
            )
        );
        vm.expectRevert("INVALID_OWNER");
        yeToken = GenericYeToken(_proxify(yeTokenImplementation, address(this), initData));
        vm.revertToState(stateBeforeInitialize);

        initData = abi.encodeCall(
            yeToken.initialize,
            (
                owner,
                "",
                symbol,
                asset,
                minimumReservePercentage,
                address(yeTokenVault),
                yieldRecipient,
                LXLY_BRIDGE,
                migrationManager
            )
        );
        vm.expectRevert("INVALID_NAME");
        yeToken = GenericYeToken(_proxify(yeTokenImplementation, address(this), initData));
        vm.revertToState(stateBeforeInitialize);

        initData = abi.encodeCall(
            yeToken.initialize,
            (
                owner,
                name,
                "",
                asset,
                minimumReservePercentage,
                address(yeTokenVault),
                yieldRecipient,
                LXLY_BRIDGE,
                migrationManager
            )
        );
        vm.expectRevert("INVALID_SYMBOL");
        yeToken = GenericYeToken(_proxify(yeTokenImplementation, address(this), initData));
        vm.revertToState(stateBeforeInitialize);

        initData = abi.encodeCall(
            yeToken.initialize,
            (
                owner,
                name,
                symbol,
                address(0),
                minimumReservePercentage,
                address(yeTokenVault),
                yieldRecipient,
                LXLY_BRIDGE,
                migrationManager
            )
        );
        vm.expectRevert("INVALID_UNDERLYING_TOKEN");
        yeToken = GenericYeToken(_proxify(yeTokenImplementation, address(this), initData));
        vm.revertToState(stateBeforeInitialize);

        initData = abi.encodeCall(
            yeToken.initialize,
            (owner, name, symbol, asset, 101, address(yeTokenVault), yieldRecipient, LXLY_BRIDGE, migrationManager)
        );
        vm.expectRevert("INVALID_PERCENTAGE");
        yeToken = GenericYeToken(_proxify(yeTokenImplementation, address(this), initData));
        vm.revertToState(stateBeforeInitialize);

        initData = abi.encodeCall(
            yeToken.initialize,
            (
                owner,
                name,
                symbol,
                asset,
                minimumReservePercentage,
                address(0),
                yieldRecipient,
                LXLY_BRIDGE,
                migrationManager
            )
        );
        vm.expectRevert("INVALID_VAULT");
        yeToken = GenericYeToken(_proxify(yeTokenImplementation, address(this), initData));
        vm.revertToState(stateBeforeInitialize);

        initData = abi.encodeCall(
            yeToken.initialize,
            (
                owner,
                name,
                symbol,
                asset,
                minimumReservePercentage,
                address(yeTokenVault),
                address(0),
                LXLY_BRIDGE,
                migrationManager
            )
        );
        vm.expectRevert("INVALID_YIELD_RECIPIENT");
        yeToken = GenericYeToken(_proxify(yeTokenImplementation, address(this), initData));
        vm.revertToState(stateBeforeInitialize);

        initData = abi.encodeCall(
            yeToken.initialize,
            (
                owner,
                name,
                symbol,
                asset,
                minimumReservePercentage,
                address(yeTokenVault),
                yieldRecipient,
                address(0),
                migrationManager
            )
        );
        vm.expectRevert("INVALID_LXLY_BRIDGE");
        yeToken = GenericYeToken(_proxify(yeTokenImplementation, address(this), initData));
        vm.revertToState(stateBeforeInitialize);

        initData = abi.encodeCall(
            yeToken.initialize,
            (
                owner,
                name,
                symbol,
                asset,
                minimumReservePercentage,
                address(yeTokenVault),
                yieldRecipient,
                LXLY_BRIDGE,
                address(0)
            )
        );
        vm.expectRevert("INVALID_MIGRATION_MANAGER");
        yeToken = GenericYeToken(_proxify(yeTokenImplementation, address(this), initData));
        vm.revertToState(stateBeforeInitialize);
    }

    function test_deposit() public {
        uint256 amount = 100;
        uint256 reserveAssets = (amount * minimumReservePercentage) / 100;

        vm.startPrank(owner);
        yeToken.pause();
        vm.expectRevert(EnforcedPause.selector);
        yeToken.deposit(amount, recipient);

        yeToken.unpause();
        vm.stopPrank();

        deal(asset, sender, amount);

        vm.startPrank(sender);
        vm.expectRevert("INVALID_AMOUNT");
        yeToken.deposit(0, recipient);

        vm.expectRevert("INVALID_ADDRESS");
        yeToken.deposit(amount, address(0));

        uint256 sharesToBeMinted = yeToken.previewDeposit(amount);

        IERC20(asset).forceApprove(address(yeToken), amount);
        vm.expectEmit();
        emit Deposit(sender, recipient, amount, sharesToBeMinted);
        yeToken.deposit(amount, recipient);
        vm.stopPrank();

        assertEq(IERC20(asset).balanceOf(address(yeToken)), reserveAssets);
        assertEq(yeToken.balanceOf(recipient), sharesToBeMinted); // shares minted to the recipient
    }

    function test_depositWithPermit() public virtual {
        uint256 amount = 100;
        uint256 reserveAssets = (amount * minimumReservePercentage) / 100;

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
                            PERMIT_TYPEHASH, sender, address(yeToken), amount, vm.getNonce(sender), block.timestamp
                        )
                    )
                )
            )
        );
        bytes memory permitData =
            abi.encodeWithSelector(PERMIT_SIGNATURE, sender, address(yeToken), amount, block.timestamp, v, r, s);

        uint256 sharesToBeMinted = yeToken.previewDeposit(amount);

        vm.startPrank(sender);
        vm.expectEmit();
        emit Deposit(sender, recipient, amount, sharesToBeMinted);
        yeToken.depositWithPermit(amount, recipient, permitData);
        vm.stopPrank();

        assertEq(IERC20(asset).balanceOf(address(yeToken)), reserveAssets);
        assertEq(yeToken.balanceOf(recipient), sharesToBeMinted); // shares minted to the recipient
    }

    function test_depositAndBridge() public {
        uint256 amount = 100;
        uint256 reserveAssets = (amount * minimumReservePercentage) / 100;

        vm.startPrank(owner);
        yeToken.pause();
        vm.expectRevert(EnforcedPause.selector);
        yeToken.depositAndBridge(amount, recipient, NETWORK_ID_L2, true);

        yeToken.unpause();
        vm.stopPrank();

        deal(asset, sender, amount);

        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(yeToken), amount);
        vm.expectEmit();
        emit BridgeEvent(
            LEAF_TYPE_ASSET,
            NETWORK_ID_L1,
            address(yeToken),
            NETWORK_ID_L2,
            recipient,
            amount,
            yeTokenMetaData,
            _ILxLyBridge(LXLY_BRIDGE).depositCount()
        );
        yeToken.depositAndBridge(amount, recipient, NETWORK_ID_L2, true);
        vm.stopPrank();

        assertEq(IERC20(asset).balanceOf(address(yeToken)), reserveAssets);
        assertEq(yeToken.balanceOf(LXLY_BRIDGE), amount); // shares locked on bridge
    }

    function test_depositAndBridgePermit() public virtual {
        uint256 amount = 100;
        uint256 reserveAssets = (amount * minimumReservePercentage) / 100;

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
                            PERMIT_TYPEHASH, sender, address(yeToken), amount, vm.getNonce(sender), block.timestamp
                        )
                    )
                )
            )
        );
        bytes memory permitData =
            abi.encodeWithSelector(PERMIT_SIGNATURE, sender, address(yeToken), amount, block.timestamp, v, r, s);

        vm.startPrank(sender);
        vm.expectEmit();
        emit BridgeEvent(
            LEAF_TYPE_ASSET,
            NETWORK_ID_L1,
            address(yeToken),
            NETWORK_ID_L2,
            recipient,
            amount,
            yeTokenMetaData,
            _ILxLyBridge(LXLY_BRIDGE).depositCount()
        );
        yeToken.depositAndBridgeWithPermit(amount, recipient, NETWORK_ID_L2, true, permitData);
        vm.stopPrank();

        assertEq(IERC20(asset).balanceOf(address(yeToken)), reserveAssets);
        assertEq(yeToken.balanceOf(LXLY_BRIDGE), amount); // shares locked on bridge
    }

    function test_mint() public virtual {
        uint256 amount = 100;
        uint256 reserveAssets = (amount * minimumReservePercentage) / 100;

        vm.startPrank(owner);
        yeToken.pause();
        vm.expectRevert(EnforcedPause.selector);
        yeToken.mint(amount, recipient);

        yeToken.unpause();
        vm.stopPrank();

        deal(asset, sender, amount);
        uint256 sharesToBeMinted = yeToken.previewMint(amount);

        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(yeToken), amount);
        yeToken.mint(amount, sender);
        vm.stopPrank();

        assertEq(IERC20(asset).balanceOf(address(yeToken)), reserveAssets);
        assertEq(yeToken.balanceOf(sender), sharesToBeMinted); // shares minted to the recipient
    }

    function test_withdraw() public virtual {
        uint256 amount = 100;
        uint256 reserveAmount = (amount * minimumReservePercentage) / 100;

        vm.startPrank(owner);
        yeToken.pause();
        vm.expectRevert(EnforcedPause.selector);
        yeToken.withdraw(amount, recipient, owner);
        yeToken.unpause();
        vm.stopPrank();

        deal(asset, sender, amount);

        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(yeToken), amount);
        yeToken.deposit(amount, sender);
        assertEq(IERC20(asset).balanceOf(sender), 0); // make sure sender has deposited all assets
        assertEq(yeToken.balanceOf(sender), amount); // sender gets 100 shares

        vm.expectRevert("AMOUNT_TOO_LARGE");
        yeToken.withdraw(amount + 1, sender, sender);

        uint256 reserveWithdrawAmount = reserveAmount - 1;
        reserveAmount -= reserveWithdrawAmount;
        yeToken.withdraw(reserveWithdrawAmount, sender, sender);
        assertEq(IERC20(asset).balanceOf(address(yeToken)), reserveAmount); // reserve assets reduced
        assertEq(IERC20(asset).balanceOf(sender), reserveWithdrawAmount); // assets returned to sender
        assertEq(yeToken.balanceOf(sender), amount - reserveWithdrawAmount); // shares reduced

        uint256 stakeWithdrawAmount = reserveAmount + 2; // withdraw amount is greater than reserve amount
        yeToken.withdraw(stakeWithdrawAmount, sender, sender);
        assertEq(IERC20(asset).balanceOf(address(yeToken)), 0); // reserve assets remain same
        assertEq(IERC20(asset).balanceOf(sender), reserveWithdrawAmount + stakeWithdrawAmount); // assets returned to sender
        assertEq(yeToken.balanceOf(sender), amount - reserveWithdrawAmount - stakeWithdrawAmount); // shares reduced
        vm.stopPrank();
    }

    function test_replenishReserve() public {
        uint256 amount = 100;
        uint256 reserveAmount = (amount * minimumReservePercentage) / 100;

        vm.expectRevert("NO_NEED_TO_REBALANCE_RESERVE");
        yeToken.replenishReserve();

        deal(asset, sender, amount);
        // create reserve
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(yeToken), amount);
        yeToken.deposit(amount, recipient);
        vm.stopPrank();

        vm.prank(address(yeToken));
        IERC20(asset).safeTransfer(address(0xdeed), reserveAmount - 1); // reduce reserve assets
        vm.expectEmit();
        emit ReserveRebalanced(reserveAmount);
        yeToken.replenishReserve();
        assertEq(IERC20(asset).balanceOf(address(yeToken)), reserveAmount);
    }

    function test_rebalanceReserve() public {
        uint256 amount = 100;
        uint256 reserveAmount = (amount * minimumReservePercentage) / 100;

        deal(asset, sender, amount);

        // create reserve
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(yeToken), amount);
        yeToken.deposit(amount, recipient);
        vm.stopPrank();
        vm.assertEq(IERC20(asset).balanceOf(address(yeToken)), reserveAmount);

        deal(asset, address(yeToken), reserveAmount + amount); // add additional assets to the reserve on top of the reserve

        vm.expectRevert(); // only owner can rebalance reserve
        yeToken.rebalanceReserve();

        vm.expectEmit();
        emit ReserveRebalanced(reserveAmount);
        vm.prank(owner);
        yeToken.rebalanceReserve(); // deposits additional assets to the vault
        assertEq(IERC20(asset).balanceOf(address(yeToken)), reserveAmount);
    }

    function test_collectYield() public {
        vm.expectRevert(); // only owner can claim yield
        yeToken.collectYield();

        vm.expectRevert("NO_YIELD"); // no reserved and staked assets
        vm.prank(owner);
        yeToken.collectYield();

        uint256 amount = 100;

        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(yeToken), amount);
        yeToken.mint(amount, sender);
        vm.stopPrank();

        uint256 sharesBalanceBefore = yeTokenVault.balanceOf(address(yeToken));
        uint256 yieldAssets = 500;
        uint256 yieldShares = yeTokenVault.convertToShares(yieldAssets);

        deal(address(yeTokenVault), address(yeToken), sharesBalanceBefore + yieldShares); // add yield to the vault

        uint256 expectedYieldAssets = yeToken.yield();

        vm.expectEmit();
        emit YieldCollected(yieldRecipient, expectedYieldAssets);
        vm.prank(owner);
        yeToken.collectYield();

        vm.assertEq(yeToken.balanceOf(yieldRecipient), expectedYieldAssets);
    }

    function test_setYieldRecipient_no_yield() public {
        address newRecipient = makeAddr("newRecipient");
        vm.expectRevert(); // only owner can claim yield
        yeToken.changeYieldRecipient(newRecipient);

        vm.expectRevert("INVALID_YIELD_RECIPIENT");
        vm.prank(owner);
        yeToken.changeYieldRecipient(address(0));

        assertEq(yeToken.yieldRecipient(), yieldRecipient);

        vm.expectEmit();
        emit YieldRecipientChanged(newRecipient);
        vm.prank(owner);
        yeToken.changeYieldRecipient(newRecipient);
        assertEq(yeToken.yieldRecipient(), newRecipient);
    }

    function test_setYieldRecipient_with_yield() public {
        address newRecipient = makeAddr("newRecipient");
        uint256 amount = 100;

        // generate yield
        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(yeToken), amount);
        yeToken.mint(amount, sender);
        vm.stopPrank();

        uint256 sharesBalanceBefore = yeTokenVault.balanceOf(address(yeToken));
        uint256 yieldAssets = 500;
        uint256 yieldShares = yeTokenVault.convertToShares(yieldAssets);

        deal(address(yeTokenVault), address(yeToken), sharesBalanceBefore + yieldShares); // add yield to the vault

        uint256 expectedYieldAssets = yeToken.yield();

        assertEq(yeToken.yieldRecipient(), yieldRecipient);

        vm.expectEmit();
        emit YieldCollected(yieldRecipient, expectedYieldAssets);
        vm.prank(owner);
        yeToken.changeYieldRecipient(newRecipient);
        assertEq(yeToken.balanceOf(yieldRecipient), expectedYieldAssets); // yield collected to the old recipient
        assertEq(yeToken.yieldRecipient(), newRecipient);
    }

    function test_setMinimumReservePercentage_no_rebalance() public {
        uint8 percentage = 20;
        vm.expectRevert(); // only owner can set minimum reserve percentage
        yeToken.changeMinimumReservePercentage(percentage);

        vm.expectRevert("INVALID_PERCENTAGE");
        vm.prank(owner);
        yeToken.changeMinimumReservePercentage(101);

        assertEq(yeToken.minimumReservePercentage(), minimumReservePercentage);

        vm.expectEmit();
        emit MinimumReservePercentageChanged(percentage);
        vm.prank(owner);
        yeToken.changeMinimumReservePercentage(percentage);
        assertEq(yeToken.minimumReservePercentage(), percentage);
    }

    function test_setMinimumReservePercentage_with_rebalance() public {
        uint256 amount = 100;
        uint8 percentage = 20;
        uint256 reserveAmount = (amount * minimumReservePercentage) / 100;

        deal(asset, sender, amount);
        // create reserve
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(yeToken), amount);
        yeToken.deposit(amount, recipient);
        vm.stopPrank();
        assertEq(IERC20(asset).balanceOf(address(yeToken)), reserveAmount);

        uint256 stakedAssetsBefore = yeToken.stakedAssets();

        vm.expectEmit();
        emit ReserveRebalanced((amount * percentage) / 100);
        vm.expectEmit();
        emit MinimumReservePercentageChanged(percentage);
        vm.prank(owner);
        yeToken.changeMinimumReservePercentage(percentage);
        assertEq(yeToken.minimumReservePercentage(), percentage);
        assertLt(yeToken.stakedAssets(), stakedAssetsBefore);
    }

    function testFuzz_setMinimumReservePercentage(uint8 percentage) public {
        vm.assume(percentage <= 100);
        vm.prank(owner);
        yeToken.changeMinimumReservePercentage(percentage);
        assertEq(yeToken.minimumReservePercentage(), percentage);
    }

    function test_redeem() public virtual {
        uint256 initialAmount = 100;

        vm.startPrank(owner);
        yeToken.pause();
        vm.expectRevert(EnforcedPause.selector);
        yeToken.redeem(initialAmount, sender, sender);
        yeToken.unpause();
        vm.stopPrank();

        deal(asset, sender, initialAmount);

        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(yeToken), initialAmount);
        yeToken.deposit(initialAmount, sender);
        assertEq(IERC20(asset).balanceOf(sender), 0);
        assertEq(yeToken.balanceOf(sender), initialAmount);

        vm.expectRevert("AMOUNT_TOO_LARGE");
        yeToken.redeem(1000, sender, sender); // redeem amount is greater than total assets

        vm.expectRevert("INVALID_AMOUNT");
        yeToken.redeem(0, sender, sender);

        uint256 redeemAmount = yeToken.totalAssets();

        yeToken.redeem(redeemAmount, sender, sender); // redeem from both staked and reserved assets
        assertEq(IERC20(asset).balanceOf(sender), redeemAmount);
        vm.stopPrank();
    }

    function test_completeMigration_no_discrepancy() public {
        uint256 assets = 100;
        uint256 shares = 100;

        vm.startPrank(owner);
        yeToken.pause();
        vm.expectRevert(EnforcedPause.selector);
        yeToken.completeMigration(NETWORK_ID_L2, shares, assets);
        yeToken.unpause();
        vm.stopPrank();

        vm.expectRevert("UNAUTHORIZED");
        yeToken.completeMigration(NETWORK_ID_L2, shares, assets);

        vm.expectRevert("INVALID_NETWORK_ID");
        vm.prank(migrationManager);
        yeToken.completeMigration(NETWORK_ID_L1, shares, assets);

        vm.expectRevert("INVALID_AMOUNT");
        vm.prank(migrationManager);
        yeToken.completeMigration(NETWORK_ID_L2, 0, assets);

        deal(asset, migrationManager, assets);
        vm.startPrank(migrationManager);
        IERC20(asset).forceApprove(address(yeToken), assets);

        vm.expectEmit();
        emit BridgeEvent(
            LEAF_TYPE_ASSET,
            NETWORK_ID_L1,
            address(yeToken),
            NETWORK_ID_L2,
            address(0),
            shares,
            yeTokenMetaData,
            _ILxLyBridge(LXLY_BRIDGE).depositCount()
        );
        vm.expectEmit();
        emit Deposit(migrationManager, address(yeToken), assets, shares);
        vm.expectEmit();
        emit MigrationCompleted(NETWORK_ID_L2, shares, assets, assets, 0);
        yeToken.completeMigration(NETWORK_ID_L2, shares, assets);
        vm.stopPrank();
    }

    function test_completeMigration_with_discrepancy() public {
        uint256 assets = 100;
        uint256 shares = 110;

        deal(asset, migrationManager, assets);

        vm.startPrank(migrationManager);
        IERC20(asset).forceApprove(address(yeToken), assets);

        vm.expectRevert("INSUFFICIENT_YIELD_TO_COVER_FOR_DISCREPANCY");
        yeToken.completeMigration(NETWORK_ID_L2, shares, assets);
        vm.stopPrank();

        // generate yield
        deal(asset, sender, assets);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(yeToken), assets);
        yeToken.mint(assets, sender);
        vm.stopPrank();

        uint256 sharesBalanceBefore = yeTokenVault.balanceOf(address(yeToken));
        uint256 yieldAssets = 500;
        uint256 yieldShares = yeTokenVault.convertToShares(yieldAssets);
        deal(address(yeTokenVault), address(yeToken), sharesBalanceBefore + yieldShares);

        vm.expectEmit();
        emit BridgeEvent(
            LEAF_TYPE_ASSET,
            NETWORK_ID_L1,
            address(yeToken),
            NETWORK_ID_L2,
            address(0),
            shares,
            yeTokenMetaData,
            _ILxLyBridge(LXLY_BRIDGE).depositCount()
        );
        vm.expectEmit();
        emit Deposit(migrationManager, address(yeToken), assets, shares);
        vm.expectEmit();
        emit MigrationCompleted(NETWORK_ID_L2, shares, assets, assets, shares - assets);
        vm.prank(migrationManager);
        yeToken.completeMigration(NETWORK_ID_L2, shares, assets);
    }

    function test_maxDeposit() public {
        assertEq(yeToken.maxDeposit(address(0)), type(uint256).max);

        vm.prank(owner);
        yeToken.pause();
        assertEq(yeToken.maxDeposit(address(0)), 0);
    }

    function test_previewDeposit() public {
        uint256 amount = 100;
        vm.startPrank(owner);
        yeToken.pause();
        vm.expectRevert(EnforcedPause.selector);
        yeToken.previewDeposit(amount);
        yeToken.unpause();
        vm.stopPrank();

        vm.expectRevert("INVALID_AMOUNT");
        yeToken.previewDeposit(0);

        vm.assertEq(yeToken.previewDeposit(amount), amount);
    }

    function test_maxMint() public virtual {
        assertEq(yeToken.maxMint(address(0)), type(uint256).max);

        vm.prank(owner);
        yeToken.pause();
        assertEq(yeToken.maxMint(address(0)), 0);
    }

    function test_previewMint() public virtual {
        uint256 amount = 100;
        vm.startPrank(owner);
        yeToken.pause();
        vm.expectRevert(EnforcedPause.selector);
        yeToken.previewMint(amount);
        yeToken.unpause();
        vm.stopPrank();

        vm.expectRevert("INVALID_AMOUNT");
        yeToken.previewMint(0);

        vm.assertEq(yeToken.previewMint(amount), amount);
    }

    function test_maxWithdraw() public virtual {
        uint256 amount = 100;
        vm.startPrank(owner);
        yeToken.pause();
        vm.assertEq(yeToken.maxWithdraw(address(0)), 0);
        yeToken.unpause();
        vm.stopPrank();

        assertEq(yeToken.maxWithdraw(address(0)), 0); // 0 if no shares

        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(yeToken), amount);
        yeToken.deposit(amount, sender);
        vm.stopPrank();

        assertEq(yeToken.maxWithdraw(sender), yeToken.totalAssets());
    }

    function test_previewWithdraw() public virtual {
        uint256 amount = 100;
        uint256 reserveAmount = (amount * minimumReservePercentage) / 100;

        vm.startPrank(owner);
        yeToken.pause();
        vm.expectRevert(EnforcedPause.selector);
        yeToken.previewWithdraw(amount);
        yeToken.unpause();
        vm.stopPrank();

        vm.expectRevert("INVALID_AMOUNT");
        yeToken.previewWithdraw(0);

        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(yeToken), amount);
        yeToken.deposit(amount, sender);
        vm.stopPrank();

        vm.expectRevert("AMOUNT_TOO_LARGE");
        yeToken.previewWithdraw(amount + 1);

        uint256 stakedAmount = yeTokenVault.convertToAssets(yeTokenVault.balanceOf(address(yeToken)));

        vm.assertEq(yeToken.previewWithdraw(reserveAmount), yeToken.reservedAssets()); // reserve assets
        vm.assertEq(yeToken.previewWithdraw(reserveAmount + stakedAmount), yeToken.totalAssets()); // reserve + staked assets
    }

    function test_maxRedeem() public virtual {
        vm.startPrank(owner);
        yeToken.pause();
        vm.assertEq(yeToken.maxRedeem(sender), 0);
        yeToken.unpause();
        vm.stopPrank();

        assertEq(yeToken.maxRedeem(sender), 0); // 0 if no shares

        uint256 amount = 100;
        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(yeToken), amount);
        yeToken.deposit(amount, sender);
        vm.stopPrank();

        assertEq(yeToken.maxRedeem(sender), yeToken.totalAssets());
    }

    function test_previewRedeem() public virtual {
        uint256 amount = 100;
        uint256 reserveAmount = (amount * minimumReservePercentage) / 100;
        vm.startPrank(owner);
        yeToken.pause();
        vm.expectRevert(EnforcedPause.selector);
        yeToken.previewRedeem(amount);
        yeToken.unpause();
        vm.stopPrank();

        vm.expectRevert("INVALID_AMOUNT");
        yeToken.previewRedeem(0);

        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(yeToken), amount);
        yeToken.deposit(amount, sender);
        vm.stopPrank();

        vm.expectRevert("AMOUNT_TOO_LARGE");
        yeToken.previewRedeem(amount + 1);

        uint256 stakedAmount = yeTokenVault.convertToAssets(yeTokenVault.balanceOf(address(yeToken)));

        vm.assertEq(yeToken.previewRedeem(reserveAmount), yeToken.reservedAssets()); // reserve assets
        vm.assertEq(yeToken.previewRedeem(reserveAmount + stakedAmount), yeToken.totalAssets()); // reserve + staked assets
    }

    function test_reservePercentage() public {
        uint256 amount = 100;
        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(yeToken), amount);
        yeToken.deposit(amount, sender);
        vm.stopPrank();

        assertEq(yeToken.reservePercentage(), minimumReservePercentage);
    }

    function test_pause_unpause() public {
        vm.expectRevert();
        yeToken.pause();

        vm.expectRevert();
        yeToken.unpause();

        vm.startPrank(owner);
        vm.expectEmit();
        emit Paused(owner);
        yeToken.pause();

        vm.expectEmit();
        emit Unpaused(owner);
        yeToken.unpause();
        vm.stopPrank();
    }

    function test_version() public view {
        assertEq(yeToken.version(), version);
    }

    // //TODO: test claimAndWithdraw

    function test_approve() public {
        assertTrue(yeToken.approve(address(0xBEEF), 1e18));

        assertEq(yeToken.allowance(address(this), address(0xBEEF)), 1e18);
    }

    // ERC20 tests
    function test_transfer() public virtual {
        deal(address(yeToken), address(this), 1e18);

        assertTrue(yeToken.transfer(address(0xBEEF), 1e18));

        assertEq(yeToken.balanceOf(address(this)), 0);
        assertEq(yeToken.balanceOf(address(0xBEEF)), 1e18);
    }

    function test_transferFrom() public virtual {
        address from = address(0xABCD);
        deal(address(yeToken), from, 1e18);

        vm.prank(from);
        yeToken.forceApprove(address(this), 1e18);

        assertTrue(yeToken.transferFrom(from, address(0xBEEF), 1e18));

        assertEq(yeToken.allowance(from, address(this)), 0);

        assertEq(yeToken.balanceOf(from), 0);
        assertEq(yeToken.balanceOf(address(0xBEEF)), 1e18);
    }

    function test_infiniteApproveTransferFrom() public virtual {
        address from = address(0xABCD);
        deal(address(yeToken), from, 1e18);

        vm.prank(from);
        yeToken.forceApprove(address(this), type(uint256).max);

        assertTrue(yeToken.transferFrom(from, address(0xBEEF), 1e18));

        assertEq(yeToken.allowance(from, address(this)), type(uint256).max);

        assertEq(yeToken.balanceOf(from), 0);
        assertEq(yeToken.balanceOf(address(0xBEEF)), 1e18);
    }

    function test_failTransferInsufficientBalance() public {
        deal(address(yeToken), address(this), 0.9e18);
        vm.expectRevert();
        yeToken.transfer(address(0xBEEF), 1e18);
    }

    function test_failTransferFromInsufficientAllowance() public virtual {
        address from = address(0xABCD);

        deal(address(yeToken), address(this), 1e18);

        vm.prank(from);
        yeToken.forceApprove(address(this), 0.9e18);

        vm.expectRevert();
        yeToken.transferFrom(from, address(0xBEEF), 1e18);
    }

    function test_failTransferFromInsufficientBalance() public virtual {
        address from = address(0xABCD);

        deal(address(yeToken), address(this), 0.9e18);

        vm.prank(from);
        yeToken.forceApprove(address(this), 1e18);

        vm.expectRevert();
        yeToken.transferFrom(from, address(0xBEEF), 1e18);
    }

    function test_permit() public virtual {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            senderPrivateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    yeToken.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(PERMIT_TYPEHASH, sender, address(0xCAFE), 1e18, vm.getNonce(sender), block.timestamp)
                    )
                )
            )
        );

        vm.prank(sender);
        yeToken.permit(sender, address(0xCAFE), 1e18, block.timestamp, v, r, s);

        assertEq(yeToken.allowance(sender, address(0xCAFE)), 1e18);
        assertEq(yeToken.nonces(sender), 1);
    }

    function _proxify(address logic, address admin, bytes memory initData) internal returns (address proxy) {
        proxy = address(new TransparentUpgradeableProxy(logic, admin, initData));
    }
}
