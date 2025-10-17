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

// Helper contract that rejects ETH transfers to test WithdrawalFailed
contract RejectingReceiver {
// No receive() or fallback() function, so it will reject ETH transfers
}

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

    function test_Revert_withdraw_AssetsTooLarge() public {
        uint256 depositAmount = 1 ether;
        uint256 excessiveWithdrawal = 2 ether;

        assertEq(wethAgglayer.balanceOf(address(this)), 0);
        deal(address(this), depositAmount);

        // Deposit 1 ether
        wethAgglayer.deposit{value: depositAmount}();
        assertEq(wethAgglayer.balanceOf(address(this)), depositAmount);

        // Try to withdraw 2 ether (more than gasBackingOnSecondaryChain)
        vm.expectRevert(
            abi.encodeWithSelector(CustomTokenWethExtension.AssetsTooLarge.selector, depositAmount, excessiveWithdrawal)
        );
        wethAgglayer.withdraw(excessiveWithdrawal);
    }

    function test_Revert_withdraw_WithdrawalFailed() public {
        uint256 depositAmount = 1 ether;

        // Deploy a contract that rejects ETH transfers
        RejectingReceiver rejecter = new RejectingReceiver();

        // Give the rejecter some ETH and deposit it
        vm.deal(address(rejecter), depositAmount);
        vm.prank(address(rejecter));
        wethAgglayer.deposit{value: depositAmount}();
        assertEq(wethAgglayer.balanceOf(address(rejecter)), depositAmount);

        // Try to withdraw - should fail because rejecter won't accept ETH
        vm.prank(address(rejecter));
        vm.expectRevert(CustomTokenWethExtension.WithdrawalFailed.selector);
        wethAgglayer.withdraw(depositAmount);
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
