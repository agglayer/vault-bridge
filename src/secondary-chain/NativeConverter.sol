// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.0) (secondary-chain/NativeConverter.sol)

pragma solidity 0.8.29;

// Other functionality.
import {Initializable} from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ERC20PermitUser} from "../etc/ERC20PermitUser.sol";
import {InitializationCounterUpgradeable} from "../etc/InitializationCounterUpgradeable.sol";
import {Versioned} from "../etc/Versioned.sol";

// Libraries.
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// External contracts.
import {CustomToken} from "./CustomToken.sol";
import {CustomTokenWethExtension} from "./CustomTokenWethExtension.sol";
import {IAgglayerBridge} from "../etc/IAgglayerBridge.sol";
import {MigrationManager} from "../primary-chain/MigrationManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title Native Converter
/// @author See https://github.com/agglayer/vault-bridge
/// @notice Native Converter is an optional contract on Secondary Chains that converts the underlying token (usually the bridge-wrapped version of the original underlying token from Primary Chain) to Custom Token, and vice versa, on demand. It can also migrate backing for Custom Token it has minted to Primary Chain, where vbToken will be minted and locked in Agglayer Bridge. Please refer to `migrateBackingToPrimaryChain` for more information.
/// @dev A base contract used to create Native Converters.
/// @dev @note (ATTENTION) This contract MUST have mint and burn permission on Custom Token. Please refer to `CustomToken.sol` for more information.
/// @dev @note IMPORTANT: The underlying token MUST NOT be a rebasing token, and MUST NOT have transfer hooks (i.e., enable reentrancy); it MAY have a transfer fee.
abstract contract NativeConverter is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC20PermitUser,
    InitializationCounterUpgradeable,
    Versioned
{
    // Libraries.
    using SafeERC20 for IERC20;
    using SafeERC20 for CustomToken;

    /// @dev Storage of Native Converter contract.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:agglayer.vault-bridge.NativeConverter.storage
    struct NativeConverterStorage {
        CustomToken customToken;
        IERC20 underlyingToken;
        uint256 backingOnSecondaryChain;
        uint32 agglayerId;
        IAgglayerBridge bridge;
        uint32 primaryChainAgglayerId;
        uint256 nonMigratableBackingPercentage;
        address migrationManager;
        bool _underlyingTokenIsNotMintable;
        mapping(uint256 migratedBacking => uint256 times) _migrationsInProgress;
        uint256 _migrationsInProgressCount;
        uint256 _totalMigratedBackingInProgress;
    }

    /// @dev The storage slot at which Native Converter storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("agglayer.vault-bridge.NativeConverter.storage")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _NATIVE_CONVERTER_STORAGE =
        hex"a14770e0debfe4b8406a01c33ee3a7bbe0acc66b3bde7c71854bf7d080a9c600";

    // Basic roles.
    // @remind Document.
    bytes32 public constant MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Errors.
    error Unauthorized();
    error InvalidOwner();
    error InvalidCustomToken();
    error InvalidUnderlyingToken();
    error InvalidAgglayerBridge();
    error InvalidPrimaryChainAgglayerId();
    error InvalidMigrationManager();
    error NonMatchingTokenDecimals(uint8 customTokenDecimals, uint8 underlyingTokenDecimals);
    error InvalidAssets();
    error InvalidReceiver();
    error InvalidPermitData();
    error InvalidShares();
    error InvalidNonMigratableBackingPercentage();
    error AssetsTooLarge(uint256 availableAssets, uint256 requestedAssets);
    error InvalidDestinationNetworkId();
    error CannotSetCustomTokenIfBackingOnSecondaryChainIsNotZero();
    error CannotSetCustomTokenIfGasBackingOnSecondaryChainIsNotZero();
    error CannotSetCustomTokenIfMigrationsInProgressCountIsNotZero();

    // Events.
    event MigrationStarted(uint256 indexed mintedCustomToken, uint256 indexed migratedBacking);
    event NonMigratableBackingPercentageSet(uint256 nonMigratableBackingPercentage);
    event MigrationInProgressAdded(uint256 indexed migratedBacking);
    event MigrationInProgressRemoved(uint256 indexed mintedCustomToken);

    // -----================= ::: MODIFIERS ::: =================-----

    /// @dev Checks if the sender is the yield recipient.
    modifier onlyCustomToken() {
        NativeConverterStorage storage $ = _getNativeConverterStorage();
        require(msg.sender == address($.customToken), Unauthorized());
        _;
    }

    // -----================= ::: SETUP ::: =================-----

    /// @dev The `customToken` and `underlyingToken` MUST have the same number of decimals. @note (ATTENTION) The decimals of the `customToken` and `underlyingToken` will default to `18` if they revert on `decimals`.
    /// @param owner_ (ATTENTION) This address will be granted the `DEFAULT_ADMIN_ROLE`, as well as all basic roles. Roles can be modified at any time.
    /// @param customToken_ The upgraded version of the bridged vbToken. Native Converter must be able to mint and burn this token. Please refer to `CustomToken.sol` for more information.
    /// @param underlyingToken_ The token that represents the original underlying token on Secondary Chain. @note IMPORTANT: This token MUST be either the bridge-wrapped version of the original underlying token, or the original underlying token must be custom mapped to this token on Agglayer Bridge on Secondary Chain.
    /// @param nonMigratableBackingPercentage_ The percentage of backing that should remain in Native Converter when migrating backing to Primary Chain, based on the total supply of Custom Token. `1e18` is 100%. It is possible to game the system by manipulating the total supply of Custom Token, so this is more of a soft limit.
    /// @param migrationManager_ The address of the Migration Manager on Primary Chain.
    function __NativeConverter_init1(
        address owner_,
        address customToken_,
        address underlyingToken_,
        address agglayerBridge_,
        uint32 primaryChainAgglayerId_,
        uint256 nonMigratableBackingPercentage_,
        address migrationManager_
    ) internal onlyInitializing incrementsLocalInitializationCounter(1) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();

        // Check the inputs.
        require(owner_ != address(0), InvalidOwner());
        require(customToken_ != address(0), InvalidCustomToken());
        require(underlyingToken_ != address(0), InvalidUnderlyingToken());
        require(agglayerBridge_ != address(0), InvalidAgglayerBridge());
        require(primaryChainAgglayerId_ != IAgglayerBridge(agglayerBridge_).networkID(), InvalidAgglayerBridge());
        require(migrationManager_ != address(0), InvalidMigrationManager());
        require(nonMigratableBackingPercentage_ <= 1e18, InvalidNonMigratableBackingPercentage());

        // Get Custom Token's decimals.
        uint8 customTokenDecimals;
        try IERC20Metadata(customToken_).decimals() returns (uint8 decimals) {
            customTokenDecimals = decimals;
        } catch {
            // Default to 18 decimals if Custom Token reverted.
            customTokenDecimals = 18;
        }

        // Get the underlying token's decimals.
        uint8 underlyingTokenDecimals;
        try IERC20Metadata(underlyingToken_).decimals() returns (uint8 decimals) {
            underlyingTokenDecimals = decimals;
        } catch {
            // Default to 18 decimals if the underlying token reverted.
            underlyingTokenDecimals = 18;
        }

        // Check the tokens' decimals.
        require(
            customTokenDecimals == underlyingTokenDecimals,
            NonMatchingTokenDecimals(customTokenDecimals, underlyingTokenDecimals)
        );

        // Initialize the inherited contracts.
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __Context_init();
        __ERC165_init();

        // Grant the basic roles.
        _grantRole(DEFAULT_ADMIN_ROLE, owner_);
        _grantRole(MIGRATOR_ROLE, owner_);
        _grantRole(PAUSER_ROLE, owner_);

        // Initialize the storage.
        $.customToken = CustomToken(customToken_);
        $.underlyingToken = IERC20(underlyingToken_);
        $.agglayerId = IAgglayerBridge(agglayerBridge_).networkID();
        $.bridge = IAgglayerBridge(agglayerBridge_);
        $.primaryChainAgglayerId = primaryChainAgglayerId_;
        $.migrationManager = migrationManager_;
        $.nonMigratableBackingPercentage = nonMigratableBackingPercentage_;
    }

    // @remind Document (the entire function).
    function __NativeConverter_init2() internal onlyInitializing incrementsLocalInitializationCounter(2) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();

        $._underlyingTokenIsNotMintable = $.bridge.wrappedAddressIsNotMintable(address($.underlyingToken));
    }

    /*
    /// @dev How to add a new init step:
    function __NativeConverter_init3() internal onlyInitializing incrementsLocalInitializationCounter(3) {}
    */

    // @remind Document.
    function _NATIVE_CONVERTER_INIT_2_COMPATIBLE() internal pure virtual;

    // -----================= ::: STORAGE ::: =================-----

    /// @notice The upgraded version of the bridged vbToken.
    function customToken() public view returns (IERC20) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();
        return $.customToken;
    }

    /// @notice The token that represent the original underlying token on Secondary Chain.
    function underlyingToken() public view returns (IERC20) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();
        return $.underlyingToken;
    }

    /// @notice The amount of the underlying token that backs Custom Token minted by Native Converter on Secondary Chain that has not been migrated to Primary Chain.
    /// @dev The amount is used in accounting and may be different from Native Converter's underlying token balance. @note IMPORTANT: You may do as you wish with surplus underlying token balance, but you MUST NOT designate it as backing.
    function backingOnSecondaryChain() public view returns (uint256) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();
        return $.backingOnSecondaryChain;
    }

    /// @notice The Agglayer ID of this network.
    function agglayerId() public view returns (uint32) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();
        return $.agglayerId;
    }

    /// @notice Agglayer Bridge, which connects AggLayer networks.
    function bridge() public view returns (IAgglayerBridge) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();
        return $.bridge;
    }

    /// @notice The Agglayer ID of Primary Chain.
    function primaryChainAgglayerId() public view returns (uint32) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();
        return $.primaryChainAgglayerId;
    }

    /// @notice The percentage of backing that should remain in Native Converter when migrating backing to Primary Chain, based on the total supply of Custom Token.
    /// @dev It is possible to game the system by manipulating the total supply of Custom Token, so this is more of a soft limit.
    /// @return 1e18 is 100%.
    function nonMigratableBackingPercentage() public view returns (uint256) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();
        return $.nonMigratableBackingPercentage;
    }

    /// @notice The address of the Migration Manager on Primary Chain.
    function migrationManager() public view returns (MigrationManager) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();
        return MigrationManager(payable($.migrationManager));
    }

    /// @dev Returns a pointer to the ERC-7201 storage namespace.
    function _getNativeConverterStorage() private pure returns (NativeConverterStorage storage $) {
        assembly {
            $.slot := _NATIVE_CONVERTER_STORAGE
        }
    }

    // -----================= ::: PSEUDO VAULT ::: =================-----

    /// @notice Deposit a specific amount of the underlying token and get Custom Token.
    /// @param assets The amount of the underlying token to convert to Custom Token.
    /// @return shares The amount of Custom Token minted to the receiver.
    function convert(uint256 assets, address receiver) external whenNotPaused nonReentrant returns (uint256 shares) {
        return _convert(assets, receiver);
    }

    /// @notice Deposit a specific amount of the underlying token and get Custom Token.
    /// @param assets The amount of the underlying token to convert to Custom Token.
    /// @return shares The amount of Custom Token minted to the receiver.
    function _convert(uint256 assets, address receiver) internal returns (uint256 shares) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();

        // Check the inputs.
        require(assets > 0, InvalidAssets());
        require(receiver != address(0), InvalidReceiver());

        // Transfer the underlying token from the sender to self.
        assets = _receiveUnderlyingToken(msg.sender, assets);

        // Update the backing data.
        $.backingOnSecondaryChain += assets;

        // Set the return value.
        shares = _convertToShares(assets);

        // Mint Custom Token to the receiver.
        _mintCustomToken(receiver, shares);
    }

    /// @notice Deposit a specific amount of the underlying token and get Custom Token.
    /// @dev Uses EIP-2612 permit to transfer the underlying token from the sender to self.
    /// @param assets The amount of the underlying token to convert to Custom Token.
    /// @return shares The amount of Custom Token minted to the receiver.
    function convertWithPermit(uint256 assets, address receiver, bytes calldata permitData)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 shares)
    {
        NativeConverterStorage storage $ = _getNativeConverterStorage();

        // Check the input.
        require(permitData.length > 0, InvalidPermitData());

        // Use the permit.
        _permit(address($.underlyingToken), assets, permitData);

        return _convert(assets, receiver);
    }

    /// @notice How much Custom Token a specific user can burn. (Deconverting Custom Token burns it and unlocks the underlying token).
    function maxDeconvert(address owner) external view returns (uint256 maxShares) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();

        // Return zero if the contract is paused.
        if (paused()) return 0;

        // Return zero if the balance is zero.
        uint256 shares = $.customToken.balanceOf(owner);
        if (shares == 0) return 0;

        return _simulateDeconvert(shares, false);
    }

    /// @dev Calculates the amount of Custom Token that can be deconverted right now.
    /// @param shares The maximum amount of Custom Token to simulate deconversion for.
    /// @param force Whether to revert if the all of the `shares` would not be deconverted.
    function _simulateDeconvert(uint256 shares, bool force) internal view returns (uint256 deconvertedShares) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();

        // Check the input.
        require(shares > 0, InvalidShares());

        // Switch to the underlying token.
        uint256 assets = _convertToAssets(shares);

        // The amount that cannot be converted at the moment.
        uint256 remainingAssets = assets;

        // Simulate deconversion.
        uint256 backingOnSecondaryChain_ = $.backingOnSecondaryChain;
        if (backingOnSecondaryChain_ >= remainingAssets) return shares;
        remainingAssets -= backingOnSecondaryChain_;

        // Calculate the converted amount.
        uint256 convertedAssets = assets - remainingAssets;

        // Set the return value (the amount of Custom Token that can be deconverted right now).
        deconvertedShares = _convertToShares(convertedAssets);

        // Revert if all of the `shares` must have been deconverted and there is a remaining amount.
        if (force) require(remainingAssets == 0, AssetsTooLarge(convertedAssets, assets));
    }

    /// @notice Burn a specific amount of Custom Token to unlock a respective amount of the underlying token.
    /// @param shares The amount of Custom Token to deconvert to the underlying token.
    /// @return assets The amount of the underlying token unlocked to the receiver.
    function deconvert(uint256 shares, address receiver) external whenNotPaused nonReentrant returns (uint256 assets) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();
        return _deconvert(shares, $.agglayerId, receiver, false);
    }

    /// @notice Burn a specific amount of Custom Token to unlock a respective amount of the underlying token, and bridge it to another network.
    /// @param shares The amount of Custom Token to deconvert to the underlying token.
    /// @return assets The amount of the underlying token unlocked to the receiver.
    function deconvertAndBridge(
        uint256 shares,
        address receiver,
        uint32 destinationNetworkId,
        bool forceUpdateGlobalExitRoot
    ) external whenNotPaused nonReentrant returns (uint256 assets) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();

        // Check the input.
        require(destinationNetworkId != $.agglayerId, InvalidDestinationNetworkId());

        return _deconvert(shares, destinationNetworkId, receiver, forceUpdateGlobalExitRoot);
    }

    /// @notice Burn a specific amount of Custom Token to unlock a respective amount of the underlying token, and optionally bridge it to another network.
    /// @param shares The amount of Custom Token to deconvert to the underlying token.
    /// @return assets The amount of the underlying token unlocked to the receiver.
    function _deconvert(uint256 shares, uint32 destinationNetworkId, address receiver, bool forceUpdateGlobalExitRoot)
        internal
        returns (uint256 assets)
    {
        NativeConverterStorage storage $ = _getNativeConverterStorage();

        // Check the inputs.
        require(shares > 0, InvalidShares());
        require(receiver != address(0), InvalidReceiver());

        // Switch to the underlying token.
        // Set the return value.
        assets = _convertToAssets(shares);

        // Get the available backing.
        uint256 backingOnSecondaryChain_ = backingOnSecondaryChain();

        // Revert if there is not enough backing.
        require(backingOnSecondaryChain_ >= assets, AssetsTooLarge(backingOnSecondaryChain_, assets));

        // Update the backing data.
        $.backingOnSecondaryChain -= assets;

        // Burn Custom Token.
        _burnCustomToken(msg.sender, shares);

        // Withdraw the underlying token.
        if (destinationNetworkId == $.agglayerId) {
            // Withdraw to the receiver.
            _sendUnderlyingToken(receiver, assets);
        } else {
            // Bridge to the receiver.
            $.bridge
                .bridgeAsset(
                    destinationNetworkId, receiver, assets, address($.underlyingToken), forceUpdateGlobalExitRoot, ""
                );
        }
    }

    /// @dev Tells how much a specific amount of underlying token is worth in Custom Token.
    /// @dev The underlying token backs vbToken 1:1.
    /// @param assets The amount of the underlying token.
    /// @return shares The amount of Custom Token.
    function _convertToShares(uint256 assets) internal pure returns (uint256 shares) {
        // @note CAUTION! Changing this function will affect the conversion rate for the entire contract, and may introduce bugs.
        shares = assets;
    }

    /// @dev Tells how much a specific amount of Custom Token is worth in the underlying token.
    /// @dev vbToken is backed by the underlying token 1:1.
    /// @param shares The amount of Custom Token.
    /// @return assets The amount of the underlying token.
    function _convertToAssets(uint256 shares) internal pure returns (uint256 assets) {
        // @note CAUTION! Changing this function will affect the conversion rate for the entire contract, and may introduce bugs.
        assets = shares;
    }

    // -----================= ::: NATIVE CONVERTER ::: =================-----

    /// @notice The maximum amount of backing that can be migrated to Primary Chain.
    function migratableBacking() public view returns (uint256) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();

        // Calculate the non-migratable backing.
        uint256 nonMigratableBacking = _convertToAssets(
            Math.mulDiv(customToken().totalSupply(), $.nonMigratableBackingPercentage, 1e18, Math.Rounding.Ceil)
        );

        // Return the amount of backing that can be migrated.
        return $.backingOnSecondaryChain > nonMigratableBacking ? $.backingOnSecondaryChain - nonMigratableBacking : 0;
    }

    /// @notice Migrates a specific amount of backing to Primary Chain.
    /// @notice This action provides vbToken liquidity on Agglayer Bridge on Primary Chain.
    /// @notice The bridged asset and message must be claimed manually on Agglayer Bridge on Primary Chain to complete the migration.
    /// @notice This function can be called by a migrator only.
    /// @notice The migration can be completed by anyone on Primary Chain.
    /// @dev Consider calling this function periodically; anyone can complete a migration on Primary Chain.
    function migrateBackingToPrimaryChain(uint256 assets) external onlyRole(MIGRATOR_ROLE) nonReentrant {
        NativeConverterStorage storage $ = _getNativeConverterStorage();

        // Cache the migratable backing.
        uint256 migratableBacking_ = migratableBacking();

        // Check the inputs.
        require(assets > 0, InvalidAssets());
        require(assets <= migratableBacking_, AssetsTooLarge(migratableBacking_, assets));

        // Update the backing data.
        $.backingOnSecondaryChain -= assets;

        // @remind Document.
        _addMigrationInProgress(assets);

        // Calculate the amount of Custom Token for which backing is being migrated.
        uint256 shares = _convertToShares(assets);

        // Bridge the backing to Migration Manager on Primary Chain.
        /* If the underlying token is not mintable by Agglayer Bridge, we need to check for a transfer fee. */
        if ($._underlyingTokenIsNotMintable) {
            // Cache the balance.
            uint256 balanceBefore = $.underlyingToken.balanceOf(address($.bridge));

            // Bridge.
            // @note IMPORTANT: Make sure the underlying token you are integrating does not enable reentrancy on `transferFrom`.
            $.bridge
                .bridgeAsset($.primaryChainAgglayerId, $.migrationManager, assets, address($.underlyingToken), true, "");

            uint256 originalAssets = assets;

            // Calculate the bridged amount.
            assets = $.underlyingToken.balanceOf(address($.bridge)) - balanceBefore;

            // Try to prevent a mistake in case Agglayer Bridge code changes.
            assert(assets > 0 && originalAssets >= assets);
        }
        /* If the underlying token is mintable by Agglayer Bridge, it will be burned (not transferred). */
        else {
            $.bridge
                .bridgeAsset($.primaryChainAgglayerId, $.migrationManager, assets, address($.underlyingToken), true, "");
        }

        // Bridge a message to Migration Manager on Primary Chain to complete the migration.
        $.bridge
            .bridgeMessage(
                $.primaryChainAgglayerId,
                $.migrationManager,
                true,
                abi.encode(MigrationManager.CrossChainInstruction._0_COMPLETE_MIGRATION, abi.encode(shares, assets))
            );

        // Emit the event.
        emit MigrationStarted(shares, assets);
    }

    /// @notice Sets the percentage of backing that should remain in Native Converter after a migration, based on the total supply of Custom Token.
    /// @notice It is possible to game the system by manipulating the total supply of Custom Token, so this is a soft limit.
    /// @notice This function can be called by the owner only.
    /// @param nonMigratableBackingPercentage_ 1e18 is 100%.
    function setNonMigratableBackingPercentage(uint256 nonMigratableBackingPercentage_)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        NativeConverterStorage storage $ = _getNativeConverterStorage();

        // Check the input.
        require(nonMigratableBackingPercentage_ <= 1e18, InvalidNonMigratableBackingPercentage());

        // Set the non-migratable backing percentage.
        $.nonMigratableBackingPercentage = nonMigratableBackingPercentage_;

        // Emit the event.
        emit NonMigratableBackingPercentageSet(nonMigratableBackingPercentage_);
    }

    // @remind Document (the entire function).
    function removeMigrationInProgress(uint256 mintedCustomToken) external onlyCustomToken nonReentrant {
        _removeMigrationInProgress(mintedCustomToken);
    }

    // @remind Document (the entire function).
    function _addMigrationInProgress(uint256 migratedBacking) internal {
        NativeConverterStorage storage $ = _getNativeConverterStorage();

        $._migrationsInProgress[migratedBacking]++;
        $._migrationsInProgressCount++;
        $._totalMigratedBackingInProgress += migratedBacking;

        emit MigrationInProgressAdded(migratedBacking);
    }

    // @remind Document (the entire function).
    function _removeMigrationInProgress(uint256 mintedCustomToken) private {
        NativeConverterStorage storage $ = _getNativeConverterStorage();

        $._migrationsInProgress[mintedCustomToken]--;
        $._migrationsInProgressCount--;
        $._totalMigratedBackingInProgress -= mintedCustomToken;

        emit MigrationInProgressRemoved(mintedCustomToken);
    }

    // @remind Document (the entire function).
    function setCustomToken(address customToken_) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        NativeConverterStorage storage $ = _getNativeConverterStorage();

        require(customToken_ != address(0), InvalidCustomToken());

        require($.backingOnSecondaryChain == 0, CannotSetCustomTokenIfBackingOnSecondaryChainIsNotZero());
        require($._migrationsInProgressCount == 0, CannotSetCustomTokenIfMigrationsInProgressCountIsNotZero());

        try CustomTokenWethExtension(payable(address($.customToken))).gasBackingOnSecondaryChain() returns (
            uint256 gasBackingOnSecondaryChain
        ) {
            require(gasBackingOnSecondaryChain == 0, CannotSetCustomTokenIfGasBackingOnSecondaryChainIsNotZero());
        } catch {}

        // Get Custom Token's decimals.
        uint8 customTokenDecimals;
        try IERC20Metadata(customToken_).decimals() returns (uint8 decimals) {
            customTokenDecimals = decimals;
        } catch {
            // Default to 18 decimals if Custom Token reverted.
            customTokenDecimals = 18;
        }

        // Get the underlying token's decimals.
        uint8 underlyingTokenDecimals;
        try IERC20Metadata(address($.underlyingToken)).decimals() returns (uint8 decimals) {
            underlyingTokenDecimals = decimals;
        } catch {
            // Default to 18 decimals if the underlying token reverted.
            underlyingTokenDecimals = 18;
        }

        // Check the tokens' decimals.
        require(
            customTokenDecimals == underlyingTokenDecimals,
            NonMatchingTokenDecimals(customTokenDecimals, underlyingTokenDecimals)
        );

        $.customToken = CustomToken(customToken_);
    }

    // -----================= ::: UNDERLYING TOKEN ::: =================-----

    /// @notice Transfers the underlying token from an external account to itself.
    /// @dev @note CAUTION! This function MUST NOT introduce reentrancy/cross-entrancy vulnerabilities.
    /// @return receivedValue The amount of the underlying actually received (e.g., after transfer fees).
    function _receiveUnderlyingToken(address from, uint256 value) internal returns (uint256 receivedValue) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();

        // Cache the balance.
        uint256 balanceBefore = $.underlyingToken.balanceOf(address(this));

        // Transfer.
        // @note IMPORTANT: Make sure the underlying token you are integrating does not enable reentrancy on `transferFrom`.
        $.underlyingToken.safeTransferFrom(from, address(this), value);

        // Calculate the received amount.
        receivedValue = $.underlyingToken.balanceOf(address(this)) - balanceBefore;
    }

    /// @notice Transfers the underlying token to an external account.
    /// @dev @note CAUTION! This function MUST NOT introduce reentrancy/cross-entrancy vulnerabilities.
    function _sendUnderlyingToken(address to, uint256 value) internal {
        NativeConverterStorage storage $ = _getNativeConverterStorage();

        // Transfer.
        // @note IMPORTANT: Make sure the underlying token you are integrating does not enable reentrancy on `transfer`.
        $.underlyingToken.safeTransfer(to, value);
    }

    // -----================= ::: ADMIN ::: =================-----

    /// @notice Prevents usage of functions with the `whenNotPaused` modifier.
    /// @notice This function can be called by a pauser only.
    function pause() external onlyRole(PAUSER_ROLE) nonReentrant {
        _pause();
    }

    /// @notice Allows usage of functions with the `whenNotPaused` modifier.
    /// @notice This function can be called by the owner only.
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        _unpause();
    }

    // -----================= ::: DEVELOPER ::: =================-----

    // @remind Document (the entire function).
    function _mintCustomToken(address account, uint256 value) internal virtual;

    // @remind Document (the entire function).
    function _burnCustomToken(address account, uint256 value) internal virtual;
}
