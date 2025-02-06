// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {YeETH} from "src/yield-exposed-tokens/yeETH/YeETH.sol";
import {YieldExposedToken} from "src/YieldExposedToken.sol";
import {ILxLyBridge} from "src/etc/ILxLyBridge.sol";
import {IWETH9} from "src/etc/IWETH9.sol";
import {GenericYieldExposedTokenTest, GenericYeToken} from "test/GenericYieldExposedToken.t.sol";
import {IMetaMorpho} from "test/interfaces/IMetaMorpho.sol";

contract YeETHTest is GenericYieldExposedTokenTest {
    YeETH public yeETH;
    address public morphoVault;

    address constant WETH_METAMORPHO = 0x78Fc2c2eD1A4cDb5402365934aE5648aDAd094d0;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint32 constant ZKEVM_NETWORK_ID = 1; // zkEVM

    function setUp() public override {
        mainnetFork = vm.createSelectFork("mainnet_test", 21590932);

        asset = WETH;
        yeTokenVault = IMetaMorpho(WETH_METAMORPHO);
        version = "1.0.0";
        name = "Yield Exposed ETH";
        symbol = "yeETH";
        decimals = 18;
        yeTokenMetaData = abi.encode(name, symbol, decimals);
        minimumReservePercentage = 10;

        // Deploy implementation
        yeToken = GenericYeToken(address(new YeETH()));
        yeTokenImplementation = address(yeToken);
        stateBeforeInitialize = vm.snapshotState();

        // prepare calldata
        bytes memory initData = abi.encodeCall(
            yeETH.initialize,
            (
                owner, // owner
                name, // name
                symbol, // symbol
                asset, // underlying token
                minimumReservePercentage,
                address(yeTokenVault), // Use our deployed Morpho vault
                yieldRecipient, // mock yield recipient
                LXLY_BRIDGE,
                nativeConverter // mock migration manager
            )
        );

        // deploy proxy and initialize implementation
        yeToken = GenericYeToken(_proxify(address(yeTokenImplementation), address(this), initData));
        yeETH = YeETH(address(yeToken));

        vm.label(address(yeTokenVault), "WETH Vault");
        vm.label(address(yeToken), "yeETH");
        vm.label(address(yeTokenImplementation), "yeETH Implementation");
        vm.label(address(this), "Default Address");
        vm.label(asset, "Underlying Asset");
        vm.label(nativeConverter, "Native Converter");
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
        assertEq(yeETH.name(), "Yield Exposed ETH");
        assertEq(yeETH.symbol(), "yeETH");
        assertEq(yeETH.asset(), WETH);
    }

    function test_depositGasToken(address receiver, uint256 depositAmount) public {
        vm.assume(receiver != address(0));
        vm.assume(depositAmount > 0 && depositAmount < 100 ether);

        // Get initial balance
        uint256 initialReceiverBalance = yeETH.balanceOf(receiver);

        // Deposit ETH
        vm.deal(address(this), depositAmount);
        uint256 shares = yeETH.depositGasToken{value: depositAmount}(receiver);

        // Verify
        assertGt(shares, 0, "Should receive shares for deposit");
        assertEq(yeETH.balanceOf(receiver), initialReceiverBalance + shares, "Receiver should get correct shares");
    }

    function test_depositGasTokenAndBridge(address receiver, uint256 depositAmount) public {
        vm.assume(receiver != address(0));
        vm.assume(depositAmount > 0 && depositAmount < 100 ether);

        // Deposit ETH
        vm.deal(address(this), depositAmount);
        uint256 shares = yeETH.depositGasTokenAndBridge{value: depositAmount}(receiver, ZKEVM_NETWORK_ID, true);

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
        weth.approve(address(yeETH), depositAmount);

        uint256 shares = yeETH.deposit(depositAmount, receiver);

        assertEq(yeETH.balanceOf(receiver), shares, "Receiver should get correct shares");
    }

    function test_mint(uint256 amount) public {
        vm.assume(amount > 0 && amount < 100 ether);
        vm.deal(address(this), amount + 1 ether);

        uint256 initialBalance = IWETH9(WETH).balanceOf(address(this));

        // sending a bit more to test refund func
        yeETH.mintWithGasToken{value: amount + 1 ether}(amount, address(this));

        // check refund
        assertEq(IWETH9(WETH).balanceOf(address(this)), initialBalance + 1 ether);

        assertEq(yeETH.balanceOf(address(this)), amount); // shares minted to the sender
        assertApproxEqAbs(yeETH.totalAssets(), amount, 2); // allow for rounding

        uint256 reserveAmount = (amount * minimumReservePercentage) / MAX_MINIMUM_RESERVE_PERCENTAGE;
        assertApproxEqAbs(yeETH.reservedAssets(), reserveAmount, 2); // allow for rounding
    }

    function test_withdraw() public override {
        uint256 initialAmount = 100;
        uint256 reserveAmount = (initialAmount * minimumReservePercentage) / MAX_MINIMUM_RESERVE_PERCENTAGE; // 10

        // Deposit ETH
        vm.deal(address(this), initialAmount);
        uint256 shares = yeETH.depositGasToken{value: initialAmount}(address(this));
        assertEq(yeETH.balanceOf(address(this)), shares); // sender gets 100 shares

        uint256 withdrawAmount = 110; // withdraw amount is greater than total assets (100)
        vm.expectRevert(abi.encodeWithSelector(YieldExposedToken.AssetsTooLarge.selector, 99, 110));
        yeETH.withdraw(withdrawAmount, address(this), address(this));

        uint256 initialBalance = IWETH9(WETH).balanceOf(address(this));

        uint256 reserveWithdrawAmount = 5;
        reserveAmount -= reserveWithdrawAmount;
        yeETH.withdraw(reserveWithdrawAmount, address(this), address(this));
        assertEq(IWETH9(WETH).balanceOf(address(yeETH)), reserveAmount); // reserve assets reduced
        assertEq(IWETH9(WETH).balanceOf(address(this)), initialBalance + reserveWithdrawAmount); // assets returned to sender
        assertEq(yeETH.balanceOf(address(this)), initialAmount - reserveWithdrawAmount); // shares reduced

        uint256 stakeWithdrawAmount = 10; // withdraw amount is greater than reserve amount (5)
        yeETH.withdraw(stakeWithdrawAmount, address(this), address(this));
        assertEq(IWETH9(WETH).balanceOf(address(yeETH)), 0); // reserve assets remain same
        assertEq(IWETH9(WETH).balanceOf(address(this)), initialBalance + reserveWithdrawAmount + stakeWithdrawAmount); // assets returned to sender
        assertEq(yeETH.balanceOf(address(this)), initialAmount - reserveWithdrawAmount - stakeWithdrawAmount); // shares reduced
    }
}
