// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

import {GenericVbToken} from "src/vault-bridge-tokens/GenericVbToken.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {
    VaultBridgeToken, PausableUpgradeable, OwnableUpgradeable, NativeConverterInfo, Initializable
} from "src/VaultBridgeToken.sol";
import {VaultBridgeTokenInitializer} from "src/VaultBridgeTokenInitializer.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IMetaMorpho} from "test/interfaces/IMetaMorpho.sol";
import {ILxLyBridge as _ILxLyBridge} from "test/interfaces/ILxLyBridge.sol";

contract GenericVaultBridgeTokenTest is Test {
    using SafeERC20 for IERC20;
    using SafeERC20 for GenericVbToken;

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
    uint256 internal constant MINIMUM_YIELD_VAULT_DEPOSIT = 1e12;
    bytes32 internal constant RESERVE_ASSET_STORAGE =
        hex"ed23de664e59f2cbf6ba852da776346da171cf53c9d06b116fea0fc5ee912502";

    uint256 stateBeforeInitialize;
    uint256 mainnetFork;
    IMetaMorpho vbTokenVault;
    GenericVbToken vbToken;
    address vbTokenImplementation;
    address asset;

    address nativeConverterAddress = makeAddr("nativeConverter");
    NativeConverterInfo[] nativeConverter =
        [NativeConverterInfo({layerYLxlyId: NETWORK_ID_L2, nativeConverter: nativeConverterAddress})];

    address recipient = makeAddr("recipient");
    address owner = makeAddr("owner");
    address yieldRecipient = makeAddr("yieldRecipient");
    uint256 senderPrivateKey = 0xBEEF;
    address sender = vm.addr(senderPrivateKey);

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
        vbTokenVault = IMetaMorpho(TEST_TOKEN_VAULT);
        version = "1.0.0";
        name = "Vault Bridge USDC";
        symbol = "vbUSDC";
        decimals = 6;
        vbTokenMetaData = abi.encode(name, symbol, decimals);
        minimumReservePercentage = 1e17;
        initializer = address(new VaultBridgeTokenInitializer());

        vbToken = new GenericVbToken();
        vbTokenImplementation = address(vbToken);
        stateBeforeInitialize = vm.snapshotState();
        bytes memory initData = abi.encodeCall(
            vbToken.initialize,
            (
                owner,
                name,
                symbol,
                asset,
                minimumReservePercentage,
                address(vbTokenVault),
                yieldRecipient,
                LXLY_BRIDGE,
                nativeConverter,
                MINIMUM_YIELD_VAULT_DEPOSIT,
                address(0),
                initializer
            )
        );
        vbToken = GenericVbToken(_proxify(address(vbTokenImplementation), address(this), initData));

        vm.label(address(vbTokenVault), "vbToken Vault");
        vm.label(address(vbToken), "vbToken");
        vm.label(address(vbTokenImplementation), "vbToken Implementation");
        vm.label(address(this), "Default Address");
        vm.label(asset, "Underlying Asset");
        vm.label(nativeConverterAddress, "Migration Manager");
        vm.label(owner, "Owner");
        vm.label(recipient, "Recipient");
        vm.label(sender, "Sender");
        vm.label(yieldRecipient, "Yield Recipient");
        vm.label(LXLY_BRIDGE, "Lxly Bridge");
    }

    function test_setup() public view {
        assertEq(vbToken.owner(), owner);
        assertEq(vbToken.name(), name);
        assertEq(vbToken.symbol(), symbol);
        assertEq(vbToken.decimals(), decimals);
        assertEq(vbToken.asset(), asset);
        assertEq(vbToken.minimumReservePercentage(), minimumReservePercentage);
        assertEq(address(vbToken.yieldVault()), address(vbTokenVault));
        assertEq(vbToken.yieldRecipient(), yieldRecipient);
        assertEq(vbToken.nativeConverters(NETWORK_ID_L2), nativeConverterAddress);
        assertEq(address(vbToken.lxlyBridge()), LXLY_BRIDGE);
        assertEq(vbToken.allowance(address(vbToken), LXLY_BRIDGE), type(uint256).max);
        assertEq(IERC20(asset).allowance(address(vbToken), address(vbToken.yieldVault())), type(uint256).max);
    }

    function test_initialize_twice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        vbToken.initialize(owner,
                name,
                symbol,
                asset,
                minimumReservePercentage,
                address(vbTokenVault),
                yieldRecipient,
                LXLY_BRIDGE,
                nativeConverter,
                MINIMUM_YIELD_VAULT_DEPOSIT,
                address(0),
                initializer);
    }

    function test_initialize() public virtual {
        vm.revertToState(stateBeforeInitialize);

        bytes memory initData;

        initData = abi.encodeCall(
            vbToken.initialize,
            (
                address(0),
                name,
                symbol,
                asset,
                minimumReservePercentage,
                address(vbTokenVault),
                yieldRecipient,
                LXLY_BRIDGE,
                nativeConverter,
                MINIMUM_YIELD_VAULT_DEPOSIT,
                address(0),
                initializer
            )
        );
        vm.expectRevert(VaultBridgeToken.InvalidOwner.selector);
        vbToken = GenericVbToken(_proxify(vbTokenImplementation, address(this), initData));
        vm.revertToState(stateBeforeInitialize);

        initData = abi.encodeCall(
            vbToken.initialize,
            (
                owner,
                "",
                symbol,
                asset,
                minimumReservePercentage,
                address(vbTokenVault),
                yieldRecipient,
                LXLY_BRIDGE,
                nativeConverter,
                MINIMUM_YIELD_VAULT_DEPOSIT,
                address(0),
                initializer
            )
        );
        vm.expectRevert(VaultBridgeToken.InvalidName.selector);
        vbToken = GenericVbToken(_proxify(vbTokenImplementation, address(this), initData));
        vm.revertToState(stateBeforeInitialize);

        initData = abi.encodeCall(
            vbToken.initialize,
            (
                owner,
                name,
                "",
                asset,
                minimumReservePercentage,
                address(vbTokenVault),
                yieldRecipient,
                LXLY_BRIDGE,
                nativeConverter,
                MINIMUM_YIELD_VAULT_DEPOSIT,
                address(0),
                initializer
            )
        );
        vm.expectRevert(VaultBridgeToken.InvalidSymbol.selector);
        vbToken = GenericVbToken(_proxify(vbTokenImplementation, address(this), initData));
        vm.revertToState(stateBeforeInitialize);

        initData = abi.encodeCall(
            vbToken.initialize,
            (
                owner,
                name,
                symbol,
                address(0),
                minimumReservePercentage,
                address(vbTokenVault),
                yieldRecipient,
                LXLY_BRIDGE,
                nativeConverter,
                MINIMUM_YIELD_VAULT_DEPOSIT,
                address(0),
                initializer
            )
        );
        /// forge-config: default.allow_internal_expect_revert = true
        vm.expectRevert(VaultBridgeToken.InvalidUnderlyingToken.selector);
        vbToken = GenericVbToken(_proxify(vbTokenImplementation, address(this), initData));
        vm.revertToState(stateBeforeInitialize);

        initData = abi.encodeCall(
            vbToken.initialize,
            (
                owner,
                name,
                symbol,
                asset,
                1e19,
                address(vbTokenVault),
                yieldRecipient,
                LXLY_BRIDGE,
                nativeConverter,
                MINIMUM_YIELD_VAULT_DEPOSIT,
                address(0),
                initializer
            )
        );
        vm.expectRevert(VaultBridgeToken.InvalidMinimumReservePercentage.selector);
        vbToken = GenericVbToken(_proxify(vbTokenImplementation, address(this), initData));
        vm.revertToState(stateBeforeInitialize);

        initData = abi.encodeCall(
            vbToken.initialize,
            (
                owner,
                name,
                symbol,
                asset,
                minimumReservePercentage,
                address(0),
                yieldRecipient,
                LXLY_BRIDGE,
                nativeConverter,
                MINIMUM_YIELD_VAULT_DEPOSIT,
                address(0),
                initializer
            )
        );
        vm.expectRevert(VaultBridgeToken.InvalidYieldVault.selector);
        vbToken = GenericVbToken(_proxify(vbTokenImplementation, address(this), initData));
        vm.revertToState(stateBeforeInitialize);

        initData = abi.encodeCall(
            vbToken.initialize,
            (
                owner,
                name,
                symbol,
                asset,
                minimumReservePercentage,
                address(vbTokenVault),
                address(0),
                LXLY_BRIDGE,
                nativeConverter,
                MINIMUM_YIELD_VAULT_DEPOSIT,
                address(0),
                initializer
            )
        );
        vm.expectRevert(VaultBridgeToken.InvalidYieldRecipient.selector);
        vbToken = GenericVbToken(_proxify(vbTokenImplementation, address(this), initData));
        vm.revertToState(stateBeforeInitialize);

        initData = abi.encodeCall(
            vbToken.initialize,
            (
                owner,
                name,
                symbol,
                asset,
                minimumReservePercentage,
                address(vbTokenVault),
                yieldRecipient,
                address(0),
                nativeConverter,
                MINIMUM_YIELD_VAULT_DEPOSIT,
                address(0),
                initializer
            )
        );
        vm.expectRevert(VaultBridgeToken.InvalidLxLyBridge.selector);
        vbToken = GenericVbToken(_proxify(vbTokenImplementation, address(this), initData));
        vm.revertToState(stateBeforeInitialize);

        nativeConverter = [NativeConverterInfo({layerYLxlyId: NETWORK_ID_L1, nativeConverter: nativeConverterAddress})];

        initData = abi.encodeCall(
            vbToken.initialize,
            (
                owner,
                name,
                symbol,
                asset,
                minimumReservePercentage,
                address(vbTokenVault),
                yieldRecipient,
                LXLY_BRIDGE,
                nativeConverter,
                MINIMUM_YIELD_VAULT_DEPOSIT,
                address(0),
                initializer
            )
        );
        vm.expectRevert(VaultBridgeToken.InvalidNativeConverters.selector);
        vbToken = GenericVbToken(_proxify(vbTokenImplementation, address(this), initData));
        vm.revertToState(stateBeforeInitialize);
    }

    function test_deposit_revert() public {
        uint256 amount = 100 ether;

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
    }

    function test_deposit_amount_gt_max_deposit() public {
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));
        uint256 amount = (vaultMaxDeposit * 10) / 9 + 1; // acount for the minimum reserve percentage and add to make the amount greater than the max deposit limit
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
        assertGt(IERC20(vbTokenVault).balanceOf(address(vbToken)), 0); // shares locked in the vault
        assertEq(vbToken.balanceOf(recipient), sharesToBeMinted); // shares minted to the recipient
    }

    function test_deposit_amount_lt_max_deposit() public {
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));
        uint256 amount = (vaultMaxDeposit * 10) / 9 - 1; // acount for the minimum reserve percentage and subtracy to make the amount less than the max deposit limit
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
        uint256 reserveAssets = (amount * minimumReservePercentage) / MAX_MINIMUM_RESERVE_PERCENTAGE;

        assertEq(IERC20(asset).balanceOf(address(vbToken)), reserveAssets); // reserve assets increased
        assertGt(IERC20(vbTokenVault).balanceOf(address(vbToken)), 0); // shares locked in the vault
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
        assertEq(IERC20(vbTokenVault).balanceOf(address(vbToken)), 0); // No assets deposited in the vault
        assertEq(vbToken.balanceOf(recipient), sharesToBeMinted); // shares minted to the recipient
    }

    function test_depositWithPermit() public virtual {
        uint256 amount = 100 ether;
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

    function test_depositAndBridge() public {
        uint256 amount = 100 ether;
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
        uint256 amount = 100 ether;
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
        uint256 amount = 100 ether;
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
        uint256 amount = 100 ether;

        bytes memory callData = abi.encodeCall(vbToken.withdraw, (amount, recipient, sender));
        _testPauseUnpause(owner, address(vbToken), callData);

        vm.expectRevert(VaultBridgeToken.InvalidAssets.selector);
        vbToken.withdraw(0, recipient, sender);

        vm.expectRevert(VaultBridgeToken.InvalidReceiver.selector);
        vbToken.withdraw(amount, address(0), sender);

        vm.expectRevert(VaultBridgeToken.InvalidOwner.selector);
        vbToken.withdraw(amount, recipient, address(0));

        deal(asset, sender, amount);

        vm.startPrank(sender);

        IERC20(asset).forceApprove(address(vbToken), amount);
        vbToken.deposit(amount, sender);
        assertEq(IERC20(asset).balanceOf(sender), 0); // make sure sender has deposited all assets
        assertEq(vbToken.balanceOf(sender), amount); // sender gets 100 shares

        vm.expectRevert(
            abi.encodeWithSelector(VaultBridgeToken.AssetsTooLarge.selector, vbToken.totalAssets(), amount + 1)
        );
        vbToken.withdraw(amount + 1, sender, sender);

        vm.stopPrank();
    }

    function test_withdraw_from_reserve() public virtual {
        uint256 amount = 100 ether;
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));

        deal(asset, sender, amount);

        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(vbToken), amount);
        vbToken.deposit(amount, sender);
        assertEq(IERC20(asset).balanceOf(sender), 0); // make sure sender has deposited all assets
        assertEq(vbToken.balanceOf(sender), amount); // sender gets 100 shares

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
        uint256 amount = 100 ether;

        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(vbToken), amount);
        vbToken.deposit(amount, sender);
        assertEq(IERC20(asset).balanceOf(sender), 0); // make sure sender has deposited all assets
        assertEq(vbToken.balanceOf(sender), amount); // sender gets 100 shares

        uint256 amountToWithdraw = amount - 1;

        vm.expectEmit();
        emit IERC4626.Withdraw(sender, sender, sender, amountToWithdraw, amountToWithdraw);
        vbToken.withdraw(amountToWithdraw, sender, sender);
        assertEq(IERC20(asset).balanceOf(address(vbToken)), 0); // reserve assets reduced
        assertEq(IERC20(asset).balanceOf(sender), amountToWithdraw); // assets returned to sender
        assertEq(vbToken.balanceOf(sender), amount - amountToWithdraw); // shares reduced
        vm.stopPrank();
    }

    function test_rebalanceReserve_revert() public {
        vm.expectRevert(); // only owner can rebalance reserve
        vbToken.rebalanceReserve();

        bytes memory callData = abi.encodeCall(vbToken.rebalanceReserve, ());
        _testPauseUnpause(owner, address(vbToken), callData);
    }

    // TODO: fix this test and possibly the rebalance function
    // function test_rebalanceReserve_main() public {
    //     uint256 amount = 100 ether;
    //     uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));
    //     uint256 userDepositAmount = amount;
    //     uint256 totalSupply;
    //     deal(asset, sender, amount); // fund the sender

    //     if (userDepositAmount > vaultMaxDeposit) {
    //         userDepositAmount = vaultMaxDeposit / 2; // deposit half of the max deposit limit
    //         assertGt(
    //             userDepositAmount, MINIMUM_YIELD_VAULT_DEPOSIT, "Amount should be greater than the minimum deposit."
    //         );
    //         uint256 reserveAmount = (userDepositAmount * minimumReservePercentage) / MAX_MINIMUM_RESERVE_PERCENTAGE;

    //         // create reserve
    //         vm.startPrank(sender);

    //         IERC20(asset).forceApprove(address(vbToken), amount);
    //         vbToken.deposit(userDepositAmount, recipient);
    //         totalSupply += userDepositAmount;
    //         assertEq(vbToken.reservedAssets(), reserveAmount);
    //         console.log("Reserve Amount: ", reserveAmount);

    //         uint256 stakedAssetsBefore = vbToken.stakedAssets();

    //         // offset the reserve by reducing the reserve assets
    //         vm.store(address(vbToken), RESERVE_ASSET_STORAGE, bytes32(uint256(reserveAmount - 1)));

    //         vm.stopPrank();

    //         uint256 finalReserveAmount = totalSupply * minimumReservePercentage / MAX_MINIMUM_RESERVE_PERCENTAGE;
    //         vm.expectEmit();
    //         emit VaultBridgeToken.ReserveRebalanced(reserveAmount, finalReserveAmount, vbToken.reservePercentage());
    //         vm.prank(owner);
    //         vbToken.rebalanceReserve();

    //         assertEq(vbToken.reservedAssets(), finalReserveAmount);
    //         assertLt(vbToken.stakedAssets(), stakedAssetsBefore);
    //     } else {
    //         uint256 reserveAmount = (userDepositAmount * minimumReservePercentage) / MAX_MINIMUM_RESERVE_PERCENTAGE;

    //         vm.startPrank(sender);

    //         IERC20(asset).forceApprove(address(vbToken), amount);
    //         vbToken.deposit(userDepositAmount, recipient);
    //         totalSupply += userDepositAmount;
    //         assertEq(vbToken.reservedAssets(), reserveAmount);

    //         uint256 stakedAssetsBefore = vbToken.stakedAssets();
    //         uint256 reservedAssetsBefore = vbToken.reservedAssets();

    //         // offset the reserve by adding more shares
    //         deal(asset, address(vbToken), reservedAssetsBefore + amount);
    //         vm.store(address(vbToken), RESERVE_ASSET_STORAGE, bytes32(uint256(reservedAssetsBefore + amount)));

    //         vm.stopPrank();

    //         vm.expectEmit();
    //         emit VaultBridgeToken.ReserveRebalanced(reserveAmount, reservedAssetsBefore, vbToken.reservePercentage());
    //         vm.prank(owner);
    //         vbToken.rebalanceReserve();

    //         assertEq(vbToken.reservedAssets(), reservedAssetsBefore);
    //         assertGt(vbToken.stakedAssets(), stakedAssetsBefore);
    //     }
    // }

    function test_collectYield() public {
        vm.expectRevert(); // only owner can claim yield
        vbToken.collectYield();

        vm.expectRevert(VaultBridgeToken.NoYield.selector); // no reserved and staked assets
        vm.prank(owner);
        vbToken.collectYield();

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
        vbToken.collectYield();

        vm.assertEq(vbToken.balanceOf(yieldRecipient), expectedYieldAssets);
    }

    function test_setYieldRecipient_no_yield() public {
        address newRecipient = makeAddr("newRecipient");
        vm.expectRevert(); // only owner can claim yield
        vbToken.setYieldRecipient(newRecipient);

        vm.expectRevert(VaultBridgeToken.InvalidYieldRecipient.selector);
        vm.prank(owner);
        vbToken.setYieldRecipient(address(0));

        assertEq(vbToken.yieldRecipient(), yieldRecipient);

        vm.expectEmit();
        emit VaultBridgeToken.YieldRecipientSet(newRecipient);
        vm.prank(owner);
        vbToken.setYieldRecipient(newRecipient);
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
        vbToken.setYieldRecipient(newRecipient);
        assertEq(vbToken.balanceOf(yieldRecipient), expectedYieldAssets); // yield collected to the old recipient
        assertEq(vbToken.yieldRecipient(), newRecipient);
    }

    function test_setMinimumReservePercentage_no_rebalance() public {
        uint256 newPercentage = 2e17;
        vm.expectRevert(); // only owner can set minimum reserve percentage
        vbToken.setMinimumReservePercentage(newPercentage);

        vm.expectRevert(VaultBridgeToken.InvalidMinimumReservePercentage.selector);
        vm.prank(owner);
        vbToken.setMinimumReservePercentage(MAX_MINIMUM_RESERVE_PERCENTAGE + 1);

        assertEq(vbToken.minimumReservePercentage(), minimumReservePercentage); // sanity check

        vm.expectEmit();
        emit VaultBridgeToken.MinimumReservePercentageSet(newPercentage);
        vm.prank(owner);
        vbToken.setMinimumReservePercentage(newPercentage);
        assertEq(vbToken.minimumReservePercentage(), newPercentage);
    }

    // TODO: fix rebalance function
    // function test_setMinimumReservePercentage_with_rebalance() public {
    //     uint256 amount = 100 ether;
    //     uint256 newPercentage = 2e17;
    //     uint256 maxVaultDeposit = vbTokenVault.maxDeposit(address(vbToken));
    //     uint256 userDepositAmount = amount;

    //     if (userDepositAmount > maxVaultDeposit) {
    //         userDepositAmount = maxVaultDeposit / 2;
    //     }

    //     // create reserve
    //     deal(asset, sender, userDepositAmount);

    //     vm.startPrank(sender);

    //     IERC20(asset).forceApprove(address(vbToken), userDepositAmount);
    //     vbToken.deposit(userDepositAmount, recipient);

    //     vm.stopPrank();

    //     uint256 reserveAmount = (userDepositAmount * minimumReservePercentage) / MAX_MINIMUM_RESERVE_PERCENTAGE;
    //     assertEq(vbToken.reservedAssets(), reserveAmount);

    //     uint256 finalReserveAmount = (userDepositAmount * newPercentage) / MAX_MINIMUM_RESERVE_PERCENTAGE;
    //     uint256 stakedAssetsBefore = vbToken.stakedAssets();

    //     vm.expectEmit();
    //     emit VaultBridgeToken.ReserveRebalanced(reserveAmount, finalReserveAmount, vbToken.reservePercentage());
    //     vm.expectEmit();
    //     emit VaultBridgeToken.MinimumReservePercentageSet(newPercentage);
    //     vm.prank(owner);
    //     vbToken.setMinimumReservePercentage(newPercentage);

    //     assertEq(vbToken.minimumReservePercentage(), newPercentage);
    //     assertEq(vbToken.reservedAssets(), finalReserveAmount);
    //     assertLt(vbToken.stakedAssets(), stakedAssetsBefore);
    // }

    function testFuzz_setMinimumReservePercentage(uint256 percentage) public {
        vm.assume(percentage <= MAX_MINIMUM_RESERVE_PERCENTAGE);
        vm.prank(owner);
        vbToken.setMinimumReservePercentage(percentage);
        assertEq(vbToken.minimumReservePercentage(), percentage);
    }

    function test_redeem_revert() public {
        bytes memory callData = abi.encodeCall(vbToken.redeem, (100 ether, sender, sender));
        _testPauseUnpause(owner, address(vbToken), callData);

        vm.expectRevert(VaultBridgeToken.InvalidShares.selector);
        vbToken.redeem(0, sender, sender);

        vm.stopPrank();
    }

    function test_redeem() public virtual {
        uint256 amount = 100 ether;

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

    function test_onMessageReceived_revert() public {
        bytes memory callData = abi.encodeWithSelector(vbToken.onMessageReceived.selector, address(0), 0, "");
        _testPauseUnpause(owner, address(vbToken), callData);

        bytes memory data =
            abi.encode(VaultBridgeToken.CrossNetworkInstruction.COMPLETE_MIGRATION, abi.encode(100, 100));

        // Not bridge manager
        vm.expectRevert(VaultBridgeToken.Unauthorized.selector);
        vbToken.onMessageReceived(nativeConverterAddress, NETWORK_ID_L2, data);

        vm.startPrank(LXLY_BRIDGE);

        // No origin address
        vm.expectRevert(VaultBridgeToken.Unauthorized.selector);
        vbToken.onMessageReceived(address(0), NETWORK_ID_L2, data);

        // Wrong network id
        vm.expectRevert(VaultBridgeToken.Unauthorized.selector);
        vbToken.onMessageReceived(nativeConverterAddress, NETWORK_ID_L1, data);

        bytes memory invalidSharesData =
            abi.encode(VaultBridgeToken.CrossNetworkInstruction.COMPLETE_MIGRATION, abi.encode(0, 100));

        vm.expectRevert(VaultBridgeToken.InvalidShares.selector);
        vbToken.onMessageReceived(nativeConverterAddress, NETWORK_ID_L2, invalidSharesData);

        vm.stopPrank();
    }

    function test_onMessageReceived_no_discrepancy_shares_lt_max_deposit() public {
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));
        uint256 amount = (vaultMaxDeposit * 10) / 9 - 1;
        uint256 shares = vbToken.convertToShares(amount);

        bytes memory data =
            abi.encode(VaultBridgeToken.CrossNetworkInstruction.COMPLETE_MIGRATION, abi.encode(shares, amount));

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
        emit IERC4626.Deposit(LXLY_BRIDGE, address(vbToken), amount, shares);
        vm.expectEmit();
        emit VaultBridgeToken.MigrationCompleted(NETWORK_ID_L2, shares, amount, amount, 0);
        vm.prank(LXLY_BRIDGE);
        vbToken.onMessageReceived(nativeConverterAddress, NETWORK_ID_L2, data);

        uint256 reserveAssetsAfterDeposit =
            vbToken.convertToAssets(shares) * minimumReservePercentage / MAX_MINIMUM_RESERVE_PERCENTAGE;

        assertEq(vbToken.reservedAssets(), reserveAssetsAfterDeposit);
        assertGt(vbToken.stakedAssets(), stakedAssetsBefore);
    }

    function test_onMessageReceived_no_discrepancy_shares_gt_max_deposit() public {
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));
        uint256 amount = (vaultMaxDeposit * 10) / 9 + 1;
        uint256 shares = vbToken.convertToShares(amount);

        bytes memory data =
            abi.encode(VaultBridgeToken.CrossNetworkInstruction.COMPLETE_MIGRATION, abi.encode(shares, amount));

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
        emit IERC4626.Deposit(LXLY_BRIDGE, address(vbToken), amount, shares);
        vm.expectEmit();
        emit VaultBridgeToken.MigrationCompleted(NETWORK_ID_L2, shares, amount, amount, 0);
        vm.prank(LXLY_BRIDGE);
        vbToken.onMessageReceived(nativeConverterAddress, NETWORK_ID_L2, data);

        // since max deposit is reached, the reserve amount should be calculated based on the max deposit limit
        uint256 reserveAssetsAfterDeposit = _calculateReserveAssets(amount, vaultMaxDeposit);

        assertEq(vbToken.reservedAssets(), reserveAssetsAfterDeposit);
        assertGt(vbToken.stakedAssets(), stakedAssetsBefore);
    }

    function test_onMessageReceived_with_discrepancy() public {
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));
        uint256 amount = (vaultMaxDeposit * 10) / 9 - 1;
        uint256 shares = vbToken.convertToShares(amount) + vbToken.convertToShares(1);

        bytes memory data =
            abi.encode(VaultBridgeToken.CrossNetworkInstruction.COMPLETE_MIGRATION, abi.encode(shares, amount));

        // no migration fees funds
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

        uint256 reserveAssetsAfterDeposit =
            vbToken.convertToAssets(shares) * minimumReservePercentage / MAX_MINIMUM_RESERVE_PERCENTAGE;

        assertEq(vbToken.reservedAssets(), reserveAssetsAfterDeposit);
        assertGt(vbToken.stakedAssets(), stakedAssetsBefore);
    }

    function test_maxDeposit() public {
        assertEq(vbToken.maxDeposit(address(0)), type(uint256).max);

        vm.prank(owner);
        vbToken.pause();
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
        vbToken.pause();
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
        uint256 amount = 100 ether;

        vm.startPrank(owner);
        vbToken.pause();
        vm.assertEq(vbToken.maxWithdraw(address(0)), 0);
        vbToken.unpause();
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
        uint256 amount = 100 ether;
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

        vm.expectRevert(
            abi.encodeWithSelector(VaultBridgeToken.AssetsTooLarge.selector, vbToken.totalAssets(), amount + 1)
        );
        vbToken.previewWithdraw(amount + 1);

        uint256 stakedAmount = vbTokenVault.convertToAssets(vbTokenVault.balanceOf(address(vbToken)));
        uint256 reserveAssetsAfterDeposit = _calculateReserveAssets(amount, vaultMaxDeposit);

        vm.assertEq(vbToken.previewWithdraw(reserveAssetsAfterDeposit), vbToken.reservedAssets()); // reserve assets
        vm.assertEq(vbToken.previewWithdraw(reserveAssetsAfterDeposit + stakedAmount), vbToken.totalAssets()); // reserve + staked assets
    }

    function test_maxRedeem() public virtual {
        uint256 amount = 100 ether;

        vm.startPrank(owner);
        vbToken.pause();
        vm.assertEq(vbToken.maxRedeem(sender), 0);
        vbToken.unpause();
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
        uint256 amount = 100 ether;
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));
        uint256 reserveAmount = (amount * minimumReservePercentage) / MAX_MINIMUM_RESERVE_PERCENTAGE;

        bytes memory callData = abi.encodeCall(vbToken.previewRedeem, (amount));
        _testPauseUnpause(owner, address(vbToken), callData);

        vm.expectRevert(VaultBridgeToken.InvalidShares.selector);
        vbToken.previewRedeem(0);

        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(vbToken), amount);
        vbToken.deposit(amount, sender);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(VaultBridgeToken.AssetsTooLarge.selector, vbToken.totalAssets(), amount + 1)
        );
        vbToken.previewRedeem(amount + 1);

        uint256 stakedAmount = vbTokenVault.convertToAssets(vbTokenVault.balanceOf(address(vbToken)));
        uint256 assetsToDeposit = amount - reserveAmount;
        uint256 assetsToDepositMax = (assetsToDeposit > vaultMaxDeposit) ? vaultMaxDeposit : assetsToDeposit;
        uint256 reserveAssetsAfterDeposit = amount - assetsToDepositMax;

        vm.assertEq(vbToken.previewRedeem(reserveAssetsAfterDeposit), vbToken.reservedAssets()); // reserve assets
        vm.assertEq(vbToken.previewRedeem(reserveAssetsAfterDeposit + stakedAmount), vbToken.totalAssets()); // reserve + staked assets
    }

    function test_reservePercentage() public {
        uint256 amount = 100 ether;
        uint256 vaultMaxDeposit = vbTokenVault.maxDeposit(address(vbToken));

        deal(asset, sender, amount);
        vm.startPrank(sender);
        IERC20(asset).forceApprove(address(vbToken), amount);
        vbToken.deposit(amount, sender);
        vm.stopPrank();

        uint256 reserveAssetsAfterDeposit = _calculateReserveAssets(amount, vaultMaxDeposit);

        uint256 expectedPercentage =
            (reserveAssetsAfterDeposit * MAX_MINIMUM_RESERVE_PERCENTAGE) / vbToken.totalSupply();

        assertEq(vbToken.reservePercentage(), expectedPercentage);
    }

    function test_pause_unpause() public {
        vm.expectRevert();
        vbToken.pause();

        vm.expectRevert();
        vbToken.unpause();

        vm.startPrank(owner);
        vm.expectEmit();
        emit PausableUpgradeable.Paused(owner);
        vbToken.pause();

        vm.expectEmit();
        emit PausableUpgradeable.Unpaused(owner);
        vbToken.unpause();
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
        uint256 reserveAssets = (amount * minimumReservePercentage) / MAX_MINIMUM_RESERVE_PERCENTAGE;
        uint256 assetsToDeposit = amount - reserveAssets;
        uint256 assetsToDepositMax = (assetsToDeposit > vaultMaxDeposit) ? vaultMaxDeposit : assetsToDeposit;
        return amount - assetsToDepositMax;
    }

    function _testPauseUnpause(address caller, address callee, bytes memory callData) internal {
        vm.startPrank(caller);
        (bool success, /* bytes memory data */ ) = callee.call(abi.encodeCall(vbToken.pause, ()));

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        (success, /* bytes memory data */ ) = callee.call(callData);

        (success, /* bytes memory data */ ) = callee.call(abi.encodeCall(vbToken.unpause, ()));
        vm.stopPrank();
    }

    function _proxify(address logic, address admin, bytes memory initData) internal returns (address proxy) {
        proxy = address(new TransparentUpgradeableProxy(logic, admin, initData));
    }
}
