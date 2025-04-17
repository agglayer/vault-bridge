// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.29;

// Other functionality.
import {Initializable} from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ERC20PermitUser} from "./etc/ERC20PermitUser.sol";
import {IVersioned} from "./etc/IVersioned.sol";

// Libraries.
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// External contracts.
import {CustomToken} from "./CustomToken.sol";
import {ILxLyBridge} from "./etc/ILxLyBridge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title Native Converter
/// @notice Native Converter lives on Layer Ys and converts the underlying token (usually the bridge-wrapped version of the original underlying token from Layer X) to Custom Token, and vice versa, on demand. It can also migrate backing for Custom Token it has minted to Layer X, where vbToken will be minted and locked in LxLy Bridge. Please refer to `migrateBackingToLayerX` for more information.
/// @dev This contract MUST have mint and burn permission on Custom Token. Please refer to `CustomToken.sol` for more information.
abstract contract NativeConverter is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC20PermitUser,
    IVersioned
{
    // Libraries.
    using SafeERC20 for IERC20;
    using SafeERC20 for CustomToken;

    /// @dev Used in cross-network communication.
    enum CrossNetworkInstruction {
        COMPLETE_MIGRATION,
        CUSTOM
    }

    /// @dev Storage of Native Converter contract.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:0xpolygon.storage.NativeConverter
    struct NativeConverterStorage {
        CustomToken customToken;
        IERC20 underlyingToken;
        bool _underlyingTokenIsNotMintable;
        uint256 backingOnLayerY;
        uint32 lxlyId;
        ILxLyBridge lxlyBridge;
        uint32 layerXLxlyId;
        address vbToken;
        // @todo Remove. If upgrading the testnet contracts, add a reinitializer and clear the old slots using assembly.
        address __OUTDATED__migrator;
        uint256 nonMigratableBackingPercentage;
    }

    // @todo Change the namespace. If upgrading the testnet contracts, add a reinitializer and clear the old slots using assembly.
    /// @dev The storage slot at which Native Converter storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("0xpolygon.storage.NativeConverter")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _NATIVE_CONVERTER_STORAGE =
        hex"b6887066a093cfbb0ec14b46507f657825a892fd6a4c4a1ef4fc83e8c7208c00";

    // Basic roles.
    bytes32 public constant MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Errors.
    error InvalidOwner();
    error InvalidCustomToken();
    error InvalidUnderlyingToken();
    error InvalidLxLyBridge();
    error InvalidLayerXLxlyId();
    error InvalidVbToken();
    error NonMatchingCustomTokenDecimals(uint8 customTokenDecimals, uint8 originalUnderlyingTokenDecimals);
    error NonMatchingUnderlyingTokenDecimals(uint8 underlyingTokenDecimals, uint8 originalUnderlyingTokenDecimals);
    error InvalidAssets();
    error InvalidReceiver();
    error InvalidPermitData();
    error InvalidShares();
    error InvalidNonMigratableBackingPercentage();
    error AssetsTooLarge(uint256 availableAssets, uint256 requestedAssets);
    error InvalidDestinationNetworkId();
    error OnlyMigrator();

    // Events.
    event MigrationStarted(address indexed initiator, uint256 indexed mintedCustomToken, uint256 migratedBacking);
    event NonMigratableBackingPercentageSet(uint256 nonMigratableBackingPercentage);

    /// @param originalUnderlyingTokenDecimals_ The number of decimals of the original underlying token on Layer X. The `customToken` and `underlyingToken` MUST have the same number of decimals as the original underlying token. @note (ATTENTION) The decimals of the `customToken` and `underlyingToken` will default to 18 if they revert.
    /// @param customToken_ The token custom mapped to vbToken on LxLy Bridge on Layer Y. Native Converter must be able to mint and burn this token. Please refer to `CustomToken.sol` for more information.
    /// @param underlyingToken_ The token that represents the original underlying token on Layer Y. @note IMPORTANT: This token MUST be either the bridge-wrapped version of the original underlying token, or the original underlying token must be custom mapped to this token on LxLy Bridge on Layer Y.
    /// @param vbToken_ The address of vbToken on Layer X.
    /// @param nonMigratableBackingPercentage_ The percentage of backing that should remain in Native Converter after a migration, based on the total supply of Custom Token. 1e18 is 100%. It is possible to game the system by manipulating the total supply of Custom Token, so this is a soft limit.
    function __NativeConverter_init(
        address owner_,
        uint8 originalUnderlyingTokenDecimals_,
        address customToken_,
        address underlyingToken_,
        address lxlyBridge_,
        uint32 layerXLxlyId_,
        address vbToken_,
        uint256 nonMigratableBackingPercentage_
    ) internal onlyInitializing {
        NativeConverterStorage storage $ = _getNativeConverterStorage();

        // Check the inputs.
        require(owner_ != address(0), InvalidOwner());
        require(customToken_ != address(0), InvalidCustomToken());
        require(underlyingToken_ != address(0), InvalidUnderlyingToken());
        require(lxlyBridge_ != address(0), InvalidLxLyBridge());
        require(layerXLxlyId_ != ILxLyBridge(lxlyBridge_).networkID(), InvalidLxLyBridge());
        require(vbToken_ != address(0), InvalidVbToken());
        require(nonMigratableBackingPercentage_ <= 1e18, InvalidNonMigratableBackingPercentage());

        // Check Custom Token's decimals.
        uint8 customTokenDecimals;
        try IERC20Metadata(customToken_).decimals() returns (uint8 decimals) {
            customTokenDecimals = decimals;
        } catch {
            // Default to 18 decimals.
            customTokenDecimals = 18;
        }
        require(
            customTokenDecimals == originalUnderlyingTokenDecimals_,
            NonMatchingCustomTokenDecimals(customTokenDecimals, originalUnderlyingTokenDecimals_)
        );

        // Check the underlying token's decimals.
        uint8 underlyingTokenDecimals;
        try IERC20Metadata(underlyingToken_).decimals() returns (uint8 decimals_) {
            underlyingTokenDecimals = decimals_;
        } catch {
            // Default to 18 decimals.
            underlyingTokenDecimals = 18;
        }
        require(
            underlyingTokenDecimals == originalUnderlyingTokenDecimals_,
            NonMatchingUnderlyingTokenDecimals(underlyingTokenDecimals, originalUnderlyingTokenDecimals_)
        );

        // Initialize the inherited contracts.
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        // Grant the basic roles.
        _grantRole(DEFAULT_ADMIN_ROLE, owner_);
        _grantRole(MIGRATOR_ROLE, owner_);
        _grantRole(PAUSER_ROLE, owner_);

        // Initialize the storage.
        $.customToken = CustomToken(customToken_);
        $.underlyingToken = IERC20(underlyingToken_);
        $._underlyingTokenIsNotMintable = ILxLyBridge(lxlyBridge_).wrappedAddressIsNotMintable(underlyingToken_);
        $.lxlyId = ILxLyBridge(lxlyBridge_).networkID();
        $.lxlyBridge = ILxLyBridge(lxlyBridge_);
        $.layerXLxlyId = layerXLxlyId_;
        $.vbToken = vbToken_;
        $.nonMigratableBackingPercentage = nonMigratableBackingPercentage_;

        // Approve LxLy Bridge.
        $.underlyingToken.forceApprove(address($.lxlyBridge), type(uint256).max);
    }

    // -----================= ::: STORAGE ::: =================-----

    /// @notice The token custom mapped to vbToken on LxLy Bridge on Layer Y.
    function customToken() public view returns (IERC20) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();
        return $.customToken;
    }

    /// @notice The token that represent the original underlying token on Layer Y.
    function underlyingToken() public view returns (IERC20) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();
        return $.underlyingToken;
    }

    /// @notice The amount of the underlying token that backs Custom Token minted by Native Converter on Layer Y that has not been migrated to Layer X.
    /// @dev The amount is used in accounting and may be different from Native Converter's underlying token balance. You may do as you wish with surplus underlying token balance, but you MUST NOT designate it as backing.
    function backingOnLayerY() public view returns (uint256) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();
        return $.backingOnLayerY;
    }

    /// @notice The LxLy ID of this network.
    function lxlyId() public view returns (uint32) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();
        return $.lxlyId;
    }

    /// @notice LxLy Bridge, which connects AggLayer networks.
    function lxlyBridge() public view returns (ILxLyBridge) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();
        return $.lxlyBridge;
    }

    /// @notice The LxLy ID of Layer X.
    function layerXLxlyId() public view returns (uint32) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();
        return $.layerXLxlyId;
    }

    /// @notice The address of vbToken on Layer X.
    function vbToken() public view returns (address) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();
        return $.vbToken;
    }

    /// @notice The percentage of backing that should remain in Native Converter after a migration, based on the total supply of Custom Token.
    /// @dev It is possible to game the system by manipulating the total supply of Custom Token, so this is a soft limit.
    /// @return 1e18 is 100%.
    function nonMigratableBackingPercentage() public view returns (uint256) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();
        return $.nonMigratableBackingPercentage;
    }

    /// @dev Returns a pointer to the ERC-7201 storage namespace.
    function _getNativeConverterStorage() private pure returns (NativeConverterStorage storage $) {
        assembly {
            $.slot := _NATIVE_CONVERTER_STORAGE
        }
    }

    // -----================= ::: PSEUDO-ERC-4626 ::: =================-----

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
        $.backingOnLayerY += assets;

        // Set the return value.
        shares = _convertToShares(assets);

        // Mint Custom Token to the receiver.
        $.customToken.mint(receiver, shares);
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
        uint256 backingOnLayerY_ = $.backingOnLayerY;
        if (backingOnLayerY_ >= remainingAssets) return shares;
        remainingAssets -= backingOnLayerY_;

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
        return _deconvert(shares, $.lxlyId, receiver, false);
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
        require(destinationNetworkId != $.lxlyId, InvalidDestinationNetworkId());

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
        uint256 backingOnLayerY_ = backingOnLayerY();

        // Revert if there is not enough backing.
        require(backingOnLayerY_ >= assets, AssetsTooLarge(backingOnLayerY_, assets));

        // Update the backing data.
        $.backingOnLayerY -= assets;

        // Burn Custom Token.
        $.customToken.burn(msg.sender, shares);

        // Withdraw the underlying token.
        if (destinationNetworkId == $.lxlyId) {
            // Withdraw to the receiver.
            _sendUnderlyingToken(receiver, assets);
        } else {
            // Bridge to the receiver.
            $.lxlyBridge.bridgeAsset(
                destinationNetworkId, receiver, assets, address($.underlyingToken), forceUpdateGlobalExitRoot, ""
            );
        }
    }

    /// @notice Burn a specific amount of Custom Token to unlock a respective amount of the underlying token.
    /// @param shares The amount of Custom Token to deconvert to the underlying token.
    /// @return assets The amount of the underlying token unlocked to the receiver.
    /// @dev Uses EIP-2612 permit to transfer Custom Token from the sender to self.
    function deconvertWithPermit(uint256 shares, address receiver, bytes calldata permitData)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 assets)
    {
        NativeConverterStorage storage $ = _getNativeConverterStorage();
        return _deconvertWithPermit(shares, permitData, $.lxlyId, receiver, false);
    }

    /// @notice Burn a specific amount of Custom Token to unlock a respective amount of the underlying token, and bridge it to another network.
    /// @param shares The amount of Custom Token to deconvert to the underlying token.
    /// @return assets The amount of the underlying token unlocked to the receiver.
    /// @dev Uses EIP-2612 permit to transfer Custom Token from the sender to self.
    function deconvertWithPermitAndBridge(
        uint256 shares,
        address receiver,
        uint32 destinationNetworkId,
        bool forceUpdateGlobalExitRoot,
        bytes calldata permitData
    ) external whenNotPaused nonReentrant returns (uint256 assets) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();

        // Check the input.
        require(destinationNetworkId != $.lxlyId, InvalidDestinationNetworkId());

        return _deconvertWithPermit(shares, permitData, destinationNetworkId, receiver, forceUpdateGlobalExitRoot);
    }

    /// @notice Burn a specific amount of Custom Token to unlock a respective amount of the underlying token, and optionally bridge it to another network.
    /// @param shares The amount of Custom Token to deconvert to the underlying token.
    /// @return assets The amount of the underlying token unlocked to the receiver.
    /// @dev Uses EIP-2612 permit to transfer Custom Token from the sender to self.
    function _deconvertWithPermit(
        uint256 shares,
        bytes calldata permitData,
        uint32 destinationNetworkId,
        address receiver,
        bool forceUpdateGlobalExitRoot
    ) internal returns (uint256 assets) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();

        // Check the input.
        require(permitData.length > 0, InvalidPermitData());

        // Use the permit.
        _permit(address($.underlyingToken), assets, permitData);

        return _deconvert(shares, destinationNetworkId, receiver, forceUpdateGlobalExitRoot);
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

    /// @notice The maximum amount of backing that can be migrated to Layer X.
    function migratableBacking() public view returns (uint256) {
        NativeConverterStorage storage $ = _getNativeConverterStorage();

        // Calculate the non-migratable backing.
        uint256 nonMigratableBacking = Math.mulDiv(customToken().totalSupply(), $.nonMigratableBackingPercentage, 1e18);

        // Return the amount of backing that can be migrated.
        return $.backingOnLayerY > nonMigratableBacking ? $.backingOnLayerY - nonMigratableBacking : 0;
    }

    /// @notice Migrates a specific amount of backing to Layer X.
    /// @notice This action provides vbToken liquidity on LxLy Bridge on Layer X.
    /// @notice The bridged asset and message must be claimed manually on LxLy Bridge on Layer X to complete the migration.
    /// @notice This function can be called by the migrator only.
    /// @notice The migration can be completed by anyone on Layer X.
    /// @dev Consider calling this function periodically; anyone can complete a migration on Layer X.
    function migrateBackingToLayerX(uint256 assets) external whenNotPaused onlyRole(MIGRATOR_ROLE) nonReentrant {
        NativeConverterStorage storage $ = _getNativeConverterStorage();

        // Cache the migratable backing.
        uint256 migratableBacking_ = migratableBacking();

        // Check the inputs.
        require(assets > 0, InvalidAssets());
        require(assets <= migratableBacking_, AssetsTooLarge(migratableBacking_, assets));

        // Update the backing data.
        $.backingOnLayerY -= assets;

        // Calculate the amount of Custom Token for which backing is being migrated.
        uint256 shares = _convertToShares(assets);

        // Bridge the backing to vbToken on Layer X.
        /* If the underlying token is not mintable by LxLy Bridge, we need to check for a transfer fee. */
        if ($._underlyingTokenIsNotMintable) {
            // Cache the balance.
            uint256 balanceBefore = $.underlyingToken.balanceOf(address($.lxlyBridge));

            // Bridge.
            // @note IMPORTANT: Make sure the underlying token you are integrating does not enable reentrancy on `transferFrom`.
            $.lxlyBridge.bridgeAsset($.layerXLxlyId, $.vbToken, assets, address($.underlyingToken), true, "");

            // Calculate the bridged amount.
            assets = $.underlyingToken.balanceOf(address($.lxlyBridge)) - balanceBefore;
        }
        /* If the underlying token is mintable by LxLy Bridge, it will be burned (not transferred). */
        else {
            $.lxlyBridge.bridgeAsset($.layerXLxlyId, $.vbToken, assets, address($.underlyingToken), true, "");
        }

        // Bridge a message to vbToken on Layer X to complete the migration.
        $.lxlyBridge.bridgeMessage(
            $.layerXLxlyId,
            $.vbToken,
            true,
            abi.encode(CrossNetworkInstruction.COMPLETE_MIGRATION, abi.encode(shares, assets))
        );

        // Emit the event.
        emit MigrationStarted(msg.sender, shares, assets);
    }

    /// @notice Sets the percentage of backing that should remain in Native Converter after a migration, based on the total supply of Custom Token.
    /// @notice It is possible to game the system by manipulating the total supply of Custom Token, so this is a soft limit.
    /// @notice This function can be called by the owner only.
    /// @param nonMigratableBackingPercentage_ 1e18 is 100%.
    function setNonMigratableBackingPercentage(uint256 nonMigratableBackingPercentage_)
        external
        whenNotPaused
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

    // -----================= ::: ADMIN ::: =================-----

    /// @notice Prevents usage of functions with the `whenNotPaused` modifier.
    /// @notice This function can be called by the pauser only.
    function pause() external onlyRole(PAUSER_ROLE) nonReentrant {
        _pause();
    }

    /// @notice Allows usage of functions with the `whenNotPaused` modifier.
    /// @notice This function can be called by the owner only.
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        _unpause();
    }

    // -----================= ::: DEVELOPER ::: =================-----

    /// @notice Transfers the underlying token from an external account to itself.
    /// @dev This function can be overridden to implement custom transfer logic.
    /// @dev @note CAUTION! This function MUST NOT introduce reentrancy/cross-entrancy vulnerabilities.
    /// @return receivedValue The amount of the underlying actually received (e.g., after transfer fees).
    function _receiveUnderlyingToken(address from, uint256 value) internal virtual returns (uint256 receivedValue) {
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
    /// @dev This function can be overridden to implement custom transfer logic.
    /// @dev @note CAUTION! This function MUST NOT introduce reentrancy/cross-entrancy vulnerabilities.
    function _sendUnderlyingToken(address to, uint256 value) internal virtual {
        NativeConverterStorage storage $ = _getNativeConverterStorage();

        // Transfer.
        // @note IMPORTANT: Make sure the underlying token you are integrating does not enable reentrancy on `transfer`.
        $.underlyingToken.safeTransfer(to, value);
    }
}
