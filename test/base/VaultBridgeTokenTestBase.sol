// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import {PrimaryChainBase} from "test/base/PrimaryChainBase.sol";

// Core contracts
import {VaultBridgeToken} from "src/primary-chain/VaultBridgeToken.sol";
import {VaultBridgeTokenPart2} from "src/primary-chain/VaultBridgeTokenPart2.sol";
import {VaultBridgeTokenInitializer} from "src/primary-chain/VaultBridgeTokenInitializer.sol";

// OpenZeppelin
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title VaultBridgeToken Harness
/// @notice A customizable implementation of VaultBridgeToken for testing purposes
/// @dev This provides the same functionality as GenericVaultBridgeToken but is chain-agnostic
contract TestHarnessVaultBridgeToken is VaultBridgeToken {
    constructor() {
        _disableInitializers();
    }

    function reinitialize1(address initializer_, VaultBridgeToken.InitializationParameters calldata initParams)
        external
        whenNotPaused
        reinitializer(1)
        nonReentrant
    {
        // Initialize the base implementation.
        __VaultBridgeToken_init(initializer_, initParams);
    }

    function reinitialize2() external whenNotPaused reinitializer(2) nonReentrant {
        _incrementGlobalInitializationCounter(1);
        _incrementGlobalInitializationCounter(2);

        __VaultBridgeToken_init2();
    }

    /// @inheritdoc VaultBridgeToken
    function _VAULT_BRIDGE_TOKEN_INIT_2_COMPATIBLE() internal pure override {}
}

/// @title VaultBridgeToken Test Base
/// @notice Base contract for testing VaultBridgeToken and VaultBridgeTokenPart2 as standalone contracts
/// @dev Provides deployment and setup specifically for VaultBridgeToken testing
abstract contract VaultBridgeTokenTestBase is PrimaryChainBase {
    // ========= VAULT BRIDGE TOKEN CONTRACTS =========
    TestHarnessVaultBridgeToken internal vbToken;
    VaultBridgeTokenPart2 internal vbTokenPart2;
    address internal vbTokenImplementation;

    /// @notice Deploy VaultBridgeToken harness with proxy setup
    /// @dev Creates a complete VaultBridgeToken deployment ready for testing
    /// @param useFork Whether to use mainnet fork (default: false for unit tests)
    function deployVaultBridgeTokenHarness(bool useFork) internal {
        // Deploy primary chain infrastructure first (without fork for unit tests)
        deployPrimaryChainInfrastructure(useFork);

        // Deploy the VaultBridgeToken implementation
        TestHarnessVaultBridgeToken vbTokenImpl = new TestHarnessVaultBridgeToken();
        vbTokenImplementation = address(vbTokenImpl);

        // Take snapshot before initialization
        stateBeforeInitialize = vm.snapshotState();

        // Get initialization parameters
        VaultBridgeToken.InitializationParameters memory initParams = VaultBridgeToken.InitializationParameters({
            owner: owner,
            name: tokenName,
            symbol: tokenSymbol,
            underlyingToken: asset,
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
        bytes memory initData = abi.encodeCall(vbTokenImpl.reinitialize1, (address(initializer), initParams));

        // Deploy proxy and initialize
        address vbTokenProxy = _proxify(address(vbTokenImpl), address(this), initData);
        vbToken = TestHarnessVaultBridgeToken(payable(vbTokenProxy));

        // Set vbTokenPart2 to point to the proxy (delegation pattern)
        vbTokenPart2 = VaultBridgeTokenPart2(payable(address(vbToken)));

        // Setup additional infrastructure
        _setupVaultBridgeTokenInfrastructure();

        // Setup debugging labels
        _setupVaultBridgeTokenLabels();
    }

    /// @notice Setup additional infrastructure for VaultBridgeToken
    function _setupVaultBridgeTokenInfrastructure() internal {
        // Fund migration manager for tests
        _fundMigrationManager(migrationManagerAddr, 10000000 ether);

        // Approve migration manager to spend tokens on behalf of the vault
        vm.prank(migrationManagerAddr);
        IERC20(asset).approve(address(vbToken), 10000000 ether);

        // Verify the basic setup
        _verifyVaultBridgeTokenSetup(vbToken);

        // Verify allowances are set correctly
        assertEq(vbToken.allowance(address(vbToken), agglayerBridge), type(uint256).max);
        assertEq(IERC20(asset).allowance(address(vbToken), address(yieldVault)), type(uint256).max);
    }

    /// @notice Setup debugging labels specific to VaultBridgeToken
    function _setupVaultBridgeTokenLabels() internal {
        vm.label(address(vbToken), "VaultBridgeToken (Proxy)");
        vm.label(vbTokenImplementation, "VaultBridgeToken Implementation");
        vm.label(address(vbTokenPart2), "VaultBridgeTokenPart2 (Proxy)");
    }

    /// @notice Helper to reset to pre-initialization state
    /// @dev Useful for tests that need to test different initialization scenarios
    function resetToPreInitialization() internal {
        vm.revertToState(stateBeforeInitialize);
    }

    /// @notice Calculate expected reserve assets after deposit
    /// @param depositAmount The amount being deposited
    /// @param vaultMaxDeposit The maximum the vault can accept
    /// @return reserveAssets The expected amount that will be kept in reserve
    function _calculateReserveAssets(uint256 depositAmount, uint256 vaultMaxDeposit)
        internal
        view
        virtual
        returns (uint256)
    {
        uint256 amountToStake = depositAmount > vaultMaxDeposit ? vaultMaxDeposit : depositAmount;
        uint256 reserveAssets = depositAmount - amountToStake;

        // Add minimum reserve calculation if needed
        uint256 minimumReserve = calculatePercentage(depositAmount, minimumReservePercentage);
        if (reserveAssets < minimumReserve) {
            reserveAssets = minimumReserve > depositAmount ? depositAmount : minimumReserve;
        }

        return reserveAssets;
    }

    /// @notice Test helper to verify pause/unpause functionality
    /// @param admin The admin address that should be able to pause/unpause
    /// @param target The contract to test
    /// @param callData The function call to test while paused
    function _testPauseUnpause(address admin, address target, bytes memory callData) internal {
        // Test pause
        vm.prank(admin);
        vbTokenPart2.pause();

        // Verify paused
        assertTrue(vbToken.paused());

        // Test that operations fail when paused
        (bool success,) = target.call(callData);
        assertFalse(success);

        // Test unpause
        vm.prank(admin);
        vbTokenPart2.unpause();

        // Verify unpaused
        assertFalse(vbToken.paused());
    }

    /// @notice Helper to deal tokens and approve spending
    /// @param token The token to deal
    /// @param to The recipient address
    /// @param amount The amount to deal
    /// @param spender The address to approve for spending
    function _dealAndApprove(address token, address to, uint256 amount, address spender) internal {
        if (token == asset && address(mockAsset) != address(0)) {
            // Use mock token minting
            mockAsset.mint(to, amount);
        } else {
            // Use deal for real tokens or non-asset tokens
            deal(token, to, amount);
        }

        vm.prank(to);
        IERC20(token).approve(spender, amount);
    }

    function _calculateWithdrawableAmount(uint256 amount) internal view returns (uint256) {
        return amount - vbToken.reservedAssets() > MAX_WITHDRAW ? MAX_WITHDRAW : amount - vbToken.reservedAssets();
    }
}
