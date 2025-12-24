// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import {TestConstants} from "test/base/TestConstants.sol";

// Core contracts
import {MigrationManager} from "src/primary-chain/MigrationManager.sol";
import {VaultBridgeToken} from "src/primary-chain/VaultBridgeToken.sol";
import {VaultBridgeTokenPart2} from "src/primary-chain/VaultBridgeTokenPart2.sol";
import {VaultBridgeTokenInitializer} from "src/primary-chain/VaultBridgeTokenInitializer.sol";

// Mock contracts
import {MockAgglayerBridge} from "test/utils/mocks/MockAgglayerBridge.sol";
import {MockERC20} from "test/utils/mocks/MockERC20.sol";
import {MockVault} from "test/utils/mocks/MockVault.sol";

// OpenZeppelin
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title VaultBridgeToken Harness
/// @notice A customizable implementation of VaultBridgeToken for testing purposes
/// @dev This provides the same functionality as GenericVaultBridgeToken
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
        __VaultBridgeToken_init1(initializer_, initParams);
    }

    function reinitialize2() external whenNotPaused reinitializer(2) nonReentrant {
        _incrementGlobalInitializationCounter(1);
        _incrementGlobalInitializationCounter(2);

        __VaultBridgeToken_init2();
    }

    function reinitialize(bytes[] calldata reinitializeData) external {
        bytes4[] memory reinitializeSelectors = new bytes4[](2);

        reinitializeSelectors[0] = this.reinitialize1.selector;
        reinitializeSelectors[1] = this.reinitialize2.selector;

        _reinitialize(reinitializeSelectors, reinitializeData);
    }

    /// @inheritdoc VaultBridgeToken
    function _VAULT_BRIDGE_TOKEN_INIT_2_COMPATIBLE() internal pure override {}
}

