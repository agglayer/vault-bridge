// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

import {GenericYeToken} from "src/yield-exposed-tokens/GenericYeToken.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {YieldExposedToken} from "src/YieldExposedToken.sol";

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
    uint256 internal constant MAX_MINIMUM_RESERVE_PERCENTAGE = 1e18;
    bytes32 internal constant RESERVE_ASSET_STORAGE =
        hex"ed23de664e59f2cbf6ba852da776346da171cf53c9d06b116fea0fc5ee912502";

    uint256 stateBeforeInitialize;
    uint256 mainnetFork;
    IMetaMorpho yeTokenVault;
    GenericYeToken yeToken;
    address yeTokenImplementation;
    address asset;

    address nativeConverter = makeAddr("nativeConverter");
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
    uint256 minimumReservePercentage;
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
    event YieldRecipientSet(address indexed yieldRecipient);
    event MinimumReservePercentageSet(uint256 minimumReservePercentage);
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
        minimumReservePercentage = 1e17;

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
                nativeConverter
            )
        );
        yeToken = GenericYeToken(_proxify(address(yeTokenImplementation), address(this), initData));

        vm.label(address(yeTokenVault), "yeToken Vault");
        vm.label(address(yeToken), "yeToken");
        vm.label(address(yeTokenImplementation), "yeToken Implementation");
        vm.label(address(this), "Default Address");
        vm.label(asset, "Underlying Asset");
        vm.label(nativeConverter, "Migration Manager");
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
        assertEq(yeToken.nativeConverter(), nativeConverter);
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
                nativeConverter
            )
        );
        vm.expectRevert(YieldExposedToken.InvalidOwner.selector);
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
                nativeConverter
            )
        );
        vm.expectRevert(YieldExposedToken.InvalidName.selector);
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
                nativeConverter
            )
        );
        vm.expectRevert(YieldExposedToken.InvalidSymbol.selector);
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
                nativeConverter
            )
        );
        vm.expectRevert(YieldExposedToken.InvalidUnderlyingToken.selector);
        yeToken = GenericYeToken(_proxify(yeTokenImplementation, address(this), initData));
        vm.revertToState(stateBeforeInitialize);

        initData = abi.encodeCall(
            yeToken.initialize,
            (owner, name, symbol, asset, 1e19, address(yeTokenVault), yieldRecipient, LXLY_BRIDGE, nativeConverter)
        );
        vm.expectRevert(YieldExposedToken.InvalidMinimumReservePercentage.selector);
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
                nativeConverter
            )
        );
        vm.expectRevert(YieldExposedToken.InvalidYieldVault.selector);
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
                nativeConverter
            )
        );
        vm.expectRevert(YieldExposedToken.InvalidYieldRecipient.selector);
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
                nativeConverter
            )
        );
        vm.expectRevert(YieldExposedToken.InvalidLxLyBridge.selector);
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
        vm.expectRevert(YieldExposedToken.InvalidNativeConverter.selector);
        yeToken = GenericYeToken(_proxify(yeTokenImplementation, address(this), initData));
        vm.revertToState(stateBeforeInitialize);
    }

    function test_deposit() public {
        uint256 amount = 100 ether;
        uint256 vaultMaxDeposit = yeTokenVault.maxDeposit(address(yeToken));
        uint256 reserveAssets = (amount * minimumReservePercentage) / MAX_MINIMUM_RESERVE_PERCENTAGE;

        vm.startPrank(owner);
        yeToken.pause();
        vm.expectRevert(EnforcedPause.selector);
        yeToken.deposit(amount, recipient);

        yeToken.unpause();
        vm.stopPrank();

        deal(asset, sender, amount);

        vm.expectRevert(YieldExposedToken.InvalidReceiver.selector);
        vm.prank(address(yeToken));
        yeToken.deposit(amount, address(0));

        vm.startPrank(sender);
        vm.expectRevert(YieldExposedToken.InvalidAssets.selector);
        yeToken.deposit(0, recipient);

        vm.expectRevert(YieldExposedToken.InvalidReceiver.selector);
        yeToken.deposit(amount, address(0));

        uint256 sharesToBeMinted = yeToken.previewDeposit(amount);

        IERC20(asset).forceApprove(address(yeToken), amount);
        vm.expectEmit();
        emit Deposit(sender, recipient, amount, sharesToBeMinted);
        yeToken.deposit(amount, recipient);
        vm.stopPrank();

        uint256 assetsToDeposit = amount - reserveAssets;
        uint256 assetsToDepositMax = (assetsToDeposit > vaultMaxDeposit) ? vaultMaxDeposit : assetsToDeposit;
        uint256 reserveAssetsAfterDeposit = amount - assetsToDepositMax;

        assertEq(IERC20(asset).balanceOf(address(yeToken)), reserveAssetsAfterDeposit); // reserve assets increased
        assertEq(yeToken.balanceOf(recipient), sharesToBeMinted); // shares minted to the recipient
    }

    function test_depositWithPermit() public virtual {
        uint256 amount = 100 ether;
        uint256 vaultMaxDeposit = yeTokenVault.maxDeposit(address(yeToken));
        uint256 reserveAssets = (amount * minimumReservePercentage) / MAX_MINIMUM_RESERVE_PERCENTAGE;

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

        uint256 assetsToDeposit = amount - reserveAssets;
        uint256 assetsToDepositMax = (assetsToDeposit > vaultMaxDeposit) ? vaultMaxDeposit : assetsToDeposit;
        uint256 reserveAssetsAfterDeposit = amount - assetsToDepositMax;

        assertEq(IERC20(asset).balanceOf(address(yeToken)), reserveAssetsAfterDeposit); // reserve assets increased
        assertEq(yeToken.balanceOf(recipient), sharesToBeMinted); // shares minted to the recipient
    }

    function test_depositAndBridge() public {
        uint256 amount = 100 ether;
        uint256 vaultMaxDeposit = yeTokenVault.maxDeposit(address(yeToken));
        uint256 reserveAssets = (amount * minimumReservePercentage) / MAX_MINIMUM_RESERVE_PERCENTAGE;

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

        uint256 assetsToDeposit = amount - reserveAssets;
        uint256 assetsToDepositMax = (assetsToDeposit > vaultMaxDeposit) ? vaultMaxDeposit : assetsToDeposit;
        uint256 reserveAssetsAfterDeposit = amount - assetsToDepositMax;

        assertEq(IERC20(asset).balanceOf(address(yeToken)), reserveAssetsAfterDeposit); // reserve assets increased
        assertEq(yeToken.balanceOf(LXLY_BRIDGE), amount); // shares locked on bridge
    }

    function test_depositAndBridgePermit() public virtual {
        uint256 amount = 100 ether;
        uint256 vaultMaxDeposit = yeTokenVault.maxDeposit(address(yeToken));
        uint256 reserveAssets = (amount * minimumReservePercentage) / MAX_MINIMUM_RESERVE_PERCENTAGE;

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
        yeToken.depositWithPermitAndBridge(amount, recipient, NETWORK_ID_L2, true, permitData);
        vm.stopPrank();

        uint256 assetsToDeposit = amount - reserveAssets;
        uint256 assetsToDepositMax = (assetsToDeposit > vaultMaxDeposit) ? vaultMaxDeposit : assetsToDeposit;
        uint256 reserveAssetsAfterDeposit = amount - assetsToDepositMax;

        assertEq(IERC20(asset).balanceOf(address(yeToken)), reserveAssetsAfterDeposit);
        assertEq(yeToken.balanceOf(LXLY_BRIDGE), amount); // shares locked on bridge
    }

    function test_mint() public virtual {
        uint256 amount = 100 ether;
        uint256 vaultMaxDeposit = yeTokenVault.maxDeposit(address(yeToken));
        uint256 reserveAssets = (amount * minimumReservePercentage) / MAX_MINIMUM_RESERVE_PERCENTAGE;

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

        uint256 assetsToDeposit = amount - reserveAssets;
        uint256 assetsToDepositMax = (assetsToDeposit > vaultMaxDeposit) ? vaultMaxDeposit : assetsToDeposit;
        uint256 reserveAssetsAfterDeposit = amount - assetsToDepositMax;

        assertEq(IERC20(asset).balanceOf(address(yeToken)), reserveAssetsAfterDeposit);
        assertEq(yeToken.balanceOf(sender), sharesToBeMinted); // shares minted to the recipient
    }

    function test_withdraw() public virtual {
        uint256 amount = 100 ether;
        uint256 vaultMaxDeposit = yeTokenVault.maxDeposit(address(yeToken));
        uint256 reserveAmount = (amount * minimumReservePercentage) / MAX_MINIMUM_RESERVE_PERCENTAGE;

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

        vm.expectRevert(
            abi.encodeWithSelector(YieldExposedToken.AssetsTooLarge.selector, yeToken.totalAssets(), amount + 1)
        );
        yeToken.withdraw(amount + 1, sender, sender);

        uint256 assetsToDeposit = amount - reserveAmount;
        uint256 assetsToDepositMax = (assetsToDeposit > vaultMaxDeposit) ? vaultMaxDeposit : assetsToDeposit;
        uint256 reserveAssetsAfterDeposit = amount - assetsToDepositMax;

        uint256 reserveWithdrawAmount = (reserveAssetsAfterDeposit * 90) / 100; // withdraw 90% of reserve assets
        uint256 reserveAfterWithdraw = reserveAssetsAfterDeposit - reserveWithdrawAmount;
        yeToken.withdraw(reserveWithdrawAmount, sender, sender);
        assertEq(IERC20(asset).balanceOf(address(yeToken)), reserveAfterWithdraw); // reserve assets reduced
        assertEq(IERC20(asset).balanceOf(sender), reserveWithdrawAmount); // assets returned to sender
        assertEq(yeToken.balanceOf(sender), amount - reserveWithdrawAmount); // shares reduced

        uint256 stakeWithdrawAmount = reserveAfterWithdraw + ((assetsToDepositMax * 20) / 100); // withdraw amount is greater than reserve amount
        yeToken.withdraw(stakeWithdrawAmount, sender, sender);
        assertEq(IERC20(asset).balanceOf(address(yeToken)), 0); // reserve assets remain same
        assertEq(IERC20(asset).balanceOf(sender), reserveWithdrawAmount + stakeWithdrawAmount); // assets returned to sender
        assertEq(yeToken.balanceOf(sender), amount - reserveWithdrawAmount - stakeWithdrawAmount); // shares reduced
        vm.stopPrank();
    }

    function test_replenishReserve() public {
        uint256 amount = 100 ether;
        uint256 vaultMaxDeposit = yeTokenVault.maxDeposit(address(yeToken));
        uint256 userDepositAmount = amount;

        if (userDepositAmount > vaultMaxDeposit) {
            userDepositAmount = vaultMaxDeposit;
        }

        vm.expectRevert(YieldExposedToken.NoNeedToReplenishReserve.selector);
        yeToken.replenishReserve();

        // create reserve
        deal(asset, sender, userDepositAmount);

        vm.startPrank(sender);

        IERC20(asset).forceApprove(address(yeToken), userDepositAmount);
        yeToken.deposit(userDepositAmount, recipient);

        vm.stopPrank();

        uint256 reserveAmount = (userDepositAmount * minimumReservePercentage) / MAX_MINIMUM_RESERVE_PERCENTAGE;
        uint256 stakedAmountBefore = yeToken.stakedAssets();

        vm.prank(address(yeToken));
        IERC20(asset).safeTransfer(address(0xdeed), 1); // reduce reserve assets
        vm.store(address(yeToken), RESERVE_ASSET_STORAGE, bytes32(uint256(reserveAmount - 1)));

        vm.expectEmit();
        emit ReserveRebalanced(reserveAmount);
        yeToken.replenishReserve();
        assertEq(IERC20(asset).balanceOf(address(yeToken)), reserveAmount);
        assertLt(yeToken.stakedAssets(), stakedAmountBefore);
    }

    function test_rebalanceReserve() public {
        vm.expectRevert(); // only owner can rebalance reserve
        yeToken.rebalanceReserve();

        uint256 amount = 100 ether;
        uint256 vaultMaxDeposit = yeTokenVault.maxDeposit(address(yeToken));
        uint256 userDepositAmount = amount;
        uint256 totalSupply;
        deal(asset, sender, amount); // fund the sender

        if (userDepositAmount > vaultMaxDeposit) {
            userDepositAmount = vaultMaxDeposit / 2; // deposit half of the max deposit limit
            uint256 reserveAmount = (userDepositAmount) * minimumReservePercentage / MAX_MINIMUM_RESERVE_PERCENTAGE;

            // create reserve
            vm.startPrank(sender);

            IERC20(asset).forceApprove(address(yeToken), amount);
            yeToken.deposit(userDepositAmount, recipient);
            totalSupply += userDepositAmount;
            assertEq(yeToken.reservedAssets(), reserveAmount);

            uint256 stakedAssetsBefore = yeToken.stakedAssets();

            // offset the reserve by reducing the reserve assets
            vm.store(address(yeToken), RESERVE_ASSET_STORAGE, bytes32(uint256(reserveAmount - 1)));

            vm.stopPrank();

            uint256 finalReserveAmount = totalSupply * minimumReservePercentage / MAX_MINIMUM_RESERVE_PERCENTAGE;
            vm.prank(owner);
            vm.expectEmit();
            emit ReserveRebalanced(finalReserveAmount);
            yeToken.rebalanceReserve();

            assertEq(yeToken.reservedAssets(), finalReserveAmount);
            assertLt(yeToken.stakedAssets(), stakedAssetsBefore);
        } else {
            uint256 reserveAmount = (userDepositAmount * minimumReservePercentage) / MAX_MINIMUM_RESERVE_PERCENTAGE;

            vm.startPrank(sender);

            IERC20(asset).forceApprove(address(yeToken), amount);
            yeToken.deposit(userDepositAmount, recipient);
            totalSupply += userDepositAmount;
            assertEq(yeToken.reservedAssets(), reserveAmount);

            uint256 stakedAssetsBefore = yeToken.stakedAssets();
            uint256 reservedAssetsBefore = yeToken.reservedAssets();

            // offset the reserve by adding more shares
            deal(asset, address(yeToken), reservedAssetsBefore + amount);
            vm.store(address(yeToken), RESERVE_ASSET_STORAGE, bytes32(uint256(reservedAssetsBefore + amount)));

            vm.stopPrank();

            vm.prank(owner);
            vm.expectEmit();
            emit ReserveRebalanced(reservedAssetsBefore);
            yeToken.rebalanceReserve();

            assertEq(yeToken.reservedAssets(), reservedAssetsBefore);
            assertGt(yeToken.stakedAssets(), stakedAssetsBefore);
        }
    }

    function test_collectYield() public {
        vm.expectRevert(); // only owner can claim yield
        yeToken.collectYield();

        vm.expectRevert(YieldExposedToken.NoYield.selector); // no reserved and staked assets
        vm.prank(owner);
        yeToken.collectYield();

        uint256 amount = 100 ether;
        uint256 yieldInAssets = 500 ether;

        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(yeToken), amount);
        yeToken.mint(amount, sender);
        vm.stopPrank();

        uint256 sharesBalanceBefore = yeTokenVault.balanceOf(address(yeToken));
        uint256 yieldShares = yeTokenVault.convertToShares(yieldInAssets);

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
        yeToken.setYieldRecipient(newRecipient);

        vm.expectRevert(YieldExposedToken.InvalidYieldRecipient.selector);
        vm.prank(owner);
        yeToken.setYieldRecipient(address(0));

        assertEq(yeToken.yieldRecipient(), yieldRecipient);

        vm.expectEmit();
        emit YieldRecipientSet(newRecipient);
        vm.prank(owner);
        yeToken.setYieldRecipient(newRecipient);
        assertEq(yeToken.yieldRecipient(), newRecipient);
    }

    function test_setYieldRecipient_with_yield() public {
        uint256 amount = 100 ether;
        uint256 yieldInAssets = 500 ether;
        address newRecipient = makeAddr("newRecipient");

        // generate yield
        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(yeToken), amount);
        yeToken.mint(amount, sender);
        vm.stopPrank();

        uint256 sharesBalanceBefore = yeTokenVault.balanceOf(address(yeToken));
        uint256 yieldShares = yeTokenVault.convertToShares(yieldInAssets);

        deal(address(yeTokenVault), address(yeToken), sharesBalanceBefore + yieldShares); // add yield to the vault

        uint256 expectedYieldAssets = yeToken.yield();

        assertEq(yeToken.yieldRecipient(), yieldRecipient);

        vm.expectEmit();
        emit YieldCollected(yieldRecipient, expectedYieldAssets);
        vm.prank(owner);
        yeToken.setYieldRecipient(newRecipient);
        assertEq(yeToken.balanceOf(yieldRecipient), expectedYieldAssets); // yield collected to the old recipient
        assertEq(yeToken.yieldRecipient(), newRecipient);
    }

    function test_setMinimumReservePercentage_no_rebalance() public {
        uint256 newPercentage = 2e17;
        vm.expectRevert(); // only owner can set minimum reserve percentage
        yeToken.setMinimumReservePercentage(newPercentage);

        vm.expectRevert(YieldExposedToken.InvalidMinimumReservePercentage.selector);
        vm.prank(owner);
        yeToken.setMinimumReservePercentage(MAX_MINIMUM_RESERVE_PERCENTAGE + 1);

        assertEq(yeToken.minimumReservePercentage(), minimumReservePercentage); // sanity check

        vm.expectEmit();
        emit MinimumReservePercentageSet(newPercentage);
        vm.prank(owner);
        yeToken.setMinimumReservePercentage(newPercentage);
        assertEq(yeToken.minimumReservePercentage(), newPercentage);
    }

    function test_setMinimumReservePercentage_with_rebalance() public {
        uint256 amount = 100 ether;
        uint256 newPercentage = 2e17;
        uint256 maxVaultDeposit = yeTokenVault.maxDeposit(address(yeToken));
        uint256 userDepositAmount = amount;

        if (userDepositAmount > maxVaultDeposit) {
            userDepositAmount = maxVaultDeposit / 2;
        }

        // create reserve
        deal(asset, sender, userDepositAmount);

        vm.startPrank(sender);

        IERC20(asset).forceApprove(address(yeToken), userDepositAmount);
        yeToken.deposit(userDepositAmount, recipient);

        vm.stopPrank();

        uint256 reserveAmount = (userDepositAmount * minimumReservePercentage) / MAX_MINIMUM_RESERVE_PERCENTAGE;
        assertEq(yeToken.reservedAssets(), reserveAmount);

        uint256 finalReserveAmount = (userDepositAmount * newPercentage) / MAX_MINIMUM_RESERVE_PERCENTAGE;
        uint256 stakedAssetsBefore = yeToken.stakedAssets();

        vm.expectEmit();
        emit ReserveRebalanced(finalReserveAmount);
        vm.expectEmit();
        emit MinimumReservePercentageSet(newPercentage);
        vm.prank(owner);
        yeToken.setMinimumReservePercentage(newPercentage);

        assertEq(yeToken.minimumReservePercentage(), newPercentage);
        assertEq(yeToken.reservedAssets(), finalReserveAmount);
        assertLt(yeToken.stakedAssets(), stakedAssetsBefore);
    }

    function testFuzz_setMinimumReservePercentage(uint256 percentage) public {
        vm.assume(percentage <= MAX_MINIMUM_RESERVE_PERCENTAGE);
        vm.prank(owner);
        yeToken.setMinimumReservePercentage(percentage);
        assertEq(yeToken.minimumReservePercentage(), percentage);
    }

    function test_redeem() public virtual {
        uint256 amount = 100 ether;

        vm.startPrank(owner);
        yeToken.pause();
        vm.expectRevert(EnforcedPause.selector);
        yeToken.redeem(amount, sender, sender);
        yeToken.unpause();
        vm.stopPrank();

        deal(asset, sender, amount);

        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(yeToken), amount);
        yeToken.deposit(amount, sender);
        assertEq(IERC20(asset).balanceOf(sender), 0);
        assertEq(yeToken.balanceOf(sender), amount);

        vm.expectRevert(
            abi.encodeWithSelector(YieldExposedToken.AssetsTooLarge.selector, yeToken.totalAssets(), 1000 ether)
        );
        yeToken.redeem(1000 ether, sender, sender); // redeem amount is greater than total assets

        vm.expectRevert(YieldExposedToken.InvalidShares.selector);
        yeToken.redeem(0, sender, sender);

        uint256 redeemAmount = yeToken.totalAssets();

        yeToken.redeem(redeemAmount, sender, sender); // redeem from both staked and reserved assets
        assertEq(IERC20(asset).balanceOf(sender), redeemAmount);
        vm.stopPrank();
    }

    function test_onMessageReceived_no_discrepancy() public {
        uint256 amount = 100 ether;
        uint256 shares = 100 ether;

        // make sure the amount is less than the max deposit limit
        uint256 vaultMaxDeposit = yeTokenVault.maxDeposit(address(yeToken));
        if (amount > vaultMaxDeposit) {
            amount = vaultMaxDeposit / 2;
            shares = vaultMaxDeposit / 2;
        }

        bytes memory data =
            abi.encode(YieldExposedToken.CrossNetworkInstruction.COMPLETE_MIGRATION, abi.encode(shares, amount));

        vm.startPrank(owner);
        yeToken.pause();
        vm.expectRevert(EnforcedPause.selector);
        yeToken.onMessageReceived(nativeConverter, NETWORK_ID_L2, data);
        yeToken.unpause();
        vm.stopPrank();

        vm.expectRevert(YieldExposedToken.Unauthorized.selector);
        yeToken.onMessageReceived(nativeConverter, NETWORK_ID_L2, data);

        vm.expectRevert(YieldExposedToken.Unauthorized.selector);
        vm.prank(LXLY_BRIDGE);
        yeToken.onMessageReceived(address(0), NETWORK_ID_L2, data);

        vm.expectRevert(YieldExposedToken.InvalidOriginNetworkId.selector);
        vm.prank(LXLY_BRIDGE);
        yeToken.onMessageReceived(nativeConverter, NETWORK_ID_L1, data);

        bytes memory invalidSharesData =
            abi.encode(YieldExposedToken.CrossNetworkInstruction.COMPLETE_MIGRATION, abi.encode(0, amount));

        vm.expectRevert(YieldExposedToken.InvalidShares.selector);
        vm.prank(LXLY_BRIDGE);
        yeToken.onMessageReceived(nativeConverter, NETWORK_ID_L2, invalidSharesData);

        deal(asset, address(yeToken), amount);

        uint256 stakedAssetsBefore = yeToken.stakedAssets();

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
        emit Deposit(LXLY_BRIDGE, address(yeToken), amount, shares);
        vm.expectEmit();
        emit MigrationCompleted(NETWORK_ID_L2, shares, amount, amount, 0);
        vm.prank(LXLY_BRIDGE);
        yeToken.onMessageReceived(nativeConverter, NETWORK_ID_L2, data);

        assertEq(
            yeToken.reservedAssets(),
            yeToken.convertToAssets(shares) * minimumReservePercentage / MAX_MINIMUM_RESERVE_PERCENTAGE
        );
        assertGt(yeToken.stakedAssets(), stakedAssetsBefore);
    }

    function test_onMessageReceived_with_discrepancy() public {
        uint256 amount = 100 ether;
        uint256 shares = 110 ether;
        uint256 yieldInAssets = 20 ether;

        // make sure the amount is less than the max deposit limit
        uint256 vaultMaxDeposit = yeTokenVault.maxDeposit(address(yeToken));
        if (amount > vaultMaxDeposit) {
            amount = vaultMaxDeposit / 2;
            shares = (vaultMaxDeposit / 2) + 10;
            yieldInAssets = vaultMaxDeposit;
        }

        bytes memory data =
            abi.encode(YieldExposedToken.CrossNetworkInstruction.COMPLETE_MIGRATION, abi.encode(shares, amount));

        vm.expectRevert(abi.encodeWithSelector(YieldExposedToken.CannotCompleteMigration.selector, shares, amount, 0));
        vm.prank(LXLY_BRIDGE);
        yeToken.onMessageReceived(nativeConverter, NETWORK_ID_L2, data);

        uint256 sharesBalanceBefore = yeTokenVault.balanceOf(address(yeToken));
        uint256 yieldShares = yeTokenVault.convertToShares(yieldInAssets);

        deal(address(yeTokenVault), address(yeToken), sharesBalanceBefore + yieldShares); // add yield to the vault
        deal(asset, address(yeToken), amount);

        uint256 stakedAssetsBefore = yeToken.stakedAssets();

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
        emit Deposit(LXLY_BRIDGE, address(yeToken), amount, shares);
        vm.expectEmit();
        emit MigrationCompleted(NETWORK_ID_L2, shares, amount, amount, shares - amount);
        vm.prank(LXLY_BRIDGE);
        yeToken.onMessageReceived(nativeConverter, NETWORK_ID_L2, data);

        assertEq(
            yeToken.reservedAssets(),
            yeToken.convertToAssets(shares) * minimumReservePercentage / MAX_MINIMUM_RESERVE_PERCENTAGE
        );
        assertGt(yeToken.stakedAssets(), stakedAssetsBefore);
    }

    function test_maxDeposit() public {
        assertEq(yeToken.maxDeposit(address(0)), type(uint256).max);

        vm.prank(owner);
        yeToken.pause();
        assertEq(yeToken.maxDeposit(address(0)), 0);
    }

    function test_previewDeposit() public {
        uint256 amount = 100 ether;

        vm.startPrank(owner);
        yeToken.pause();
        vm.expectRevert(EnforcedPause.selector);
        yeToken.previewDeposit(amount);
        yeToken.unpause();
        vm.stopPrank();

        vm.expectRevert(YieldExposedToken.InvalidAssets.selector);
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
        uint256 amount = 100 ether;

        vm.startPrank(owner);
        yeToken.pause();
        vm.expectRevert(EnforcedPause.selector);
        yeToken.previewMint(amount);
        yeToken.unpause();
        vm.stopPrank();

        vm.expectRevert(YieldExposedToken.InvalidShares.selector);
        yeToken.previewMint(0);

        vm.assertEq(yeToken.previewMint(amount), amount);
    }

    function test_maxWithdraw() public virtual {
        uint256 amount = 100 ether;

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
        uint256 amount = 100 ether;
        uint256 vaultMaxDeposit = yeTokenVault.maxDeposit(address(yeToken));
        uint256 reserveAmount = (amount * minimumReservePercentage) / MAX_MINIMUM_RESERVE_PERCENTAGE;

        vm.startPrank(owner);
        yeToken.pause();
        vm.expectRevert(EnforcedPause.selector);
        yeToken.previewWithdraw(amount);
        yeToken.unpause();
        vm.stopPrank();

        vm.expectRevert(YieldExposedToken.InvalidAssets.selector);
        yeToken.previewWithdraw(0);

        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(yeToken), amount);
        yeToken.deposit(amount, sender);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(YieldExposedToken.AssetsTooLarge.selector, yeToken.totalAssets(), amount + 1)
        );
        yeToken.previewWithdraw(amount + 1);

        uint256 stakedAmount = yeTokenVault.convertToAssets(yeTokenVault.balanceOf(address(yeToken)));
        uint256 assetsToDeposit = amount - reserveAmount;
        uint256 assetsToDepositMax = (assetsToDeposit > vaultMaxDeposit) ? vaultMaxDeposit : assetsToDeposit;
        uint256 reserveAssetsAfterDeposit = amount - assetsToDepositMax;

        vm.assertEq(yeToken.previewWithdraw(reserveAssetsAfterDeposit), yeToken.reservedAssets()); // reserve assets
        vm.assertEq(yeToken.previewWithdraw(reserveAssetsAfterDeposit + stakedAmount), yeToken.totalAssets()); // reserve + staked assets
    }

    function test_maxRedeem() public virtual {
        uint256 amount = 100 ether;

        vm.startPrank(owner);
        yeToken.pause();
        vm.assertEq(yeToken.maxRedeem(sender), 0);
        yeToken.unpause();
        vm.stopPrank();

        assertEq(yeToken.maxRedeem(sender), 0); // 0 if no shares

        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(yeToken), amount);
        yeToken.deposit(amount, sender);
        vm.stopPrank();

        assertEq(yeToken.maxRedeem(sender), yeToken.totalAssets());
    }

    function test_previewRedeem() public virtual {
        uint256 amount = 100 ether;
        uint256 vaultMaxDeposit = yeTokenVault.maxDeposit(address(yeToken));
        uint256 reserveAmount = (amount * minimumReservePercentage) / MAX_MINIMUM_RESERVE_PERCENTAGE;

        vm.startPrank(owner);
        yeToken.pause();
        vm.expectRevert(EnforcedPause.selector);
        yeToken.previewRedeem(amount);
        yeToken.unpause();
        vm.stopPrank();

        vm.expectRevert(YieldExposedToken.InvalidShares.selector);
        yeToken.previewRedeem(0);

        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(yeToken), amount);
        yeToken.deposit(amount, sender);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(YieldExposedToken.AssetsTooLarge.selector, yeToken.totalAssets(), amount + 1)
        );
        yeToken.previewRedeem(amount + 1);

        uint256 stakedAmount = yeTokenVault.convertToAssets(yeTokenVault.balanceOf(address(yeToken)));
        uint256 assetsToDeposit = amount - reserveAmount;
        uint256 assetsToDepositMax = (assetsToDeposit > vaultMaxDeposit) ? vaultMaxDeposit : assetsToDeposit;
        uint256 reserveAssetsAfterDeposit = amount - assetsToDepositMax;

        vm.assertEq(yeToken.previewRedeem(reserveAssetsAfterDeposit), yeToken.reservedAssets()); // reserve assets
        vm.assertEq(yeToken.previewRedeem(reserveAssetsAfterDeposit + stakedAmount), yeToken.totalAssets()); // reserve + staked assets
    }

    function test_reservePercentage() public {
        uint256 amount = 100 ether;
        uint256 vaultMaxDeposit = yeTokenVault.maxDeposit(address(yeToken));
        uint256 reserveAmount = (amount * minimumReservePercentage) / MAX_MINIMUM_RESERVE_PERCENTAGE;

        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(yeToken), amount);
        yeToken.deposit(amount, sender);
        vm.stopPrank();

        uint256 assetsToDeposit = amount - reserveAmount;
        uint256 assetsToDepositMax = (assetsToDeposit > vaultMaxDeposit) ? vaultMaxDeposit : assetsToDeposit;
        uint256 reserveAssetsAfterDeposit = amount - assetsToDepositMax;

        uint256 expectedPercentage =
            (reserveAssetsAfterDeposit * MAX_MINIMUM_RESERVE_PERCENTAGE) / yeToken.totalSupply();

        assertEq(yeToken.reservePercentage(), expectedPercentage);
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
