// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test base
import {TestConstants} from "test/base/TestConstants.sol";

// Core contracts
import {GenericCustomTokenPolygon} from "src/secondary-chain/polygon/GenericCustomTokenPolygon.sol";
import {GenericVaultBridgeToken} from "src/primary-chain/ethereum/GenericVaultBridgeToken.sol";
import {MigrationManager} from "src/primary-chain/MigrationManager.sol";
import {VaultBridgeToken} from "src/primary-chain/VaultBridgeToken.sol";
import {VaultBridgeTokenInitializer} from "src/primary-chain/VaultBridgeTokenInitializer.sol";
import {VaultBridgeTokenPart2} from "src/primary-chain/VaultBridgeTokenPart2.sol";

// OpenZeppelin
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// Mocks
import {MockAgglayerBridge} from "test/utils/mocks/MockAgglayerBridge.sol";
import {MockChildChainManager} from "test/utils/mocks/MockChildChainManager.sol";
import {MockERC20} from "test/utils/mocks/MockERC20.sol";
import {MockRootChainManager} from "test/utils/mocks/MockRootChainManager.sol";
import {MockVault} from "test/utils/mocks/MockVault.sol";

/**
 * @title PolygonIntegrationTest
 * @notice Integration test for Polygon PoS bridge functionality with VaultBridgeToken
 * @dev This test simulates the complete flow for bridging vault bridge tokens to Polygon via PoS bridge:
 *      1. User deposits underlying asset into VaultBridgeToken to get vbToken on primary chain
 *      2. User manually calls depositFor on Polygon PoS RootChainManager to lock vbToken
 *      3. State sync mechanism mints wrapped vbToken (WvbToken) on Polygon chain
 *      4. User withdraws WvbToken on Polygon chain, burning the tokens
 *      5. User calls exit on Polygon PoS RootChainManager to unlock vbToken on primary chain
 */
