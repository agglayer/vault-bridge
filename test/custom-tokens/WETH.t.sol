// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

import {WETH} from "../../src/custom-tokens/WETH/WETH.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract WETHTest is Test {
    WETH internal wETH;
    uint256 internal zkevmFork;
    address LXLY_BRIDGE = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
    address internal calculatedNativeConverterAddr =
        vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 2);

    function setUp() public {
        zkevmFork = vm.createSelectFork("polygon_zkevm", 19164969);

        wETH = new WETH();
        bytes memory initData = abi.encodeCall(
            WETH.initialize, (address(this), "wETH", "wETH", 18, LXLY_BRIDGE, calculatedNativeConverterAddr)
        );
        wETH = WETH(payable(address(new TransparentUpgradeableProxy(address(wETH), address(this), initData))));

        vm.label(address(wETH), "wETH");
    }

    function test_wETH_receive(uint256 amount) public {
        assertEq(wETH.balanceOf(address(this)), 0);
        deal(address(this), amount);

        (bool success,) = address(wETH).call{value: amount}("");
        require(success);
        assertEq(wETH.balanceOf(address(this)), amount);
    }

    function test_wETH_deposit(uint256 amount) public {
        assertEq(wETH.balanceOf(address(this)), 0);
        deal(address(this), amount);

        vm.expectEmit();
        emit WETH.Deposit(address(this), amount);
        wETH.deposit{value: amount}();
        assertEq(wETH.balanceOf(address(this)), amount);
    }

    function test_wETH_withdraw(uint256 amount) public {
        assertEq(wETH.balanceOf(address(this)), 0);
        deal(address(this), amount);

        wETH.deposit{value: amount}();
        assertEq(wETH.balanceOf(address(this)), amount);
        assertEq(address(this).balance, 0);

        vm.expectEmit();
        emit WETH.Withdrawal(address(this), amount);
        wETH.withdraw(amount);
        assertEq(wETH.balanceOf(address(this)), 0);
        assertEq(address(this).balance, amount);
    }

    function test_wETH_version() public view {
        assertEq(wETH.version(), "1.0.0");
    }

    receive() external payable {}
}
