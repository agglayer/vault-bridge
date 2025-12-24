// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test infrastructure
import {
    IERC20,
    MockERC20,
    MockVault,
    PrimaryChainBase,
    TestHarnessVaultBridgeToken,
    VaultBridgeTokenPart2
} from "test/base/primary-chain/PrimaryChainBase.sol";

// Core contracts
import {VaultBridgeToken} from "src/primary-chain/VaultBridgeToken.sol";

/// @title VaultBridgeToken Test Base
/// @notice Base contract for testing VaultBridgeToken and VaultBridgeTokenPart2 as standalone contracts
abstract contract VaultBridgeTokenTestBase is PrimaryChainBase {
    // ========= MAIN CONTRACTS =========
    TestHarnessVaultBridgeToken internal vbToken;
    VaultBridgeTokenPart2 internal vbTokenPart2;
    address internal vbTokenImplementation;

    /// @notice Deploy VaultBridgeToken-specific infrastructure
    /// @dev Sets up token, yield vault, and related contracts
    function deployVaultBridgeTokenInfrastructure() internal {
        tokenName = "Vault Bridge Token";
        tokenSymbol = "vbTOKEN";
        tokenDecimals = 6;
        underlyingTokenName = "MockERC20";
        underlyingTokenSymbol = "mERC20";
        underlyingTokenDecimals = 6;
        minimumReservePercentage = MINIMUM_RESERVE_PERCENTAGE;
        migrationManagerInitialBalance = MIGRATION_MANAGER_INITIAL_BALANCE;
        yieldVaultMaxDeposit = MAX_DEPOSIT;
        yieldVaultMaxWithdraw = MAX_WITHDRAW;

        deployPrimaryChainInfrastructure();
        deployVaultBridgeToken();
        configureMigrationManager(address(vbToken), migrationManagerInitialBalance);
        verifyVaultBridgeTokenSetup();
        setupLabels();
    }

    /// @notice Deploy VaultBridgeToken harness with proxy setup
    /// @dev Creates a complete VaultBridgeToken deployment ready for testing
    function deployVaultBridgeToken() internal {
        // Deploy the VaultBridgeToken implementation
        vbTokenImplementation = address(new TestHarnessVaultBridgeToken());

        // Take snapshot before initialization
        stateBeforeInitialize = vm.snapshotState();

        // Get initialization parameters
        VaultBridgeToken.InitializationParameters memory initParams = VaultBridgeToken.InitializationParameters({
            owner: owner,
            name: tokenName,
            symbol: tokenSymbol,
            underlyingToken: underlyingToken,
            minimumReservePercentage: MINIMUM_RESERVE_PERCENTAGE,
            yieldVault: address(yieldVault),
            yieldRecipient: yieldRecipient,
            agglayerBridge: agglayerBridge,
            minimumYieldVaultDeposit: MINIMUM_YIELD_VAULT_DEPOSIT,
            migrationManager: migrationManagerAddr,
            yieldVaultMaximumSlippagePercentage: YIELD_VAULT_ALLOWED_SLIPPAGE,
            vaultBridgeTokenPart2: address(vbTokenPart2Implementation)
        });

        // Prepare initialization data
        // Initialize the proxy through the reinitialize1 function
        bytes[] memory reinitializeCallData = new bytes[](2);
        reinitializeCallData[0] =
            abi.encodeCall(TestHarnessVaultBridgeToken.reinitialize1, (address(initializer), initParams));
        reinitializeCallData[1] = abi.encodeCall(TestHarnessVaultBridgeToken.reinitialize2, ());

        bytes memory vaultBridgeInitData =
            abi.encodeCall(TestHarnessVaultBridgeToken.reinitialize, (reinitializeCallData));

        // Deploy proxy and initialize
        address vbTokenProxy = _proxify(vbTokenImplementation, address(this), vaultBridgeInitData);
        vbToken = TestHarnessVaultBridgeToken(payable(vbTokenProxy));

        // Set vbTokenPart2 to point to the proxy (delegation pattern)
        vbTokenPart2 = VaultBridgeTokenPart2(payable(address(vbToken)));
    }

    /// @notice Helper to verify basic VaultBridgeToken setup
    function verifyVaultBridgeTokenSetup() internal view {
        assertEq(vbToken.allowance(address(vbToken), agglayerBridge), type(uint256).max);
        assertEq(vbToken.asset(), underlyingToken);
        assertEq(vbToken.decimals(), tokenDecimals);
        assertEq(vbToken.migrationManager(), migrationManagerAddr);
        assertEq(vbToken.minimumReservePercentage(), minimumReservePercentage);
        assertEq(vbToken.name(), tokenName);
        assertEq(vbToken.symbol(), tokenSymbol);
        assertEq(vbToken.yieldRecipient(), yieldRecipient);
        assertEq(address(vbToken.yieldVault()), address(yieldVault));
        assertEq(address(vbToken.agglayerBridge()), agglayerBridge);
        assertTrue(vbToken.hasRole(vbToken.DEFAULT_ADMIN_ROLE(), owner));
        assertEq(IERC20(underlyingToken).allowance(address(vbToken), address(yieldVault)), type(uint256).max);
    }

    /// @notice Setup debugging labels
    function setupLabels() internal {
        vm.label(address(vbToken), "VaultBridgeToken (Proxy)");
        vm.label(vbTokenImplementation, "VaultBridgeToken Implementation");
    }

    // ========= HELPER FUNCTIONS =========

    /// @notice Helper to deal tokens and approve spending
    /// @param _token The token to deal
    /// @param _to The recipient address
    /// @param _amount The amount to deal
    /// @param _spender The address to approve for spending
    function _dealAndApprove(address _token, address _to, uint256 _amount, address _spender) internal {
        deal(underlyingToken, _to, _amount);
        vm.prank(_to);
        IERC20(_token).approve(_spender, _amount);
    }

    /// @notice Calculate the withdrawable amount from the vault
    /// @param _amount The total amount to withdraw
    /// @return The maximum amount that can be withdrawn
    function _calculateWithdrawableAmount(uint256 _amount) internal view returns (uint256) {
        return _amount - vbToken.reservedAssets() > MAX_WITHDRAW ? MAX_WITHDRAW : _amount - vbToken.reservedAssets();
    }
}
