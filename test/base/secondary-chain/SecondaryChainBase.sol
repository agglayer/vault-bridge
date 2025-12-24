// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test infrastructure
import {TestConstants} from "test/base/TestConstants.sol";

// Core contracts
import {NativeConverter} from "src/secondary-chain/NativeConverter.sol";
import {CustomToken} from "src/secondary-chain/CustomToken.sol";

// Mock contracts
import {MockAgglayerBridge} from "test/utils/mocks/MockAgglayerBridge.sol";
import {MockERC20Upgradeable} from "test/utils/mocks/MockERC20Upgradeable.sol";
import {MockTokenWrappedBridgeUpgradeable} from "test/utils/mocks/MockTokenWrappedBridgeUpgradeable.sol";
import {MockGlobalExitRootManager} from "test/utils/mocks/MockGlobalExitRootManager.sol";

// OpenZeppelin
import {ERC20Upgradeable} from "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

/// @title Test Harness for CustomToken
/// @notice A test harness that extends CustomToken to expose reinitialization functions for testing
contract TestHarnessCustomToken is CustomToken {
    constructor() {
        _disableInitializers();
    }

    function reinitialize1() external {}

    function reinitialize2(
        address owner_,
        uint8 originalUnderlyingTokenDecimals_,
        address agglayerBridge_,
        address nativeConverter_
    ) external whenNotPaused reinitializer(2) nonReentrant {
        string memory name_ = ERC20Upgradeable.name();
        string memory symbol_ = ERC20Upgradeable.symbol();
        __CustomToken_init1(owner_, name_, symbol_, originalUnderlyingTokenDecimals_, agglayerBridge_, nativeConverter_);
    }

    function reinitialize3() external whenNotPaused reinitializer(3) nonReentrant {
        _incrementGlobalInitializationCounter(1);
        _incrementGlobalInitializationCounter(2);
        _incrementGlobalInitializationCounter(3);

        __CustomToken_init2();
    }

    function reinitialize(bytes[] calldata reinitializeData) external {
        bytes4[] memory reinitializeSelectors = new bytes4[](3);

        reinitializeSelectors[0] = this.reinitialize1.selector;
        reinitializeSelectors[1] = this.reinitialize2.selector;
        reinitializeSelectors[2] = this.reinitialize3.selector;

        _reinitialize(reinitializeSelectors, reinitializeData);
    }

    /// @inheritdoc CustomToken
    function _CUSTOM_TOKEN_INIT_2_COMPATIBLE() internal pure override {}

    /// @inheritdoc CustomToken
    function _CUSTOM_TOKEN_IS_MINTABLE_BURNABLE() internal override {}
}

/// @title Test Harness for NativeConverter
/// @notice A test harness that extends NativeConverter to expose reinitialization functions for testing
contract TestHarnessNativeConverter is NativeConverter {
    constructor() {
        _disableInitializers();
    }

    function reinitialize1(
        address owner_,
        address customToken_,
        address underlyingToken_,
        address agglayerBridge_,
        uint32 primaryChainAgglayerId_,
        uint256 nonMigratableBackingPercentage_,
        address migrationManager_
    ) external whenNotPaused reinitializer(1) nonReentrant {
        __NativeConverter_init1(
            owner_,
            customToken_,
            underlyingToken_,
            agglayerBridge_,
            primaryChainAgglayerId_,
            nonMigratableBackingPercentage_,
            migrationManager_
        );
    }

    function reinitialize2() external whenNotPaused reinitializer(2) nonReentrant {
        _incrementGlobalInitializationCounter(1);
        _incrementGlobalInitializationCounter(2);

        __NativeConverter_init2();
    }

    // @remind Document (the entire function).
    function reinitialize(bytes[] calldata reinitializeData) external {
        bytes4[] memory reinitializeSelectors = new bytes4[](2);

        reinitializeSelectors[0] = this.reinitialize1.selector;
        reinitializeSelectors[1] = this.reinitialize2.selector;

        _reinitialize(reinitializeSelectors, reinitializeData);
    }

    /// @inheritdoc NativeConverter
    function _NATIVE_CONVERTER_INIT_2_COMPATIBLE() internal pure override {}

    function _mintCustomToken(address to, uint256 amount) internal override {
        MockTokenWrappedBridgeUpgradeable(address(customToken())).mint(to, amount);
    }

    function _burnCustomToken(address from, uint256 amount) internal override {
        MockTokenWrappedBridgeUpgradeable(address(customToken())).burn(from, amount);
    }

    // Test helper functions to expose internal state
    function getMigrationsInProgress(uint256 migratedBacking) external view returns (uint256 value) {
        bytes32 storageSlot = hex"a14770e0debfe4b8406a01c33ee3a7bbe0acc66b3bde7c71854bf7d080a9c600";
        // _migrationsInProgress is at offset 8 in the struct
        bytes32 baseSlot;
        assembly {
            baseSlot := add(storageSlot, 8)
        }
        bytes32 mappingSlot = keccak256(abi.encode(migratedBacking, baseSlot));
        assembly {
            value := sload(mappingSlot)
        }
    }

    function getMigrationsInProgressCount() external view returns (uint256 value) {
        bytes32 storageSlot = hex"a14770e0debfe4b8406a01c33ee3a7bbe0acc66b3bde7c71854bf7d080a9c600";
        // _migrationsInProgressCount is at offset 9 in the struct
        assembly {
            value := sload(add(storageSlot, 9))
        }
    }

    function getTotalMigratedBackingInProgress() external view returns (uint256 value) {
        bytes32 storageSlot = hex"a14770e0debfe4b8406a01c33ee3a7bbe0acc66b3bde7c71854bf7d080a9c600";
        // _totalMigratedBackingInProgress is at offset 10 in the struct
        assembly {
            value := sload(add(storageSlot, 10))
        }
    }
}

