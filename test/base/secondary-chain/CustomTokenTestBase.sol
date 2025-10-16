// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test infrastructure
import {
    MockERC20Upgradeable,
    SecondaryChainBase,
    TestHarnessCustomToken
} from "test/base/secondary-chain/SecondaryChainBase.sol";

// OpenZeppelin
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Custom Token Test Base
/// @notice Base contract for testing CustomToken as a standalone contract
abstract contract CustomTokenTestBase is SecondaryChainBase {
    // ========= MAIN CONTRACTS =========
    TestHarnessCustomToken internal customTokenHarness;
    address internal customTokenImpl;
    TransparentUpgradeableProxy existingCustomTokenProxy;

    /// @notice Deploy CustomToken-specific infrastructure
    /// @dev Sets up tokens, bridge, and related contracts for CustomToken testing
    function deployCustomTokenInfrastructure() internal {
        customTokenName = "Custom Token";
        customTokenSymbol = "cTKN";
        customTokenDecimals = 18;

        deploySecondaryChainInfrastructure();
        deployCustomToken();
        verifyCustomTokenSetup();
        setupLabels();
    }

    /// @notice Deploy Custom Token and related contracts
    function deployCustomToken() internal {
        MockERC20Upgradeable existingCustomTokenImpl = new MockERC20Upgradeable();
        existingCustomTokenProxy = TransparentUpgradeableProxy(
            payable(
                _proxify(
                    address(existingCustomTokenImpl),
                    proxyAdmin,
                    abi.encodeCall(MockERC20Upgradeable.initialize, (customTokenName, customTokenSymbol))
                )
            )
        );

        customTokenImpl = address(new TestHarnessCustomToken());
        stateBeforeInitialize = vm.snapshotState();

        bytes[] memory reinitializeCallData = new bytes[](3);
        reinitializeCallData[0] = abi.encodeCall(TestHarnessCustomToken.reinitialize1, ());
        reinitializeCallData[1] = abi.encodeCall(
            TestHarnessCustomToken.reinitialize2,
            (owner, customTokenDecimals, address(mockAgglayerBridge), dummyNativeConverter)
        );
        reinitializeCallData[2] = abi.encodeCall(TestHarnessCustomToken.reinitialize3, ());

        bytes memory customTokenInitData = abi.encodeCall(TestHarnessCustomToken.reinitialize, (reinitializeCallData));

        bytes memory customTokenUpgradeData =
            abi.encodeCall(ITransparentUpgradeableProxy.upgradeToAndCall, (customTokenImpl, customTokenInitData));

        vm.prank(_getProxyAdmin(address(existingCustomTokenProxy)));
        (address(existingCustomTokenProxy).call(customTokenUpgradeData));

        customTokenHarness = TestHarnessCustomToken(address(existingCustomTokenProxy));
    }

    /// @notice Setup debugging labels
    function setupLabels() internal {
        vm.label(address(customToken), "CustomToken");
        vm.label(address(customTokenImpl), "CustomTokenImplementation");
    }

    /// @notice Helper to verify basic CustomToken setup
    function verifyCustomTokenSetup() internal view {
        assertEq(customTokenHarness.name(), customTokenName);
        assertEq(customTokenHarness.symbol(), customTokenSymbol);
        assertEq(customTokenHarness.decimals(), customTokenDecimals);
        assertEq(customTokenHarness.bridge(), address(mockAgglayerBridge));
        assertEq(customTokenHarness.nativeConverter(), dummyNativeConverter);
        assertTrue(customTokenHarness.hasRole(customTokenHarness.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(customTokenHarness.hasRole(customTokenHarness.PAUSER_ROLE(), owner));
        assertEq(customTokenHarness.totalSupply(), 0);
        assertFalse(customTokenHarness.paused());
    }
}
