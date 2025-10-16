// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test Base
import {
    WethAgglayerTestBase,
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "test/base/secondary-chain/WethAgglayerTestBase.sol";

// Core contracts
import {CustomTokenWethExtension} from "src/secondary-chain/CustomTokenWethExtension.sol";

contract WethAgglayerTest is WethAgglayerTestBase {
    function setUp() public {
        deployWethAgglayerInfrastructure();
    }

    function test_receive(uint256 amount) public {
        assertEq(wethAgglayer.balanceOf(address(this)), 0);
        deal(address(this), amount);

        vm.expectRevert();
        (address(wethAgglayer).call{value: amount}(""));
    }

    function test_deposit(uint256 amount) public {
        assertEq(wethAgglayer.balanceOf(address(this)), 0);
        deal(address(this), amount);

        vm.expectEmit();
        emit CustomTokenWethExtension.Deposit(address(this), amount);
        wethAgglayer.deposit{value: amount}();
        assertEq(wethAgglayer.balanceOf(address(this)), amount);
    }

    function test_withdraw(uint256 amount) public {
        // test withdrawal failure on onlyIfGasTokenIsEth
        mockAgglayerBridge.setGasTokenAddress(address(this));
        mockAgglayerBridge.setGasTokenNetwork(0);
        deployWethAgglayer(false);
        vm.expectRevert(CustomTokenWethExtension.FunctionNotSupportedOnThisChain.selector);
        wethAgglayer.withdraw(amount);

        mockAgglayerBridge.setGasTokenAddress(address(0));
        mockAgglayerBridge.setGasTokenNetwork(0);
        deployWethAgglayer(true);
        assertEq(wethAgglayer.balanceOf(address(this)), 0);
        deal(address(this), amount);

        wethAgglayer.deposit{value: amount}();
        assertEq(wethAgglayer.balanceOf(address(this)), amount);
        assertEq(address(this).balance, 0);

        vm.expectEmit();
        emit CustomTokenWethExtension.Withdrawal(address(this), amount);
        wethAgglayer.withdraw(amount);
        assertEq(wethAgglayer.balanceOf(address(this)), 0);
        assertEq(address(this).balance, amount);
    }

    function test_onlyIfGasTokenIsEth() public {
        uint256 amount = 1 ether;
        deal(address(this), amount);

        mockAgglayerBridge.setGasTokenAddress(address(this));
        mockAgglayerBridge.setGasTokenNetwork(0);
        deployWethAgglayer(true);
        vm.expectRevert(CustomTokenWethExtension.FunctionNotSupportedOnThisChain.selector);
        wethAgglayer.deposit{value: amount}();

        mockAgglayerBridge.setGasTokenAddress(address(0));
        mockAgglayerBridge.setGasTokenNetwork(1);
        deployWethAgglayer(true);
        vm.expectRevert(CustomTokenWethExtension.FunctionNotSupportedOnThisChain.selector);
        wethAgglayer.deposit{value: amount}();

        mockAgglayerBridge.setGasTokenAddress(address(0));
        mockAgglayerBridge.setGasTokenNetwork(0);
        deployWethAgglayer(true);
        vm.expectEmit();
        emit CustomTokenWethExtension.Deposit(address(this), amount);
        wethAgglayer.deposit{value: amount}();
        assertEq(wethAgglayer.balanceOf(address(this)), amount);
    }

    function test_onlyWethFunctionalityEnabled() public {
        uint256 amount = 1 ether;
        deal(address(this), amount);

        vm.prank(owner);
        CustomTokenWethExtension(payable(address(wethAgglayer))).setWethFunctionalityEnabled(false);
        vm.expectRevert(CustomTokenWethExtension.FunctionNotEnabledOnThisChain.selector);
        wethAgglayer.deposit{value: amount}();

        vm.prank(owner);
        CustomTokenWethExtension(payable(address(wethAgglayer))).setWethFunctionalityEnabled(true);
        vm.expectEmit();
        emit CustomTokenWethExtension.Deposit(address(this), amount);
        wethAgglayer.deposit{value: amount}();
        assertEq(wethAgglayer.balanceOf(address(this)), amount);
    }

    receive() external payable {}
}
