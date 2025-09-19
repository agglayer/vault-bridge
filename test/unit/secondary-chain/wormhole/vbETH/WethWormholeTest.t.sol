// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test Base
import {WethWormholeTestBase, TransparentUpgradeableProxy} from "test/base/secondary-chain/WethWormholeTestBase.sol";

// Core contracts
import {WethWormhole} from "src/secondary-chain/wormhole/vbETH/WethWormhole.sol";
import {CustomToken} from "src/secondary-chain/CustomToken.sol";
import {CustomTokenWethExtension} from "src/secondary-chain/CustomTokenWethExtension.sol";

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
        if (expectedError != bytes4(0)) {
            vm.expectRevert(expectedError);
        }

        TransparentUpgradeableProxy newProxy = TransparentUpgradeableProxy(
            payable(
                _proxify(
                    wethWormholeImpl,
                    proxyAdmin,
                    abi.encodeCall(
                        WethWormhole.reinitialize1,
                        (owner_, name_, symbol_, originalUnderlyingTokenDecimals_, nttManager_, gasTokenIsEth_)
                    )
                )
            )
        );
        return address(newProxy);
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

    function test_init_gasTokenIsEth_true() public {
        address testWethWormholeProxy = _testInitializationRevert(
            bytes4(0),
            owner,
            "Test WETH",
            "tWETH",
            18,
            nttManager,
            true // gasTokenIsEth = true
        );
        WethWormhole testWeth = WethWormhole(payable(testWethWormholeProxy));

        // Test that deposit works (only works when gasTokenIsEth=true)
        uint256 depositAmount = 1 ether;
        deal(address(this), depositAmount);

        testWeth.deposit{value: depositAmount}();
        assertEq(testWeth.balanceOf(address(this)), depositAmount);
    }

    function test_init_wethFunctionalityEnabled_true() public {
        address testWethWormholeProxy = _testInitializationRevert(
            bytes4(0),
            owner,
            "Test WETH",
            "tWETH",
            18,
            nttManager,
            true // gasTokenIsEth = true & by extension wethFunctionalityEnabled = true
        );
        WethWormhole testWeth = WethWormhole(payable(testWethWormholeProxy));

        // Verify wethFunctionalityEnabled is set correctly
        assertTrue(testWeth.wethFunctionalityEnabled());

        // Test that deposit works when wethFunctionalityEnabled=true
        uint256 depositAmount = 1 ether;
        deal(address(this), depositAmount);

        testWeth.deposit{value: depositAmount}();
        assertEq(testWeth.balanceOf(address(this)), depositAmount);
    }

    function test_init_wethFunctionalityEnabled_false() public {
        address testWethWormholeProxy = _testInitializationRevert(
            bytes4(0),
            owner,
            "Test WETH",
            "tWETH",
            18,
            nttManager,
            false // gasTokenIsEth = false & by externsion wethFunctionalityEnabled = false
        );
        WethWormhole testWeth = WethWormhole(payable(testWethWormholeProxy));

        // Verify wethFunctionalityEnabled is set correctly
        assertFalse(testWeth.wethFunctionalityEnabled());

        // Test that deposit reverts when wethFunctionalityEnabled=false
        uint256 depositAmount = 1 ether;
        deal(address(this), depositAmount);

        vm.expectRevert(CustomTokenWethExtension.FunctionNotEnabledOnThisChain.selector);
        testWeth.deposit{value: depositAmount}();
    }
}