/// @title Primary Chain Base
/// @notice Base contract for setting up Primary Chain infrastructure in tests
abstract contract PrimaryChainBase is TestConstants {
    // ========= VAULT BRIDGE VERSION =========
    string internal constant VAULT_BRIDGE_PROTOCOL = "1.0.0";

    // ========= STATE VARIABLES =========
    address internal underlyingToken;
    string internal underlyingTokenName;
    string internal underlyingTokenSymbol;
    uint256 internal migrationManagerInitialBalance;
    uint256 internal stateBeforeInitialize;
    uint256 internal yieldVaultMaxDeposit;
    uint256 internal yieldVaultMaxWithdraw;
    uint8 internal underlyingTokenDecimals;

    // ========= ADDRESSES =========
    address internal agglayerBridge;
    address internal migrationManagerAddr;
    address internal owner;
    address internal recipient;
    address internal sender;
    address internal yieldRecipient;
    address internal nativeConverter;

    // ========= VAULT BRIDGE TOKEN COMMON CONTRACTS =========
    VaultBridgeTokenInitializer internal initializer;
    VaultBridgeTokenPart2 internal vbTokenPart2Implementation;
    MockVault internal yieldVault;

    // ========= VAULT BRIDGE TOKEN METADATA =========
    string internal tokenName;
    string internal tokenSymbol;
    uint256 internal tokenDecimals;
    uint256 internal minimumReservePercentage;
    bytes internal tokenMetadata;

    /// @notice Configure Primary Chain infrastructure
    function deployPrimaryChainInfrastructure() internal virtual {
        // Set standard test addresses
        setupStandardTestAddresses();

        // Deploy underlying token (Dynamic deployment based on specified token name)
        underlyingToken = deployContract(
            underlyingTokenName, abi.encode(underlyingTokenName, underlyingTokenSymbol, underlyingTokenDecimals)
        );

        // Deploy & configure Migration Manager
        migrationManagerAddr = address(new MigrationManager());
        fundMigrationManager(migrationManagerAddr, underlyingToken, migrationManagerInitialBalance);

        // Deploy mock bridge for unit tests (vb specific configuration happens in vb test base)
        agglayerBridge = address(new MockAgglayerBridge());
        MockAgglayerBridge(agglayerBridge).setNetworkId(0);

        // Set Vault Bridge Token metadata
        minimumReservePercentage = minimumReservePercentage;
        tokenMetadata = abi.encode(tokenName, tokenSymbol, tokenDecimals);

        // Deploy & configure yield vault
        yieldVault = new MockVault(underlyingToken);
        yieldVault.setMaxDeposit(yieldVaultMaxDeposit);
        yieldVault.setMaxWithdraw(yieldVaultMaxWithdraw);

        // Deploy Vault Bridge Token common parts
        initializer = new VaultBridgeTokenInitializer();
        vbTokenPart2Implementation = new VaultBridgeTokenPart2();

        // Label contracts for easier debugging
        setupCommonLabels();
    }

    /// @notice Setup standard test addresses
    function setupStandardTestAddresses() internal {
        owner = makeAddr("owner");
        recipient = makeAddr("recipient");
        sender = vm.addr(0xBEEF);
        yieldRecipient = makeAddr("yieldRecipient");
        nativeConverter = makeAddr("nativeConverter");
    }

    /// @notice Configure Migration Manager
    function configureMigrationManager(address _vbToken, uint256 _amount) internal {
        require(migrationManagerAddr != address(0), "Migration manager not deployed");
        require(_vbToken != address(0), "VB token address is zero");
        vm.prank(migrationManagerAddr);
        IERC20(underlyingToken).approve(_vbToken, _amount);
    }

    /// @notice Setup debugging labels
    function setupCommonLabels() internal {
        vm.label(address(initializer), "Initializer");
        vm.label(address(vbTokenPart2Implementation), "VbToken Part2 Implementation");
        vm.label(address(yieldVault), "Yield Vault");
        vm.label(agglayerBridge, "Mock Agglayer Bridge");
        vm.label(migrationManagerAddr, "Migration Manager Address");
        vm.label(owner, "Owner");
        vm.label(recipient, "Recipient");
        vm.label(sender, "Sender");
        vm.label(underlyingToken, underlyingTokenName);
        vm.label(yieldRecipient, "Yield Recipient");
    }

    /// @notice Fund migration manager with assets for testing
    /// @dev Generalized function that works with any token type
    /// @param _migrationManagerAddress The migration manager address to fund
    /// @param _tokenAddress The token address to fund with
    /// @param _amount The amount to fund (default: 10M tokens)
    function fundMigrationManager(address _migrationManagerAddress, address _tokenAddress, uint256 _amount)
        internal
        virtual
    {
        deal(_tokenAddress, _migrationManagerAddress, _amount);
        vm.prank(_migrationManagerAddress);
        IERC20(_tokenAddress).approve(_migrationManagerAddress, _amount);
    }

    /// @notice Calculate reserve assets based on deposit amount and vault limits
    /// @param _amount The total amount being deposited
    /// @param _vaultMaxDeposit The maximum amount the yield vault can accept
    /// @return reserveAssets The amount that will be kept in reserve
    function calculateReserveAssets(uint256 _amount, uint256 _vaultMaxDeposit) internal view returns (uint256) {
        uint256 reserveAssets = (_amount * minimumReservePercentage) / MAX_RESERVE_PERCENTAGE;
        uint256 assetsToDeposit = _amount - reserveAssets;
        uint256 assetsToDepositMax = (assetsToDeposit > _vaultMaxDeposit) ? _vaultMaxDeposit : assetsToDeposit;
        return _amount - assetsToDepositMax;
    }

    /// @notice Calculate reserve assets when deposit amount is less than minimum required and reserve is rebalanced
    /// @param _amount The total amount being deposited
    /// @param _minimumReservePercentage The minimum reserve percentage required
    /// @return The amount that will be kept in reserve
    function calculateReserveAssetsLtMinimumDeposit(uint256 _amount, uint256 _minimumReservePercentage)
        internal
        pure
        returns (uint256)
    {
        uint256 amountToDeposit =
            (_amount * (MAX_RESERVE_PERCENTAGE - _minimumReservePercentage)) / MAX_RESERVE_PERCENTAGE;
        return _amount - amountToDeposit;
    }
}
