// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {YeETH} from "../src/yield-exposed-tokens/yeETH/yeETH.sol";
import {ERC1967Proxy} from "@openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IMetaMorphoV1_1Factory} from "./interfaces/IMetaMorphoV1_1Factory.sol";
import {ILxLyBridge} from "../src/etc/ILxLyBridge.sol";
import {IWETH9} from "../src/etc/IWETH9.sol";

contract yeETHTest is Test {
    YeETH public implementation;
    YeETH public yeETH;
    uint256 mainnetFork;
    uint256 zkevmFork;
    address public morphoVault;

    // address constant METAMORPHO_FACTORY = 0x1897A8997241C1cD4bD0698647e4EB7213535c24;
    address constant WETH_METAMORPHO = 0x78Fc2c2eD1A4cDb5402365934aE5648aDAd094d0;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant LXLY_BRIDGE = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
    uint8 constant MINIMUM_RESERVE_PERCENTAGE = 10;
    uint32 constant ZKEVM_NETWORK_ID = 1; // zkEVM

    function setUp() public {
        mainnetFork = vm.createSelectFork("mainnet_test", 21590932);

        // Deploy implementation
        implementation = new YeETH();

        // prepare calldata
        bytes memory initData = abi.encodeCall(
            yeETH.initialize,
            (
                address(this), // owner
                "Yield Exposed ETH", // name
                "yeETH", // symbol
                WETH, // underlying token
                MINIMUM_RESERVE_PERCENTAGE,
                WETH_METAMORPHO, // Use our deployed Morpho vault
                makeAddr("yield"), // mock yield recipient
                LXLY_BRIDGE,
                makeAddr("migration") // mock migration manager
            )
        );

        // deploy proxy and initialize implementation
        ERC1967Proxy proxyContract = new ERC1967Proxy(address(implementation), initData);

        // Get the proxy instance
        yeETH = YeETH(address(proxyContract));
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

        // sending a bit more to test refund func
        yeETH.mintWithGasToken{value: amount + 1 ether}(amount, address(this));

        assertEq(yeETH.balanceOf(address(this)), amount); // shares minted to the sender
        assertApproxEqAbs(yeETH.totalAssets(), amount, 2); // allow for rounding

        uint256 reserveAmount = (amount * MINIMUM_RESERVE_PERCENTAGE) / 100;
        assertApproxEqAbs(yeETH.reservedAssets(), reserveAmount, 2); // allow for rounding
    }

    function test_withdraw() public {
        uint256 initialAmount = 100;
        uint256 reserveAmount = (initialAmount * MINIMUM_RESERVE_PERCENTAGE) / 100; // 10

        // Deposit ETH
        vm.deal(address(this), initialAmount);
        uint256 shares = yeETH.depositGasToken{value: initialAmount}(address(this));
        assertEq(yeETH.balanceOf(address(this)), shares); // sender gets 100 shares

        uint256 withdrawAmount = 110; // withdraw amount is greater than total assets (100)
        vm.expectRevert("AMOUNT_TOO_LARGE");
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
