// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test Base
import {WethWormholeTestBase, TransparentUpgradeableProxy} from "test/base/secondary-chain/WethWormholeTestBase.sol";

// Core contracts
import {WethWormhole} from "src/secondary-chain/wormhole/vbETH/WethWormhole.sol";
import {CustomToken} from "src/secondary-chain/CustomToken.sol";
import {CustomTokenWethExtension} from "src/secondary-chain/CustomTokenWethExtension.sol";

// OpenZeppelin
import {IAccessControl} from "@openzeppelin-contracts/access/IAccessControl.sol";

/// @dev WethWormhole tests
/// @notice Comprehensive tests for WethWormhole which covers both CustomTokenWormhole and CustomTokenWethExtension functionality
contract WethWormholeTest is WethWormholeTestBase {
    function setUp() public virtual {
        deployWethWormholeInfrastructure();
    }

    /// @notice Helper to test initialization reverts with different parameters
    function _testInitializationRevert(
        bytes4 expectedError,
        address owner_,
        string memory name_,
        string memory symbol_,
        uint8 originalUnderlyingTokenDecimals_,
        address nttManager_,
        bool gasTokenIsEth_
    ) internal returns (address) {
        bytes[] memory reinitializeCallData = new bytes[](1);
        reinitializeCallData[0] = abi.encodeCall(
            WethWormhole.reinitialize1,
            (owner_, name_, symbol_, originalUnderlyingTokenDecimals_, nttManager_, gasTokenIsEth_)
        );

        if (expectedError != bytes4(0)) {
            vm.expectRevert(expectedError);
        }
        wethWormhole = WethWormhole(
            payable(
                address(
                    TransparentUpgradeableProxy(
                        payable(
                            _proxify(
                                wethWormholeImpl,
                                proxyAdmin,
                                abi.encodeCall(WethWormhole.reinitialize, (reinitializeCallData))
                            )
                        )
                    )
                )
            )
        );

        return address(wethWormhole);
    }

    function test_initialize_revert_zeroOwner() public {
        _testInitializationRevert(
            CustomToken.InvalidOwner.selector,
            address(0),
            customTokenName,
            customTokenSymbol,
            originalUnderlyingTokenDecimals,
            nttManager,
            gasTokenIsEth
        );
    }

    function test_initialize_revert_emptyName() public {
        _testInitializationRevert(
            CustomToken.InvalidName.selector,
            owner,
            "",
            customTokenSymbol,
            originalUnderlyingTokenDecimals,
            nttManager,
            gasTokenIsEth
        );
    }

    function test_initialize_revert_emptySymbol() public {
        _testInitializationRevert(
            CustomToken.InvalidSymbol.selector,
            owner,
            customTokenName,
            "",
            originalUnderlyingTokenDecimals,
            nttManager,
            gasTokenIsEth
        );
    }

    function test_initialize_revert_zeroDecimals() public {
        _testInitializationRevert(
            CustomToken.InvalidOriginalUnderlyingTokenDecimals.selector,
            owner,
            customTokenName,
            customTokenSymbol,
            0,
            nttManager,
            gasTokenIsEth
        );
    }

    function test_initialize_revert_zeroNttManager() public {
        _testInitializationRevert(
            CustomToken.InvalidBridge.selector,
            owner,
            customTokenName,
            customTokenSymbol,
            originalUnderlyingTokenDecimals,
            address(0),
            gasTokenIsEth
        );
    }

    function test_init_gasTokenIsEth() public {
        address testWethWormholeProxy = _testInitializationRevert(
            bytes4(0),
            owner,
            "Test WETH",
            "tWETH",
            18,
            nttManager,
            false // gasTokenIsEth = false,
        );
        WethWormhole testWeth = WethWormhole(payable(testWethWormholeProxy));

        uint256 depositAmount = 1 ether;
        deal(address(this), depositAmount);

        vm.expectRevert(CustomTokenWethExtension.FunctionNotSupportedOnThisChain.selector);
        testWeth.deposit{value: depositAmount}();

        testWethWormholeProxy = _testInitializationRevert(
            bytes4(0),
            owner,
            "Test WETH",
            "tWETH",
            18,
            nttManager,
            true // gasTokenIsEth = true,
        );
        testWeth = WethWormhole(payable(testWethWormholeProxy));

        vm.expectRevert(CustomTokenWethExtension.FunctionNotEnabledOnThisChain.selector);
        testWeth.deposit{value: depositAmount}();
    }

    function test_init_wethFunctionalityEnabled() public {
        address testWethWormholeProxy =
            _testInitializationRevert(bytes4(0), owner, "Test WETH", "tWETH", 18, nttManager, gasTokenIsEth);
        WethWormhole testWeth = WethWormhole(payable(testWethWormholeProxy));

        uint256 depositAmount = 1 ether;
        deal(address(this), depositAmount);

        // weth functionality should be disabled by default
        assertFalse(testWeth.wethFunctionalityEnabled());
        vm.expectRevert(CustomTokenWethExtension.FunctionNotEnabledOnThisChain.selector);
        testWeth.deposit{value: depositAmount}();
    }

    function test_setNativeConverter_revert() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                wethWormhole.DEFAULT_ADMIN_ROLE()
            )
        );
        wethWormhole.setNativeConverter(address(1));

        vm.prank(owner);
        vm.expectRevert(CustomToken.FunctionNotSupportedWithThisBridgeProvider.selector);
        wethWormhole.setNativeConverter(address(1));
    }

    function test_setWethFunctionalityEnabled_revert() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                wethWormhole.DEFAULT_ADMIN_ROLE()
            )
        );
        wethWormhole.setWethFunctionalityEnabled(true);

        vm.prank(owner);
        vm.expectRevert(CustomToken.FunctionNotSupportedWithThisBridgeProvider.selector);
        wethWormhole.setWethFunctionalityEnabled(true);
    }
}
