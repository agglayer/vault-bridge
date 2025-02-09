// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

import {ZETH} from "../../src/custom-tokens/WETH/zETH.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract ZETHTest is Test {
    ZETH internal zETH;
    uint256 internal zkevmFork;
    address LXLY_BRIDGE = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
    address internal calculatedNativeConverterAddr =
        vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 2);

    function setUp() public {
        zkevmFork = vm.createSelectFork("polygon_zkevm", 19164969);

        zETH = new ZETH();
        bytes memory initData = abi.encodeCall(
            ZETH.initialize, (address(this), "zETH", "zETH", 18, LXLY_BRIDGE, calculatedNativeConverterAddr)
        );
        zETH = ZETH(payable(address(new TransparentUpgradeableProxy(address(zETH), address(this), initData))));

        vm.label(address(zETH), "zETH");
    }

    function test_zETH_receive(uint256 amount) public {
        assertEq(zETH.balanceOf(address(this)), 0);
        deal(address(this), amount);

        (bool success,) = address(zETH).call{value: amount}("");
        require(success);
        assertEq(zETH.balanceOf(address(this)), amount);
    }

    function test_zETH_deposit(uint256 amount) public {
        assertEq(zETH.balanceOf(address(this)), 0);
        deal(address(this), amount);

        vm.expectEmit();
        emit ZETH.Deposit(address(this), amount);
        zETH.deposit{value: amount}();
        assertEq(zETH.balanceOf(address(this)), amount);
    }

    function test_zETH_withdraw(uint256 amount) public {
        assertEq(zETH.balanceOf(address(this)), 0);
        deal(address(this), amount);

        zETH.deposit{value: amount}();
        assertEq(zETH.balanceOf(address(this)), amount);
        assertEq(address(this).balance, 0);

        vm.expectEmit();
        emit ZETH.Withdrawal(address(this), amount);
        zETH.withdraw(amount);
        assertEq(zETH.balanceOf(address(this)), 0);
        assertEq(address(this).balance, amount);
    }

    function test_zETH_version() public view {
        assertEq(zETH.version(), "1.0.0");
    }

    receive() external payable {}
}
