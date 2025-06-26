// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import "forge-std/Test.sol";

import {WETH} from "../../src/custom-tokens/WETH/WETH.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract LXLYBridgeMock {
    address public gasTokenAddress;
    uint32 public gasTokenNetwork;

    function setGasTokenAddress(address _gasTokenAddress) external {
        gasTokenAddress = _gasTokenAddress;
    }

    function setGasTokenNetwork(uint32 _gasTokenNetwork) external {
        gasTokenNetwork = _gasTokenNetwork;
    }
}

contract WETHTest is Test {
    WETH internal wETH;
    LXLYBridgeMock internal lxlyBridgeMock;
    uint256 internal zkevmFork;
    address LXLY_BRIDGE = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
    address internal calculatedNativeConverterAddr =
        vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 2);

    function setUp() public {
        zkevmFork = vm.createSelectFork("polygon_zkevm", 19164969);

        _deployWETH(LXLY_BRIDGE);
        lxlyBridgeMock = new LXLYBridgeMock();

        vm.label(address(wETH), "wETH");
        vm.label(address(lxlyBridgeMock), "lxlyBridgeMock");
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
        assertEq(wETH.version(), "0.5.0");
    }

    function test_onlyIfGasTokenIsEth() public {
        uint256 amount = 1 ether;
        deal(address(this), amount);

        lxlyBridgeMock.setGasTokenAddress(address(this));
        lxlyBridgeMock.setGasTokenNetwork(0);
        _deployWETH(address(lxlyBridgeMock));
        vm.expectRevert(WETH.FunctionNotSupportedOnThisNetwork.selector);
        wETH.deposit{value: amount}();

        lxlyBridgeMock.setGasTokenAddress(address(0));
        lxlyBridgeMock.setGasTokenNetwork(1);
        _deployWETH(address(lxlyBridgeMock));
        vm.expectRevert(WETH.FunctionNotSupportedOnThisNetwork.selector);
        wETH.deposit{value: amount}();

        lxlyBridgeMock.setGasTokenAddress(address(0));
        lxlyBridgeMock.setGasTokenNetwork(0);
        _deployWETH(address(lxlyBridgeMock));
        vm.expectEmit();
        emit WETH.Deposit(address(this), amount);
        wETH.deposit{value: amount}();
        assertEq(wETH.balanceOf(address(this)), amount);
    }

    function _deployWETH(address _lxlyBridge) internal {
        wETH = new WETH();
        bytes memory initData = abi.encodeCall(
            WETH.reinitialize, (address(this), "wETH", "wETH", 18, _lxlyBridge, calculatedNativeConverterAddr)
        );
        wETH = WETH(payable(address(new TransparentUpgradeableProxy(address(wETH), address(this), initData))));
    }

    receive() external payable {}
}
