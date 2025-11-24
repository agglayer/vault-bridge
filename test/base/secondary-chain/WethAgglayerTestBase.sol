// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test infrastructure
import {
    MockERC20Upgradeable,
    MockTokenWrappedBridgeUpgradeable,
    SecondaryChainBase
} from "test/base/secondary-chain/SecondaryChainBase.sol";

// Core contracts
import {WethAgglayer} from "src/secondary-chain/agglayer/vbETH/WethAgglayer.sol";

// OpenZeppelin
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title WETH Agglayer Test Base
/// @notice Base contract for testing WETH Agglayer as a standalone contract
abstract contract WethAgglayerTestBase is SecondaryChainBase {
    // ========= MAIN CONTRACTS =========
    WethAgglayer internal wethAgglayer;
    address internal wethAgglayerImpl;

    /// @notice Deploy WETH Agglayer-specific infrastructure
    /// @dev Sets up tokens, bridge, and related contracts for WETH Agglayer testing
    function deployWethAgglayerInfrastructure() internal {
        customTokenName = "WETH Custom Token";
        customTokenSymbol = "cWETH";
        customTokenDecimals = 18;

        deploySecondaryChainInfrastructure();
        deployWethAgglayer(true);
        verifyWethAgglayerSetup();
        setupLabels();
    }
    /// @notice Deploy WETH Agglayer and related contracts
    /// @dev This includes deploying the Custom Token and initializing both contracts

    function deployWethAgglayer(bool wethFunctionalityEnabled_) internal {
        MockTokenWrappedBridgeUpgradeable existingWethAgglayerImpl = new MockTokenWrappedBridgeUpgradeable();
        TransparentUpgradeableProxy existingWethAgglayerProxy = TransparentUpgradeableProxy(
            payable(
                _proxify(
                    address(existingWethAgglayerImpl),
                    address(this),
                    abi.encodeCall(
                        MockTokenWrappedBridgeUpgradeable.initialize,
                        (customTokenName, customTokenSymbol, customTokenDecimals, address(mockAgglayerBridge))
                    )
                )
            )
        );

        address wethAgglayerImplAddr = address(new WethAgglayer());

        bytes[] memory reinitializeCallData = new bytes[](3);
        reinitializeCallData[0] = abi.encodeCall(WethAgglayer.reinitialize1, ());
        reinitializeCallData[1] = abi.encodeCall(
            WethAgglayer.reinitialize2, (owner, customTokenDecimals, address(mockAgglayerBridge), dummyNativeConverter)
        );
        reinitializeCallData[2] = abi.encodeCall(WethAgglayer.reinitialize3, (wethFunctionalityEnabled_));

        bytes memory wethAgglayerInitData = abi.encodeCall(WethAgglayer.reinitialize, (reinitializeCallData));

        bytes memory upgradeData = abi.encodeWithSelector(
            ITransparentUpgradeableProxy.upgradeToAndCall.selector, wethAgglayerImplAddr, wethAgglayerInitData
        );
        vm.prank(_getProxyAdmin(address(existingWethAgglayerProxy)));
        (bool success, bytes memory returndata) = address(existingWethAgglayerProxy).call(upgradeData);
        if (!success) {
            assembly {
                revert(add(returndata, 32), mload(returndata))
            }
        }

        wethAgglayer = WethAgglayer(payable(address(existingWethAgglayerProxy)));
    }

    /// @notice Setup debugging labels
    function setupLabels() internal {
        vm.label(address(wethAgglayer), "wethAgglayer");
        vm.label(address(wethAgglayerImpl), "wethAgglayerImpl");
    }

    /// @notice Helper to verify basic NativeConverter setup
    function verifyWethAgglayerSetup() internal view {
        assertEq(wethAgglayer.name(), customTokenName);
        assertEq(wethAgglayer.symbol(), customTokenSymbol);
        assertEq(wethAgglayer.decimals(), customTokenDecimals);
        assertEq(wethAgglayer.bridge(), address(mockAgglayerBridge));
        assertEq(wethAgglayer.nativeConverter(), dummyNativeConverter);
    }
}