contract PolygonIntegrationTest is TestConstants {
    // ===== TEST ADDRESSES =====
    address owner = makeAddr("owner");
    address sender = vm.addr(senderPrivateKey);

    // ===== CORE CONTRACTS =====
    MigrationManager migrationManager;
    MockAgglayerBridge mockAgglayerBridge;
    MockChildChainManager mockChildChainManager;
    MockRootChainManager mockRootChainManager;
    GenericVaultBridgeToken vbToken;
    VaultBridgeTokenPart2 vbTokenPart2;
    GenericCustomTokenPolygon customToken;

    // ===== EXTERNAL CONTRACTS =====
    MockVault vbTokenVault;
    MockERC20 underlyingAsset;

    function setUp() public virtual {
        _deployInfrastructure();
        _deployVaultBridgeToken();
        _deployCustomToken();
        _configureTokenMappings();
        _addLabels();
    }

    /// @notice Deploy core infrastructure contracts
    function _deployInfrastructure() internal {
        // Deploy mock underlying asset
        underlyingAsset = new MockERC20(UNDERLYING_ASSET_NAME, UNDERLYING_ASSET_SYMBOL, UNDERLYING_ASSET_DECIMALS);

        // Deploy vault for vbToken
        vbTokenVault = new MockVault(address(underlyingAsset));
        vbTokenVault.setMaxDeposit(MAX_DEPOSIT);
        vbTokenVault.setMaxWithdraw(MAX_WITHDRAW);

        // Deploy mock bridge managers
        mockRootChainManager = new MockRootChainManager();
        mockChildChainManager = new MockChildChainManager();

        // Deploy mock agglayer bridge
        mockAgglayerBridge = new MockAgglayerBridge();
        mockAgglayerBridge.setNetworkId(1); // Ethereum mainnet

        // Deploy migration manager
        MigrationManager migrationManagerImpl = new MigrationManager();
        bytes[] memory reinitializeCallData = new bytes[](2);
        reinitializeCallData[0] = abi.encodeCall(MigrationManager.reinitialize1, (owner, address(mockAgglayerBridge)));
        reinitializeCallData[1] = abi.encodeCall(MigrationManager.reinitialize2, (makeAddr("WrappedGasToken")));
        bytes memory migrationManagerInitData = abi.encodeCall(MigrationManager.reinitialize, (reinitializeCallData));
        migrationManager =
            MigrationManager(payable(_proxify(address(migrationManagerImpl), address(this), migrationManagerInitData)));
    }

    /// @notice Deploy VaultBridgeToken on primary chain
    function _deployVaultBridgeToken() internal {
        // Deploy vbToken part 2
        vbTokenPart2 = new VaultBridgeTokenPart2();

        // Deploy vbToken implementation
        GenericVaultBridgeToken vbTokenImpl = new GenericVaultBridgeToken();

        // Deploy initializer
        address initializer = address(new VaultBridgeTokenInitializer());

        // Prepare initialization parameters
        bytes[] memory initData = new bytes[](2);
        initData[0] = abi.encodeCall(
            vbTokenImpl.reinitialize1,
            (
                initializer,
                VaultBridgeToken.InitializationParameters({
                    owner: owner,
                    name: VBTOKEN_NAME,
                    symbol: VBTOKEN_SYMBOL,
                    underlyingToken: address(underlyingAsset),
                    minimumReservePercentage: MINIMUM_RESERVE_PERCENTAGE,
                    yieldVault: address(vbTokenVault),
                    yieldRecipient: owner,
                    agglayerBridge: address(mockAgglayerBridge),
                    minimumYieldVaultDeposit: MINIMUM_YIELD_VAULT_DEPOSIT_INTEGRATION,
                    migrationManager: address(migrationManager),
                    yieldVaultMaximumSlippagePercentage: 0.01e18, // 1% slippage
                    vaultBridgeTokenPart2: address(vbTokenPart2)
                })
            )
        );
        initData[1] = abi.encodeCall(vbTokenImpl.reinitialize2, ());

        // Deploy vbToken proxy
        bytes memory vbTokenInitData = abi.encodeCall(vbTokenImpl.reinitialize, (initData));
        vbToken = GenericVaultBridgeToken(payable(_proxify(address(vbTokenImpl), address(this), vbTokenInitData)));
        vbTokenPart2 = VaultBridgeTokenPart2(payable(address(vbToken)));
    }

    /// @notice Deploy CustomToken on secondary chain
    function _deployCustomToken() internal {
        // Deploy custom token implementation
        GenericCustomTokenPolygon customTokenImpl = new GenericCustomTokenPolygon();

        // Prepare initialization data for the custom token
        bytes[] memory customTokenInitData = new bytes[](1);
        customTokenInitData[0] = abi.encodeCall(
            GenericCustomTokenPolygon.reinitialize1,
            (
                owner, // owner_
                "Wrapped Vault Bridge Underlying Asset", // name_
                "WvbUAT", // symbol_
                UNDERLYING_ASSET_DECIMALS, // originalUnderlyingTokenDecimals_
                address(mockChildChainManager) // childChainManager_
            )
        );

        // Deploy custom token proxy
        customToken = GenericCustomTokenPolygon(
            _proxify(
                address(customTokenImpl),
                address(this),
                abi.encodeCall(GenericCustomTokenPolygon.reinitialize, (customTokenInitData))
            )
        );
    }

    /// @notice Configure token mappings between chains
    function _configureTokenMappings() internal {
        // Map root token (vbToken) to child token (customToken) on root chain manager
        mockRootChainManager.mapToken(
            address(vbToken), // rootToken
            address(customToken), // childToken
            keccak256("ERC20") // tokenType
        );

        // Map child token (customToken) to root token (vbToken) on child chain manager
        mockChildChainManager.mapToken(
            address(vbToken), // rootToken
            address(customToken) // childToken
        );
    }

    /// @notice Add labels for debugging
    function _addLabels() internal {
        vm.label(address(customToken), "Custom Token");
        vm.label(address(migrationManager), "Migration Manager");
        vm.label(address(mockAgglayerBridge), "Mock Agglayer Bridge");
        vm.label(address(mockChildChainManager), "Mock Child Chain Manager");
        vm.label(address(mockRootChainManager), "Mock Root Chain Manager");
        vm.label(address(owner), "Owner");
        vm.label(address(sender), "Sender");
        vm.label(address(underlyingAsset), "Mock Underlying Asset");
        vm.label(address(vbToken), "VB Token");
        vm.label(address(vbTokenVault), "VB Token Vault");
    }

    // Basic test to verify setup
    function test_setupVerification() public view {
        // Verify vbToken setup
        assertEq(address(vbToken.underlyingToken()), address(underlyingAsset));
        assertEq(vbToken.name(), VBTOKEN_NAME);
        assertEq(vbToken.symbol(), VBTOKEN_SYMBOL);
        assertEq(vbToken.decimals(), VBTOKEN_DECIMALS);

        // Verify root chain mapping
        address mappedChildToken = mockRootChainManager.rootToChildToken(address(vbToken));
        assertEq(mappedChildToken, address(customToken), "Root to child mapping incorrect");

        // Verify secondary chain setup
        assertEq(customToken.name(), "Wrapped Vault Bridge Underlying Asset");
        assertEq(customToken.symbol(), "WvbUAT");
        assertEq(customToken.decimals(), UNDERLYING_ASSET_DECIMALS);
        assertEq(customToken.bridge(), address(mockChildChainManager)); // bridge is child chain manager
        assertTrue(customToken.hasRole(customToken.DEFAULT_ADMIN_ROLE(), owner));

        // Verify child chain mapping
        address mappedRootToken = mockChildChainManager.rootToChildToken(address(vbToken));
        assertEq(mappedRootToken, address(customToken), "Child to root mapping incorrect");
    }

    // ===== BRIDGING TESTS =====

    function test_depositAndBridge() public {
        uint256 depositAmount = 1000 * 10 ** UNDERLYING_ASSET_DECIMALS;

        // Step 1: User deposits underlying asset into vbToken

        // Fund sender with underlying asset
        underlyingAsset.mint(sender, depositAmount);

        // Approve vbToken to spend underlying asset
        vm.prank(sender);
        underlyingAsset.approve(address(vbToken), depositAmount);

        // Deposit underlying asset to get vbToken
        vm.prank(sender);
        uint256 vbTokenAmount = vbToken.deposit(depositAmount, sender);

        assertEq(vbToken.balanceOf(sender), vbTokenAmount);
        assertGt(vbTokenAmount, 0, "Should receive vbTokens");

        // Step 2: User bridges vbToken via Polygon PoS (manual deposit + depositFor)
        // Note: This uses the Polygon PoS bridge directly, not the agglayer bridge
        _bridgeToSecondaryChain(sender, vbTokenAmount);
    }

    function test_withdrawAndExit() public {
        uint256 vbTokenAmount = 1000 * 10 ** UNDERLYING_ASSET_DECIMALS;

        // Step 1: Setup - Bridge tokens to secondary chain first
        _setupTokensOnSecondaryChain(sender, vbTokenAmount);

        // Verify initial state
        assertEq(customToken.balanceOf(sender), vbTokenAmount, "Should have WvbUAT on secondary chain");
        assertEq(
            vbToken.balanceOf(address(mockRootChainManager)), vbTokenAmount, "Root chain manager should hold vbTokens"
        );

        // Step 2: User withdraws WvbUAT from secondary chain and exits on primary chain
        _bridgeToPrimaryChain(sender, vbTokenAmount);

        // Verify final state
        assertEq(customToken.balanceOf(sender), 0, "Should have no WvbUAT left");
        assertEq(vbToken.balanceOf(sender), vbTokenAmount, "Should have vbTokens back on primary chain");
    }

    // ===== HELPER FUNCTIONS =====

    /// @notice Simulates bridging from primary to secondary chain via Polygon PoS bridge
    /// @dev This is the manual process: user must first deposit to get vbTokens,
    ///      then manually call depositFor on the root chain manager
    /// @param user The user bridging tokens
    /// @param amount The amount of vbTokens to bridge
    function _bridgeToSecondaryChain(address user, uint256 amount) internal {
        // Step 1: User calls depositFor on MockRootChainManager

        vm.prank(user);
        vbToken.approve(address(mockRootChainManager), amount);

        // Encode the deposit data
        bytes memory depositData = abi.encode(amount);

        // Call depositFor on MockRootChainManager
        vm.prank(user);
        mockRootChainManager.depositFor(user, address(vbToken), depositData);

        // Step 2: Simulate state sync - ChildChainManager calls deposit on secondary chain
        _simulateDepositFromPrimaryChain(user, address(vbToken), amount);
    }

    /// @notice Simulates the state sync mechanism for deposits
    /// @param user The user receiving tokens
    /// @param amount The amount to mint
    function _simulateDepositFromPrimaryChain(address user, address rootToken, uint256 amount) internal {
        // Simulate ChildChainManager calling deposit on the custom token
        bytes memory depositData = abi.encode(user, rootToken, amount);
        mockChildChainManager.onStateReceive(0, depositData);

        assertEq(customToken.balanceOf(user), amount, "WvbUAT should be minted");
    }

    /// @notice Setup tokens on secondary chain for testing reverse flow
    /// @param user The user to setup tokens for
    /// @param amount The amount of underlying tokens to bridge
    function _setupTokensOnSecondaryChain(address user, uint256 amount) internal {
        // Fund user with underlying asset
        underlyingAsset.mint(user, amount);

        // Approve vbToken to spend underlying asset
        vm.prank(user);
        underlyingAsset.approve(address(vbToken), amount);

        // Deposit underlying asset to get vbToken
        vm.prank(user);
        uint256 vbTokenAmount = vbToken.deposit(amount, user);

        // Bridge vbToken to secondary chain
        _bridgeToSecondaryChain(user, vbTokenAmount);
    }

    /// @notice Simulates bridging from secondary to primary chain via Polygon PoS bridge
    /// @dev This is the reverse process: user withdraws WvbUAT, then exits on primary chain
    /// @param user The user bridging tokens
    /// @param amount The amount of WvbUAT to bridge back
    function _bridgeToPrimaryChain(address user, uint256 amount) internal {
        // Step 1: User withdraws WvbUAT on secondary chain (burns tokens)
        vm.prank(user);
        customToken.withdraw(amount);

        // Verify tokens were burned
        assertEq(customToken.balanceOf(user), 0, "WvbUAT should be burned");

        // Step 2: Simulate exit on primary chain (normally requires merkle proof)
        // In real scenario, user would submit proof and call exit on RootChainManager
        mockRootChainManager.exit(user, address(vbToken), amount);
    }
}
