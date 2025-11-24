// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test infrastructure
import {
    MockERC20Upgradeable,
    MockTokenWrappedBridgeUpgradeable,
    SecondaryChainBase
} from "test/base/secondary-chain/SecondaryChainBase.sol";

// Core contracts
import {GenericCustomTokenAgglayer} from "src/secondary-chain/agglayer/GenericCustomTokenAgglayer.sol";

// Mocks
import {MockNativeConverter} from "test/utils/mocks/MockNativeConverter.sol";

// OpenZeppelin
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Generic Custom Token Agglayer Test Base
/// @notice Base contract for testing GenericCustomTokenAgglayer as a standalone contract
abstract contract GenericCustomTokenAgglayerTestBase is SecondaryChainBase {
    // ========= MAIN CONTRACTS =========
    GenericCustomTokenAgglayer internal genericCustomTokenAgglayer;
    address internal genericCustomTokenAgglayerImpl;
    TransparentUpgradeableProxy existingGenericCustomTokenAgglayerProxy;

    // ========= MOCK CONTRACTS =========
    MockNativeConverter internal mockNativeConverter;

    /// @notice Deploy GenericCustomTokenAgglayer-specific infrastructure
    /// @dev Sets up tokens, bridge, and related contracts for GenericCustomTokenAgglayer testing
    function deployGenericCustomTokenAgglayerInfrastructure() internal {
        customTokenName = "Generic Custom Token Agglayer";
        customTokenSymbol = "gcTKN";
        customTokenDecimals = 18;

        deploySecondaryChainInfrastructure();
        deployGenericCustomTokenAgglayer();
        verifyGenericCustomTokenAgglayerSetup();
        setupLabels();
    }

    /// @notice Deploy Generic Custom Token Agglayer and related contracts
    function deployGenericCustomTokenAgglayer() internal {
        mockNativeConverter = new MockNativeConverter();

        MockTokenWrappedBridgeUpgradeable existingGenericCustomTokenAgglayerImpl =
            new MockTokenWrappedBridgeUpgradeable();
        existingGenericCustomTokenAgglayerProxy = TransparentUpgradeableProxy(
            payable(
                _proxify(
                    address(existingGenericCustomTokenAgglayerImpl),
                    proxyAdmin,
                    abi.encodeCall(
                        MockTokenWrappedBridgeUpgradeable.initialize,
                        (customTokenName, customTokenSymbol, customTokenDecimals, address(mockAgglayerBridge))
                    )
                )
            )
        );

        genericCustomTokenAgglayerImpl = address(new GenericCustomTokenAgglayer());
        stateBeforeInitialize = vm.snapshotState();

        bytes[] memory reinitializeCallData = new bytes[](3);
        reinitializeCallData[0] = abi.encodeCall(GenericCustomTokenAgglayer.reinitialize1, ());
        reinitializeCallData[1] = abi.encodeCall(
            GenericCustomTokenAgglayer.reinitialize2,
            (owner, customTokenDecimals, address(mockAgglayerBridge), address(mockNativeConverter))
        );
        reinitializeCallData[2] = abi.encodeCall(GenericCustomTokenAgglayer.reinitialize3, ());

        bytes memory genericCustomTokenAgglayerInitData =
            abi.encodeCall(GenericCustomTokenAgglayer.reinitialize, (reinitializeCallData));

        bytes memory genericCustomTokenAgglayerUpgradeData = abi.encodeCall(
            ITransparentUpgradeableProxy.upgradeToAndCall,
            (genericCustomTokenAgglayerImpl, genericCustomTokenAgglayerInitData)
        );

        vm.prank(_getProxyAdmin(address(existingGenericCustomTokenAgglayerProxy)));
        (bool success, bytes memory returndata) =
            address(existingGenericCustomTokenAgglayerProxy).call(genericCustomTokenAgglayerUpgradeData);
        if (!success) {
            assembly {
                revert(add(returndata, 32), mload(returndata))
            }
        }

        genericCustomTokenAgglayer = GenericCustomTokenAgglayer(address(existingGenericCustomTokenAgglayerProxy));
    }

    /// @notice Setup debugging labels
    function setupLabels() internal {
        vm.label(address(genericCustomTokenAgglayer), "GenericCustomTokenAgglayer");
        vm.label(address(genericCustomTokenAgglayerImpl), "GenericCustomTokenAgglayerImplementation");
    }

    /// @notice Helper to verify basic GenericCustomTokenAgglayer setup
    function verifyGenericCustomTokenAgglayerSetup() internal view {
        assertEq(genericCustomTokenAgglayer.name(), customTokenName);
        assertEq(genericCustomTokenAgglayer.symbol(), customTokenSymbol);
        assertEq(genericCustomTokenAgglayer.decimals(), customTokenDecimals);
        assertEq(genericCustomTokenAgglayer.bridge(), address(mockAgglayerBridge));
        assertEq(genericCustomTokenAgglayer.nativeConverter(), address(mockNativeConverter));
        assertTrue(genericCustomTokenAgglayer.hasRole(genericCustomTokenAgglayer.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(genericCustomTokenAgglayer.hasRole(genericCustomTokenAgglayer.PAUSER_ROLE(), owner));
        assertEq(genericCustomTokenAgglayer.totalSupply(), 0);
        assertFalse(genericCustomTokenAgglayer.paused());
    }
}
