// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test infrastructure
import {SecondaryChainBase} from "test/base/secondary-chain/SecondaryChainBase.sol";

// Core contracts
import {GenericCustomTokenPolygon} from "src/secondary-chain/polygon/GenericCustomTokenPolygon.sol";

// OpenZeppelin
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Generic Custom Token Polygon Test Base
/// @notice Base contract for testing GenericCustomTokenPolygon as a standalone contract
abstract contract GenericCustomTokenPolygonTestBase is SecondaryChainBase {
    // ========= MAIN CONTRACTS =========
    GenericCustomTokenPolygon internal genericCustomTokenPolygon;
    address internal genericCustomTokenPolygonImpl;
    TransparentUpgradeableProxy existingGenericCustomTokenPolygonProxy;

    // ========= VARIABLES =========
    address internal childChainManager = makeAddr("ChildChainManager");
    uint8 internal originalUnderlyingTokenDecimals = 18;

    /// @notice Deploy GenericCustomTokenPolygon-specific infrastructure
    /// @dev Sets up tokens, bridge, and related contracts for GenericCustomTokenPolygon testing
    function deployGenericCustomTokenPolygonInfrastructure() internal {
        customTokenName = "Generic Custom Token Polygon";
        customTokenSymbol = "gcTKN";
        customTokenDecimals = 18;

        deploySecondaryChainInfrastructure();
        deployGenericCustomTokenPolygon();
        verifyGenericCustomTokenPolygonSetup();
        setupLabels();
    }

    /// @notice Deploy Generic Custom Token Polygon and related contracts
    function deployGenericCustomTokenPolygon() internal {
        genericCustomTokenPolygonImpl = address(new GenericCustomTokenPolygon());

        bytes[] memory reinitializeCallData = new bytes[](1);
        reinitializeCallData[0] = abi.encodeCall(
            GenericCustomTokenPolygon.reinitialize1,
            (owner, customTokenName, customTokenSymbol, originalUnderlyingTokenDecimals, childChainManager)
        );

        bytes memory genericCustomTokenPolygonInitData =
            abi.encodeCall(GenericCustomTokenPolygon.reinitialize, (reinitializeCallData));

        existingGenericCustomTokenPolygonProxy = TransparentUpgradeableProxy(
            payable(_proxify(genericCustomTokenPolygonImpl, proxyAdmin, genericCustomTokenPolygonInitData))
        );

        genericCustomTokenPolygon = GenericCustomTokenPolygon(address(existingGenericCustomTokenPolygonProxy));
    }

    /// @notice Setup debugging labels
    function setupLabels() internal {
        vm.label(address(genericCustomTokenPolygon), "GenericCustomTokenPolygon");
        vm.label(address(genericCustomTokenPolygonImpl), "GenericCustomTokenPolygonImplementation");
        vm.label(childChainManager, "MockChildChainManager");
    }

    /// @notice Helper to verify basic GenericCustomTokenPolygon setup
    function verifyGenericCustomTokenPolygonSetup() internal view {
        assertEq(genericCustomTokenPolygon.name(), customTokenName);
        assertEq(genericCustomTokenPolygon.symbol(), customTokenSymbol);
        assertEq(genericCustomTokenPolygon.decimals(), customTokenDecimals);
        assertEq(genericCustomTokenPolygon.bridge(), childChainManager);
        assertTrue(genericCustomTokenPolygon.hasRole(genericCustomTokenPolygon.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(genericCustomTokenPolygon.hasRole(genericCustomTokenPolygon.PAUSER_ROLE(), owner));
        assertEq(genericCustomTokenPolygon.totalSupply(), 0);
        assertFalse(genericCustomTokenPolygon.paused());
    }

    /// @notice Helper function to simulate deposit through ChildChainManager
    /// @param user The user to deposit tokens for
    /// @param amount The amount to deposit
    function simulateDeposit(address user, uint256 amount) internal {
        bytes memory depositData = abi.encode(amount);
        vm.prank(childChainManager);
        genericCustomTokenPolygon.deposit(user, depositData);
    }

    /// @notice Helper function to simulate withdraw by user
    /// @param user The user withdrawing tokens
    /// @param amount The amount to withdraw
    function simulateWithdraw(address user, uint256 amount) internal {
        vm.prank(user);
        genericCustomTokenPolygon.withdraw(amount);
    }
}
