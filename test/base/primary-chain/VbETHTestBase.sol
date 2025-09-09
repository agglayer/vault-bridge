// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test infrastructure
import {
    IERC20,
    MockAgglayerBridge,
    MockVault,
    PrimaryChainBase,
    VaultBridgeTokenPart2
} from "test/base/primary-chain/PrimaryChainBase.sol";

// Core contracts
import {VbETH} from "src/primary-chain/ethereum/vbETH/VbETH.sol";
import {VaultBridgeToken} from "src/primary-chain/VaultBridgeToken.sol";

// Mock contracts
import {MockWETH} from "test/utils/mocks/MockWETH.sol";

/// @title VbETH Test Base
/// @notice Base contract for testing VbETH
abstract contract VbETHTestBase is PrimaryChainBase {
    // ========= MAIN CONTRACTS =========
    VbETH internal vbETH;
    VaultBridgeTokenPart2 internal vbETHPart2;
    address internal vbETHImplementation;

    /// @notice Deploy Vault Bridge ETH-specific infrastructure
    /// @dev Sets up token, yield vault, and related contracts
    function deployVbETHInfrastructure() internal virtual {
        tokenName = "Vault Bridge ETH";
        tokenSymbol = "vbETH";
        tokenDecimals = 18;
        underlyingTokenName = "MockWETH";
        underlyingTokenSymbol = "mWETH";
        underlyingTokenDecimals = 18;
        minimumReservePercentage = MINIMUM_RESERVE_PERCENTAGE;
        migrationManagerInitialBalance = MIGRATION_MANAGER_INITIAL_BALANCE;
        yieldVaultMaxDeposit = MAX_DEPOSIT;
        yieldVaultMaxWithdraw = MAX_WITHDRAW;

        deployPrimaryChainInfrastructure();
        configureAgglayerBridge();
        deployVaultBridgeToken();
        configureMigrationManager(address(vbETH), migrationManagerInitialBalance);
        verifyVbETHSetup();
        setupLabels();
    }

    /// @notice Configure the Agglayer Bridge mock
    function configureAgglayerBridge() internal {
        MockAgglayerBridge(agglayerBridge).setGasTokenAddress(address(0));
        MockAgglayerBridge(agglayerBridge).setGasTokenNetwork(0);
    }

    /// @notice Deploy VbETH implementation and proxy
    function deployVaultBridgeToken() internal {
        // Deploy VbETH implementation
        vbETHImplementation = address(new VbETH());

        // Take snapshot before initialization
        stateBeforeInitialize = vm.snapshotState();

        // Create initialization parameters
        VaultBridgeToken.InitializationParameters memory initParams = VaultBridgeToken.InitializationParameters({
            owner: owner,
            name: tokenName,
            symbol: tokenSymbol,
            underlyingToken: underlyingToken,
            minimumReservePercentage: minimumReservePercentage,
            yieldVault: address(yieldVault),
            yieldRecipient: yieldRecipient,
            agglayerBridge: agglayerBridge,
            minimumYieldVaultDeposit: MINIMUM_YIELD_VAULT_DEPOSIT,
            migrationManager: migrationManagerAddr,
            yieldVaultMaximumSlippagePercentage: YIELD_VAULT_ALLOWED_SLIPPAGE,
            vaultBridgeTokenPart2: address(vbTokenPart2Implementation)
        });

        // Prepare initialization data
        bytes memory initData =
            abi.encodeCall(VbETH(vbETHImplementation).reinitialize1, (address(initializer), initParams));

        // Deploy proxy and initialize
        address vbETHProxy = _proxify(vbETHImplementation, address(this), initData);
        vbETH = VbETH(payable(vbETHProxy));

        // Set vbETHPart2 to point to the proxy (delegation pattern)
        vbETHPart2 = VaultBridgeTokenPart2(payable(address(vbETH)));
    }

    /// @notice Helper to verify basic VbETH setup
    function verifyVbETHSetup() internal view {
        assertEq(vbETH.allowance(address(vbETH), agglayerBridge), type(uint256).max);
        assertEq(vbETH.asset(), underlyingToken);
        assertEq(vbETH.balanceOf(address(this)), 0);
        assertEq(vbETH.decimals(), tokenDecimals);
        assertEq(vbETH.migrationManager(), migrationManagerAddr);
        assertEq(vbETH.minimumReservePercentage(), minimumReservePercentage);
        assertEq(vbETH.name(), tokenName);
        assertEq(vbETH.symbol(), tokenSymbol);
        assertEq(vbETH.totalSupply(), 0);
        assertEq(vbETH.yieldRecipient(), yieldRecipient);
        assertTrue(vbETH.hasRole(vbETH.DEFAULT_ADMIN_ROLE(), owner));
        assertEq(address(vbETH.yieldVault()), address(yieldVault));
        assertEq(address(vbETH.agglayerBridge()), agglayerBridge);
        assertEq(IERC20(underlyingToken).allowance(address(vbETH), address(yieldVault)), type(uint256).max);
        // Validate the gas token constraints for VbETH
        assertEq(MockAgglayerBridge(agglayerBridge).gasTokenAddress(), address(0));
        assertEq(MockAgglayerBridge(agglayerBridge).gasTokenNetwork(), 0);
    }

    /// @notice Setup debugging labels
    function setupLabels() internal {
        vm.label(address(vbETH), "vbETH (Proxy)");
        vm.label(vbETHImplementation, "vbETH Implementation");
    }

    // ========= HELPER FUNCTIONS =========

    /// @notice Helper function to deal WETH directly to an address
    /// @param _to Address to send WETH to
    /// @param _amount Amount of WETH to provide
    function _dealWETH(address _to, uint256 _amount) internal {
        deal(underlyingToken, _to, _amount);
    }
}