/// @title Secondary Chain Base
/// @notice Base contract for setting up Secondary Chain infrastructure in tests
abstract contract SecondaryChainBase is TestConstants {
    // ========= VAULT BRIDGE VERSION =========
    string internal constant NATIVE_CONVERTER_PROTOCOL = "1.0.0";

    // ========= STATE VARIABLES =========
    uint256 internal stateBeforeInitialize;

    // ========= ADDRESSES =========
    address internal calculatedNativeConverter;
    address internal dummyNativeConverter;
    address internal migrationManager;
    address internal originUnderlyingToken;
    address internal owner;
    address internal proxyAdmin;
    address internal recipient;
    address internal sender;

    // ========= CONTRACT METADATA =========
    bytes internal underlyingTokenMetadata;
    string internal customTokenName;
    string internal customTokenSymbol;
    string internal underlyingTokenName;
    string internal underlyingTokenSymbol;
    uint256 internal maxNonMigratableBackingPercentage;
    uint256 internal maxNonMigratableGasBackingPercentage;
    uint32 internal primaryChainAgglayerId;
    uint8 internal customTokenDecimals;
    uint8 internal underlyingTokenDecimals;

    // ========= MOCK CONTRACTS =========
    MockAgglayerBridge internal mockAgglayerBridge;
    MockTokenWrappedBridgeUpgradeable internal customToken;
    MockERC20Upgradeable internal underlyingToken;

    /// @notice Configure Secondary Chain infrastructure
    /// @dev This function sets up the basic infrastructure but doesn't deploy implementations
    function deploySecondaryChainInfrastructure() internal virtual {
        // Set standard test addresses
        setupStandardTestAddresses();

        // Set origin underlying token address
        originUnderlyingToken = makeAddr("originUnderlyingToken");

        // Deploy mock Agglayer Bridge for unit tests
        mockAgglayerBridge = new MockAgglayerBridge();
        mockAgglayerBridge.setNetworkId(NETWORK_ID_L2);

        MockGlobalExitRootManager _globalExitRootManager = new MockGlobalExitRootManager();
        mockAgglayerBridge.setGlobalExitRootManager(address(_globalExitRootManager));

        // Setup labels
        setupCommonLabels();
    }

    /// @notice Setup standard test addresses
    function setupStandardTestAddresses() internal {
        dummyNativeConverter = makeAddr("dummyNativeConverter");
        migrationManager = makeAddr("migrationManager");
        owner = makeAddr("owner");
        proxyAdmin = makeAddr("proxyAdmin");
        recipient = makeAddr("recipient");
        sender = vm.addr(senderPrivateKey);
    }

    /// @notice Setup debugging labels
    function setupCommonLabels() internal {
        vm.label(address(mockAgglayerBridge), "MockAgglayerBridge");
        vm.label(dummyNativeConverter, "DummyNativeConverter");
        vm.label(migrationManager, "MigrationManager");
        vm.label(owner, "Owner");
        vm.label(proxyAdmin, "ProxyAdmin");
        vm.label(recipient, "Recipient");
        vm.label(sender, "Sender");
    }

    /// @notice Helper function to get the proxy admin address
    function _getProxyAdmin(address target) internal view returns (address) {
        bytes32 ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        bytes32 value = vm.load(target, ADMIN_SLOT);
        return address(uint160(uint256(value)));
    }
}
