// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.28;

// Main functionality.
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC20PermitUpgradeable} from
    "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

// Other functionality.
import {Initializable} from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ERC20PermitUser} from "./etc/ERC20PermitUser.sol";
import {IVersioned} from "./etc/IVersioned.sol";

// Libraries.
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// External contracts.
import {ILxLyBridge} from "./etc/ILxLyBridge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Other.
import {ERC20Upgradeable} from "@openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

/// @title Vault Backed Token
/// @notice A vbToken is an ERC-20 token, ERC-4626 vault, and LxLy Bridge extension, enabling deposits and bridging of select assets, such as WBTC, WETH, USDC, USDT, and DAI, while producing yield.
/// @dev A base contract used to create vault backed tokens.
/// @dev In order to not drive the complexity of the STB system up, vbToken MUST NOT have transfer, deposit, or withdrawal fees. The underlying token on Layer X, and the underlying token and Custom Token on Layer Ys MAY have transfer fees. The yield vault SHOULD NOT have deposit and/or withdrawal fees. The price of yield vault's shares MUST NOT decrease (e.g., due to bad debt realization).
/// @dev It is expected that generated yield will offset any costs incurred when transferring the underlying token to and from the yield vault, or depositing to and withdrawing from the yield vault for the purpose of generating yield or rebalancing reserve.
abstract contract VaultBackedToken is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    IERC4626,
    ERC20PermitUpgradeable,
    ERC20PermitUser,
    IVersioned
{
    // Libraries.
    using SafeERC20 for IERC20;

    /// @dev Used in cross-network communication.
    enum CrossNetworkInstruction {
        COMPLETE_MIGRATION,
        CUSTOM
    }

    /// @dev Used when setting Native Converter on Layer Ys.
    struct NativeConverter {
        uint32 layerYLxlyId;
        address nativeConverter;
    }

    /// @dev Storage of the Vault backed Token contract.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:0xpolygon.storage.YieldExposedToken
    struct VaultBackedTokenStorage {
        IERC20 underlyingToken;
        uint8 decimals;
        uint256 minimumReservePercentage;
        uint256 reservedAssets;
        IERC4626 yieldVault;
        address yieldRecipient;
        uint256 _netCollectedYield;
        uint32 lxlyId;
        ILxLyBridge lxlyBridge;
        mapping(uint32 layerYLxlyId => address nativeConverter) nativeConverters;
        uint256 migrationFeesFund;
        uint256 minimumYieldVaultDeposit;
        address transferFeeUtil;
    }

    // Todo fix slot while keeping weth intact
    /// @dev The storage slot at which Yield Exposed Token storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("0xpolygon.storage.YieldExposedToken")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _YIELD_EXPOSED_TOKEN_STORAGE =
        hex"ed23de664e59f2cbf6ba852da776346da171cf53c9d06b116fea0fc5ee912500";

    // Errors.
    error InvalidOwner();
    error InvalidName();
    error InvalidSymbol();
    error InvalidUnderlyingToken();
    error InvalidMinimumReservePercentage();
    error InvalidYieldVault();
    error InvalidYieldRecipient();
    error InvalidLxLyBridge();
    error InvalidNativeConverters();
    error InvalidAssets();
    error InvalidDestinationNetworkId();
    error InvalidReceiver();
    error InvalidPermitData();
    error InvalidShares();
    error IncorrectAmountOfSharesMinted(uint256 mintedShares, uint256 requiredShares);
    error AssetsTooLarge(uint256 availableAssets, uint256 requestedAssets);
    error IncorrectAmountOfSharesRedeemed(uint256 redeemedShares, uint256 requiredShares);
    error CannotRebalanceReserve();
    error NoNeedToReplenishReserve();
    error Unauthorized();
    error NoYield();
    error InvalidOriginNetwork();
    error CannotCompleteMigration(uint256 requiredAssets, uint256 receivedAssets, uint256 assetsInMigrationFund);
    error InsufficientYieldVaultSharesMinted(uint256 depositedAssets, uint256 mintedShares);
    error ExcessiveYieldVaultSharesBurned(uint256 burnedShares, uint256 withdrawnAssets);
    error CustomCrossNetworkInstructionNotSupported();

    // Events.
    event ReserveRebalanced(uint256 oldReservedAssets, uint256 newReservedAssets, uint256 reservePercentage);
    event YieldCollected(address indexed yieldRecipient, uint256 vbTokenAmount);
    event Burned(uint256 vbTokenAmount);
    event DonatedAsYield(address indexed who, uint256 assets);
    event DonatedForCompletingMigration(address indexed who, uint256 assets);
    event MigrationCompleted(
        uint32 indexed destinationNetworkId,
        uint256 indexed shares,
        uint256 assetsBeforeTransferFee,
        uint256 assets,
        uint256 usedYield
    );
    event YieldRecipientSet(address indexed yieldRecipient);
    event TransferFeeUtilSet(address transferFeeUtil);
    event MinimumReservePercentageSet(uint256 minimumReservePercentage);
    event NativeConverterSet(uint32 indexed layerYLxlyId, address nativeConverter);

    /// @dev @note (ATTENTION) `decimals` will match the underlying token. Defaults to 18 decimals if the underlying token reverts.
    /// @param minimumReservePercentage_ 1e18 is 100%.
    /// @param yieldVault_ An external, ERC-4246 compatible vault into which the underlying token is deposited to generate yield.
    /// @param yieldRecipient_ The address that receives yield generated by the yield vault. The owner collects generated yield, while the yield recipient receives it.
    /// @param nativeConverters_ The initial Native Converter on Layer Ys for this yeToken. One Layer Y cannot have more than one Native Converter.
    /// @param transferFeeUtil_ A dedicated fee calculator for covering the underlying token's transfer fees if the underlying token has a transfer fee. @note: If the underlying token does not have a transfer fee, set to address(0).
    function __VaultBackedToken_init(
        address owner_,
        string calldata name_,
        string calldata symbol_,
        address underlyingToken_,
        uint256 minimumReservePercentage_,
        address yieldVault_,
        address yieldRecipient_,
        address lxlyBridge_,
        NativeConverter[] calldata nativeConverters_,
        uint256 minimumYieldVaultDeposit_,
        address transferFeeUtil_
    ) internal onlyInitializing {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Check the inputs.
        require(owner_ != address(0), InvalidOwner());
        require(bytes(name_).length > 0, InvalidName());
        require(bytes(symbol_).length > 0, InvalidSymbol());
        require(underlyingToken_ != address(0), InvalidUnderlyingToken());
        require(minimumReservePercentage_ <= 1e18, InvalidMinimumReservePercentage());
        require(yieldVault_ != address(0), InvalidYieldVault());
        require(yieldRecipient_ != address(0), InvalidYieldRecipient());
        require(lxlyBridge_ != address(0), InvalidLxLyBridge());

        // Initialize the inherited contracts.
        __ERC20_init(name_, symbol_);
        __ERC20Permit_init(name_);
        __Ownable_init(owner_);
        __Pausable_init();
        __ReentrancyGuard_init();

        // Initialize the storage.
        $.underlyingToken = IERC20(underlyingToken_);
        try IERC20Metadata(underlyingToken_).decimals() returns (uint8 decimals_) {
            $.decimals = decimals_;
        } catch {
            // Default to 18 decimals.
            $.decimals = 18;
        }
        $.minimumReservePercentage = minimumReservePercentage_;
        $.yieldVault = IERC4626(yieldVault_);
        $.yieldRecipient = yieldRecipient_;
        $.lxlyId = ILxLyBridge(lxlyBridge_).networkID();
        $.lxlyBridge = ILxLyBridge(lxlyBridge_);
        for (uint256 i; i < nativeConverters_.length; ++i) {
            // Check the input.
            require(nativeConverters_[i].layerYLxlyId != $.lxlyId, InvalidNativeConverters());

            // Set Native Converter.
            $.nativeConverters[nativeConverters_[i].layerYLxlyId] = nativeConverters_[i].nativeConverter;
        }
        $.minimumYieldVaultDeposit = minimumYieldVaultDeposit_;
        $.transferFeeUtil = transferFeeUtil_;

        // Approve the yield vault and LxLy Bridge.
        IERC20(underlyingToken_).forceApprove(yieldVault_, type(uint256).max);
        _approve(address(this), address(lxlyBridge_), type(uint256).max);
    }

    // -----================= ::: STORAGE ::: =================-----

    /// @notice The underlying token that backs vbToken.
    function underlyingToken() public view returns (IERC20) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();
        return $.underlyingToken;
    }

    /// @notice The number of decimals of the yield exposed token.
    /// @notice The number of decimals is the same as that of the underlying token, or 18 if the underlying token reverted (e.g., does not implement `decimals`).
    function decimals() public view override(ERC20Upgradeable, IERC20Metadata) returns (uint8) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();
        return $.decimals;
    }

    /// @notice Yield exposed tokens have an internal reserve of the underlying token from which withdrawals are served first.
    /// @notice The owner can rebalance the reserve by calling `rebalanceReserve` when it is below or above the `minimumReservePercentage`.
    /// @notice 1e18 is 100%.
    function minimumReservePercentage() public view returns (uint256) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();
        return $.minimumReservePercentage;
    }

    /// @notice Yield exposed tokens have an internal reserve of the underlying token from which withdrawals are served first.
    /// @notice The owner can rebalance the reserve by calling `rebalanceReserve` when it is below or above the `minimumReservePercentage`.
    function reservedAssets() public view returns (uint256) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();
        return $.reservedAssets;
    }

    /// @notice An external, ERC-4246 compatible vault into which the underlying token is deposited to generate yield.
    function yieldVault() public view returns (IERC4626) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();
        return $.yieldVault;
    }

    /// @notice The address that receives yield generated by the yield vault.
    /// @notice The owner collects generated yield, while the yield recipient receives it.
    function yieldRecipient() public view returns (address) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();
        return $.yieldRecipient;
    }

    /// @notice The LxLy ID of this network.
    function lxlyId() public view returns (uint32) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();
        return $.lxlyId;
    }

    /// @notice LxLy Bridge, which connects AggLayer networks.
    function lxlyBridge() public view returns (ILxLyBridge) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();
        return $.lxlyBridge;
    }

    /// @notice The address of Native Converter on a Layer Y of this vbToken.
    /// @notice Native Converter on Layer Ys can mint Custom Token independently of vbToken, and migrate backing to Layer X. Please refer to `completeMigration` for more information.
    /// @return Returns address zero if there is no Native Converter set for Layer Y.
    function nativeConverters(uint32 layerYLxlyId) public view returns (address) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();
        return $.nativeConverters[layerYLxlyId];
    }

    /// @notice The address of the dedicated fee calculator for covering the underlying token's transfer fees.
    /// @notice If the underlying token does not have a transfer fee, this address is set to address(0).
    /// @return Returns the address of the dedicated fee calculator for covering the underlying token's transfer fees.
    function transferFeeUtil() public view returns (address) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();
        return $.transferFeeUtil;
    }

    /// @notice A dedicated fund for covering the underlying token's transfer fees during a migration from a Layer Y. Please refer to `_completeMigration` for more information.
    function migrationFeesFund() public view returns (uint256) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();
        return $.migrationFeesFund;
    }

    /// @notice The minimum deposit amount for triggering a yield vault deposit.
    /// @notice Amounts below this value will be reserved in full, regardless of the reserve percentage, in order to save gas for the user.
    function minimumYieldVaultDeposit() public view returns (uint256) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();
        return $.minimumYieldVaultDeposit;
    }

    /// @dev Returns a pointer to the ERC-7201 storage namespace.
    function _getVaultBackedTokenStorage() private pure returns (VaultBackedTokenStorage storage $) {
        assembly {
            $.slot := _YIELD_EXPOSED_TOKEN_STORAGE
        }
    }

    // -----================= ::: ERC-4626 ::: =================-----

    /// @notice The underlying token that backs vbToken.
    function asset() public view returns (address assetTokenAddress) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();
        return address($.underlyingToken);
    }

    /// @notice The real-time total backing of vbToken in the underlying token.
    function totalAssets() public view returns (uint256 totalManagedAssets) {
        return stakedAssets() + reservedAssets();
    }

    /// @notice Tells how much a specific amount of underlying token is worth in vbToken.
    /// @dev The underlying token backs vbToken 1:1.
    function convertToShares(uint256 assets) public pure returns (uint256 shares) {
        // @note CAUTION! Changing this function will affect the conversion rate for the entire contract, and may introduce bugs.
        shares = assets;
    }

    /// @notice Tells how much a specific amount of vbToken is worth in the underlying token.
    /// @dev vbToken is backed by the underlying token 1:1.
    function convertToAssets(uint256 shares) public pure returns (uint256 assets) {
        // @note CAUTION! Changing this function will affect the conversion rate for the entire contract, and may introduce bugs.
        assets = shares;
    }

    /// @notice How much underlying token can deposited for a specific user right now. (Depositing the underlying token mints vbToken).
    function maxDeposit(address) external view returns (uint256 maxAssets) {
        return paused() ? 0 : type(uint256).max;
    }

    /// @notice How much vbToken would be minted if a specific amount of the underlying token were deposited right now.
    function previewDeposit(uint256 assets) external view whenNotPaused returns (uint256 shares) {
        // Check the input.
        require(assets > 0, InvalidAssets());

        return convertToShares(_assetsAfterTransferFee(assets));
    }

    /// @notice Deposit a specific amount of the underlying token and mint vbToken.
    function deposit(uint256 assets, address receiver) external whenNotPaused nonReentrant returns (uint256 shares) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();
        (shares,) = _deposit(assets, $.lxlyId, receiver, false, 0);
    }

    /// @notice Deposit a specific amount of the underlying token, and bridge minted vbToken to another network.
    /// @dev If vbToken is custom mapped on LxLy Bridge on the other network, the user will receive Custom Token. Otherwise, they will receive wrapped vbToken.
    /// @dev The `receiver` in the ERC-4626 `Deposit` event will be this contract.
    function depositAndBridge(
        uint256 assets,
        address receiver,
        uint32 destinationNetworkId,
        bool forceUpdateGlobalExitRoot
    ) external whenNotPaused nonReentrant returns (uint256 shares) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Check the input.
        require(destinationNetworkId != $.lxlyId, InvalidDestinationNetworkId());

        (shares,) = _deposit(assets, destinationNetworkId, receiver, forceUpdateGlobalExitRoot, 0);
    }

    /// @notice Locks the underlying token, mints vbToken, and optionally bridges it to another network.
    /// @param maxShares Caps the amount of vbToken that is minted. Unused underlying token will be refunded to the sender. Set to `0` to disable.
    /// @dev If bridging to another network, the `receiver` in the ERC-4626 `Deposit` event will be this contract.
    function _deposit(
        uint256 assets,
        uint32 destinationNetworkId,
        address receiver,
        bool forceUpdateGlobalExitRoot,
        uint256 maxShares
    ) internal returns (uint256 shares, uint256 spentAssets) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Check the inputs.
        require(assets > 0, InvalidAssets());
        require(receiver != address(0), InvalidReceiver());
        require(receiver != address(this), InvalidReceiver());

        // Transfer the underlying token from the sender to self.
        assets = _receiveUnderlyingToken(msg.sender, assets);

        // Check for a refund.
        if (maxShares > 0) {
            // Calculate the required amount of the underlying token.
            uint256 requiredAssets = convertToAssets(maxShares);

            if (assets > requiredAssets) {
                // Calculate the difference.
                uint256 refund = assets - requiredAssets;

                // Refund the difference.
                _sendUnderlyingToken(msg.sender, refund);

                // Update the `assets`.
                assets = requiredAssets;
            }
        }

        // Set the return values.
        shares = convertToShares(assets);
        spentAssets = assets;

        // Check whether to skip depositing into the yield vault.
        if (assets >= $.minimumYieldVaultDeposit) {
            // Calculate the amount to reserve.
            uint256 assetsToReserve = _calculateAmountToReserve(assets, shares);

            // Update the reserve.
            $.reservedAssets += assetsToReserve;

            // Calculate the amount to try to deposit into the yield vault.
            uint256 assetsToDeposit = assets - assetsToReserve;

            // @todo Reentrancy?
            // Try to deposit into the yield vault.
            if (assetsToDeposit > 0) {
                $.reservedAssets += _depositIntoYieldVault(assetsToDeposit);
            }
        } else {
            // Update the reserve.
            $.reservedAssets += assets;
        }

        // Mint vbToken.
        if (destinationNetworkId != $.lxlyId) {
            // Mint to self.
            _mint(address(this), shares);

            //  Bridge to the receiver.
            $.lxlyBridge.bridgeAsset(
                destinationNetworkId, receiver, shares, address(this), forceUpdateGlobalExitRoot, ""
            );

            // Update the receiver.
            receiver = address(this);
        } else {
            // Mint to the receiver.
            _mint(receiver, shares);
        }

        // Emit the ERC-4626 event.
        emit IERC4626.Deposit(msg.sender, receiver, assets, shares);
    }

    /// @notice Deposit a specific amount of the underlying token and mint vbToken.
    /// @dev Uses EIP-2612 permit to transfer the underlying token from the sender to self.
    function depositWithPermit(uint256 assets, address receiver, bytes calldata permitData)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 shares)
    {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();
        (shares,) = _depositWithPermit(assets, permitData, $.lxlyId, receiver, false, 0);
    }

    /// @notice Deposit a specific amount of the underlying token, and bridge minted vbToken to another network.
    /// @dev If vbToken is custom mapped on LxLy Bridge on the other network, the user will receive Custom Token. Otherwise, they will receive wrapped vbToken.
    /// @dev Uses EIP-2612 permit to transfer the underlying token from the sender to self.
    /// @dev The `receiver` in the ERC-4626 `Deposit` event will be this contract.
    function depositWithPermitAndBridge(
        uint256 assets,
        address receiver,
        uint32 destinationNetworkId,
        bool forceUpdateGlobalExitRoot,
        bytes calldata permitData
    ) external whenNotPaused nonReentrant returns (uint256 shares) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Check the input.
        require(destinationNetworkId != $.lxlyId, InvalidDestinationNetworkId());

        (shares,) = _depositWithPermit(assets, permitData, destinationNetworkId, receiver, forceUpdateGlobalExitRoot, 0);
    }

    /// @notice Locks the underlying token, mints vbToken, and optionally bridges it to another network.
    /// @param maxShares Caps the amount of vbToken that is minted. Unused underlying token will be refunded to the sender. Set to `0` to disable.
    /// @dev Uses EIP-2612 permit to transfer the underlying token from the sender to self.
    function _depositWithPermit(
        uint256 assets,
        bytes calldata permitData,
        uint32 destinationNetworkId,
        address receiver,
        bool forceUpdateGlobalExitRoot,
        uint256 maxShares
    ) internal returns (uint256 shares, uint256 spentAssets) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Check the input.
        require(permitData.length > 0, InvalidPermitData());

        // Use the permit.
        _permit(address($.underlyingToken), assets, permitData);

        return _deposit(assets, destinationNetworkId, receiver, forceUpdateGlobalExitRoot, maxShares);
    }

    /// @notice How much vbToken can be minted to a specific user right now. (Minting vbToken locks the underlying token).
    function maxMint(address) external view returns (uint256 maxShares) {
        return paused() ? 0 : type(uint256).max;
    }

    /// @notice How much underlying token would be required to mint a specific amount of vbToken right now.
    function previewMint(uint256 shares) external view whenNotPaused returns (uint256 assets) {
        // Check the input.
        require(shares > 0, InvalidShares());

        return _assetsBeforeTransferFee(convertToAssets(shares));
    }

    /// @notice Mint a specific amount of vbToken by locking the required amount of the underlying token.
    function mint(uint256 shares, address receiver) external whenNotPaused nonReentrant returns (uint256 assets) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Check the input.
        require(shares > 0, InvalidShares());

        // Mint vbToken to the receiver.
        uint256 mintedShares;
        (mintedShares, assets) =
            _deposit(_assetsBeforeTransferFee(convertToAssets(shares)), $.lxlyId, receiver, false, shares);

        // Check the output.
        require(mintedShares == shares, IncorrectAmountOfSharesMinted(mintedShares, shares));
    }

    /// @notice How much underlying token can be withdrawn from a specific user right now. (Withdrawing the underlying token burns vbToken).
    function maxWithdraw(address owner) external view returns (uint256 maxAssets) {
        // Return zero if the contract is paused.
        if (paused()) return 0;

        // Return zero if the balance is zero.
        uint256 shares = balanceOf(owner);
        if (shares == 0) return 0;

        // Return the maximum amount that can be withdrawn.
        return _simulateWithdraw(convertToAssets(shares), false);
    }

    /// @notice How much vbToken would be burned if a specific amount of the underlying token were withdrawn right now.
    function previewWithdraw(uint256 assets) external view whenNotPaused returns (uint256 shares) {
        return convertToShares(_simulateWithdraw(assets, true));
    }

    /// @dev Calculates the amount of the underlying token that could be withdrawn right now.
    /// @dev This function is used for estimation purposes only.
    /// @param assets The maximum amount of the underlying token to simulate a withdrawal for.
    /// @param force Whether to revert if the all of the `assets` would not be withdrawn.
    function _simulateWithdraw(uint256 assets, bool force) internal view returns (uint256 withdrawnAssets) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Check the input.
        require(assets > 0, InvalidAssets());

        // The amount that cannot be withdrawn at the moment.
        uint256 remainingAssets = assets;

        // Simulate withdrawal from the reserve.
        if ($.reservedAssets >= remainingAssets) return assets;
        remainingAssets -= $.reservedAssets;

        // Simulate withdrawal from the yield vault.
        // @note Yield vault usage.
        uint256 maxWithdraw_ = $.yieldVault.maxWithdraw(address(this));
        maxWithdraw_ = remainingAssets > maxWithdraw_ ? maxWithdraw_ : remainingAssets;
        if (remainingAssets == maxWithdraw_) return assets;
        remainingAssets -= maxWithdraw_;

        // Set the return value (the amount of the underlying token that can be withdrawn right now).
        withdrawnAssets = assets - remainingAssets;

        // Revert if all of the `assets` must have been withdrawn and there is a remaining amount.
        if (force) require(remainingAssets == 0, AssetsTooLarge(withdrawnAssets, assets));
    }

    /// @notice Withdraw a specific amount of the underlying token by burning the required amount of vbToken.
    /// @notice Transfer fees of the underlying token may apply.
    function withdraw(uint256 assets, address receiver, address owner)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 shares)
    {
        return _withdraw(assets, receiver, owner);
    }

    /// @notice Withdraw a specific amount of the underlying token by burning the required amount of vbToken.
    function _withdraw(uint256 assets, address receiver, address owner) internal returns (uint256 shares) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Check the inputs.
        require(assets > 0, InvalidAssets());
        require(receiver != address(0), InvalidReceiver());
        require(owner != address(0), InvalidOwner());

        // Cache the total supply and uncollected yield.
        uint256 originalTotalSupply = totalSupply();
        uint256 originalYield = yield();

        // Set the return value.
        shares = convertToShares(assets);

        // Check the input.
        if (msg.sender != owner) _spendAllowance(owner, msg.sender, shares);

        // The amount that cannot be withdrawn at the moment.
        uint256 remainingAssets = assets;

        // Calculate the amount to withdraw from the reserve.
        uint256 amountToWithdraw = $.reservedAssets > remainingAssets ? remainingAssets : $.reservedAssets;

        // Withdraw the underlying token from the reserve.
        if (amountToWithdraw > 0) {
            // Burn vbToken.
            _burn(owner, convertToShares(amountToWithdraw));

            // Update the reserve.
            $.reservedAssets -= amountToWithdraw;

            // Withdraw to the receiver.
            _sendUnderlyingToken(receiver, amountToWithdraw);

            // Check if the amount in the reserve was sufficient.
            if (amountToWithdraw == remainingAssets) {
                // Emit the ERC-4626 event and return.
                emit IERC4626.Withdraw(msg.sender, receiver, owner, assets, shares);
                return shares;
            }

            // Update the remaining assets.
            remainingAssets -= amountToWithdraw;
        }

        // Calculate the amount to withdraw from the yield vault.
        // @note Yield vault usage.
        uint256 maxWithdraw_ = $.yieldVault.maxWithdraw(address(this));

        // Withdraw the underlying token from the yield vault.
        if (maxWithdraw_ >= remainingAssets) {
            // Burn vbToken.
            _burn(owner, convertToShares(remainingAssets));

            // Withdraw to the receiver.
            _withdrawFromYieldVault(remainingAssets, receiver, originalTotalSupply, originalYield);

            // Emit the ERC-4626 event.
            emit IERC4626.Withdraw(msg.sender, receiver, owner, assets, shares);

            // Return the amount of vbToken burned.
            return shares;
        } else {
            // Update the remaining assets.
            remainingAssets -= maxWithdraw_;

            // Revert if all of the `assets` could not be withdrawn.
            revert AssetsTooLarge(assets - remainingAssets, assets);
        }
    }

    /// @notice How much vbToken can be redeemed for a specific user. (Redeeming vbToken burns it and unlocks the underlying token).
    function maxRedeem(address owner) external view returns (uint256 maxShares) {
        // Return zero if the contract is paused.
        if (paused()) return 0;

        // Return zero if the balance is zero.
        uint256 shares = balanceOf(owner);
        if (shares == 0) return 0;

        // Return the maximum amount that can be redeemed.
        return convertToShares(_simulateWithdraw(convertToAssets(shares), false));
    }

    /// @notice How much underlying token would be unlocked if a specific amount of vbToken were redeemed and burned right now.
    function previewRedeem(uint256 shares) external view whenNotPaused returns (uint256 assets) {
        // Check the input.
        require(shares > 0, InvalidShares());

        return _simulateWithdraw(convertToAssets(shares), true);
    }

    /// @notice Burn a specific amount of vbToken and unlock the respective amount of the underlying token.
    /// @notice Transfer fees of the underlying token may apply.
    function redeem(uint256 shares, address receiver, address owner)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 assets)
    {
        // Check the input.
        require(shares > 0, InvalidShares());

        // Set the return value.
        assets = convertToAssets(shares);

        // Burn vbToken and unlock the underlying token.
        uint256 redeemedShares = _withdraw(assets, receiver, owner);

        // Check the output.
        require(redeemedShares == shares, IncorrectAmountOfSharesRedeemed(redeemedShares, shares));
    }

    /// @notice Claim vbToken from LxLy Bridge and redeem it.
    /// @notice Transfer fees of the underlying token may apply.
    function claimAndRedeem(
        bytes32[32] calldata smtProofLocalExitRoot,
        bytes32[32] calldata smtProofRollupExitRoot,
        uint256 globalIndex,
        bytes32 mainnetExitRoot,
        bytes32 rollupExitRoot,
        address destinationAddress,
        uint256 amount,
        address receiver,
        bytes memory metadata
    ) external whenNotPaused nonReentrant returns (uint256 assets) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Claim vbToken from LxLy Bridge.
        // @todo Review the hardcoded values.
        $.lxlyBridge.claimAsset(
            smtProofLocalExitRoot,
            smtProofRollupExitRoot,
            globalIndex,
            mainnetExitRoot,
            rollupExitRoot,
            $.lxlyId,
            address(this),
            $.lxlyId,
            destinationAddress,
            amount,
            // Todo: use the old optimization, but first fix test correctly
            metadata
        );

        // Set the return value.
        assets = convertToAssets(amount);

        // Burn vbToken and unlock the underlying token.
        uint256 redeemedShares = _withdraw(amount, receiver, destinationAddress);

        // Check the output.
        require(redeemedShares == amount, IncorrectAmountOfSharesRedeemed(redeemedShares, amount));
    }

    // -----================= ::: ERC-20 ::: =================-----

    /// @dev Pausable ERC-20 `transfer` function.
    function transfer(address to, uint256 value)
        public
        virtual
        override(ERC20Upgradeable, IERC20)
        whenNotPaused
        returns (bool)
    {
        return ERC20Upgradeable.transfer(to, value);
    }

    /// @dev Pausable ERC-20 `transferFrom` function.
    function transferFrom(address from, address to, uint256 value)
        public
        virtual
        override(ERC20Upgradeable, IERC20)
        whenNotPaused
        returns (bool)
    {
        return ERC20Upgradeable.transferFrom(from, to, value);
    }

    /// @dev Pausable ERC-20 `approve` function.
    function approve(address spender, uint256 value)
        public
        virtual
        override(ERC20Upgradeable, IERC20)
        whenNotPaused
        returns (bool)
    {
        return ERC20Upgradeable.approve(spender, value);
    }

    /// @dev Pausable ERC-20 Permit `permit` function.
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        public
        virtual
        override
        whenNotPaused
    {
        super.permit(owner, spender, value, deadline, v, r, s);
    }

    // -----================= ::: YIELD EXPOSED TOKEN ::: =================-----

    /// @notice The real-time amount of the underlying token in the yield vault, as reported by the yield vault.
    function stakedAssets() public view returns (uint256) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();
        return $.yieldVault.convertToAssets($.yieldVault.balanceOf(address(this)));
    }

    /// @notice The real-time reserve percentage.
    /// @notice The reserve is based on the total supply of vbToken, and does not account for uncompleted migrations of backing from Layer Ys to Layer X. Please refer to `completeMigration` for more information.
    function reservePercentage() public view returns (uint256) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Return zero if the total supply is zero.
        if (totalSupply() == 0) return 0;

        // Calculate the reserve percentage.
        return Math.mulDiv($.reservedAssets, 1e18, convertToAssets(totalSupply()));
    }

    /// @notice The real-time amount of yield available for collection.
    function yield() public view returns (uint256) {
        // The formula for calculating yield is:
        // yield = assets reported by yield vault + reserved assets - vbToken total supply in assets
        (bool positive, uint256 difference) = backingDifference();

        // Returns zero if the backing is negative.
        return positive ? difference : 0;
    }

    /// @notice The real-time difference between the total assets and the minimum assets required to back the total supply of vbToken.
    function backingDifference() public view returns (bool positive, uint256 difference) {
        // Get the state.
        uint256 totalAssets_ = totalAssets();
        uint256 minimumAssets = convertToAssets(totalSupply());

        // Calculate the difference.
        return
            totalAssets_ >= minimumAssets ? (true, totalAssets_ - minimumAssets) : (false, minimumAssets - totalAssets_);
    }

    /// @notice Rebalances the internal reserve by withdrawing the underlying token from, or depositing the underlying token into, the yield vault.
    /// @notice This function can be called by the owner only.
    function rebalanceReserve() external whenNotPaused onlyOwner nonReentrant {
        _rebalanceReserve(true, true);
    }

    /// @notice Rebalances the internal reserve by withdrawing the underlying token from, or depositing the underlying token into, the yield vault.
    /// @param force Whether to revert if the reserve cannot be rebalanced.
    /// @param allowRebalanceDown Whether to allow the reserve to be rebalanced down (by depositing into the yield vault).
    function _rebalanceReserve(bool force, bool allowRebalanceDown) internal {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Cache the reserved assets, total supply, and uncollected yield.
        uint256 originalReservedAssets = $.reservedAssets;
        uint256 originalTotalSupply = totalSupply();
        uint256 originalYield = yield();

        // Calculate the minimum reserve amount.
        uint256 minimumReserve = convertToAssets(Math.mulDiv(totalSupply(), $.minimumReservePercentage, 1e18));

        // Check if the reserve is below, above, or at the minimum threshold.
        /* Below. */
        if (originalReservedAssets < minimumReserve) {
            // Calculate the amount to try to withdraw from the yield vault.
            uint256 shortfall = minimumReserve - originalReservedAssets;
            // @note Yield vault usage.
            uint256 maxWithdraw_ = $.yieldVault.maxWithdraw(address(this));
            uint256 assetsToWithdraw = shortfall > maxWithdraw_ ? maxWithdraw_ : shortfall;

            // Try to withdraw from the yield vault.
            if (assetsToWithdraw > 0) {
                // @todo Reentrancy?
                // Withdraw.
                uint256 withdrawnAssets =
                    _withdrawFromYieldVault(assetsToWithdraw, address(this), originalTotalSupply, originalYield);

                // Update the reserve.
                $.reservedAssets += withdrawnAssets;

                // Emit the event.
                emit ReserveRebalanced(originalReservedAssets, $.reservedAssets, reservePercentage());
            } else if (force) {
                revert CannotRebalanceReserve();
            }
        }
        /* Above */
        else if (originalReservedAssets > minimumReserve && allowRebalanceDown) {
            // Calculate the amunt to try to deposit into the yield vault.
            uint256 excess = originalReservedAssets - minimumReserve;
            // @note Yield vault usage.
            uint256 maxDeposit_ = $.yieldVault.maxDeposit(address(this));
            uint256 assetsToDeposit = excess > maxDeposit_ ? maxDeposit_ : excess;

            // Try to deposit into the yield vault.
            if (assetsToDeposit > 0) {
                // @todo Reentrancy?
                // Deposit.
                $.reservedAssets -= _depositIntoYieldVault(assetsToDeposit);

                // Update the reserve.
                $.reservedAssets -= assetsToDeposit;

                // Emit the event.
                emit ReserveRebalanced(originalReservedAssets, $.reservedAssets, reservePercentage());
            } else if (force) {
                revert CannotRebalanceReserve();
            }
        }
        /* At. */
        else if (force) {
            revert NoNeedToReplenishReserve();
        }
    }

    /// @notice Transfers yield generated by the yield vault to the yield recipient in the form of vbToken.
    /// @notice The reserve will be rebalanced after collecting yield.
    /// @notice This function can be called by the owner only.
    function collectYield() external whenNotPaused onlyOwner nonReentrant {
        _collectYield(true);
    }

    /// @notice Transfers yield generated by the yield vault to the yield recipient in the form of vbToken.
    /// @notice The reserve will be rebalanced after collecting yield.
    /// @param force Whether to revert if no yield can be collected.
    function _collectYield(bool force) internal {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Calculate the yield.
        uint256 yield_ = yield();

        if (yield_ > 0) {
            // Update the net collected yield.
            $._netCollectedYield += yield_;

            // Mint vbToken to the yield recipient.
            _mint($.yieldRecipient, yield_);

            // Emit the event.
            emit YieldCollected(yieldRecipient(), yield_);
        } else if (force) {
            revert NoYield();
        }

        // Try to rebalance the reserve.
        _rebalanceReserve(false, true);
    }

    /// @notice Burns a specific amount of vbToken.
    /// @notice This function can be used if the yield recipient has collected an unrealistic (excessive) amount of yield historically.
    /// @notice The reserve will be rebalanced after burning vbToken.
    /// @notice This function can be called by the yield recipient only.
    function burn(uint256 shares) external nonReentrant {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Check the inputs.
        require(msg.sender == $.yieldRecipient, Unauthorized());
        require(shares > 0, InvalidShares());

        // Update the net collected yield.
        $._netCollectedYield -= shares;

        // Burn vbToken.
        _burn(msg.sender, shares);

        // Try to rebalance the reserve.
        _rebalanceReserve(false, true);

        // Emit the event.
        emit Burned(shares);
    }

    /// @notice Adds a specific amount of the underlying token to the reserve by transferring it from the sender.
    /// @notice This function can be used to restore backing difference by donating the underlying token.
    /// @notice This function can be called by anyone.
    function donateAsYield(uint256 assets) external nonReentrant {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Check the input.
        require(assets > 0, InvalidAssets());

        // Transfer the underlying token from the sender to self.
        assets = _receiveUnderlyingToken(msg.sender, assets);

        // Update the reserve.
        $.reservedAssets += assets;

        // Emit the event.
        emit DonatedAsYield(msg.sender, assets);
    }

    /// @notice Receives and dispatches a cross-network instruction.
    /// @dev This function can be called by LxLy Bridge only.
    /// @dev @note CAUTION! Do not forget to verify the `originAddress` and `originNetwork` - otherwise, an attacker could gain access unauthorized access to vbToken and other contracts.
    function onMessageReceived(address originAddress, uint32 originNetwork, bytes memory data)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Check the input.
        require(msg.sender == address($.lxlyBridge), Unauthorized());

        // Decode the cross-network instruction.
        (CrossNetworkInstruction instruction, bytes memory instructionData) =
            abi.decode(data, (CrossNetworkInstruction, bytes));

        // Dispatch.
        /* Complete migration. */
        if (instruction == CrossNetworkInstruction.COMPLETE_MIGRATION) {
            // Check the input.
            require(originAddress != address(0), Unauthorized());
            require(originAddress == $.nativeConverters[originNetwork], Unauthorized());

            // Decode the amounts.
            (uint256 shares, uint256 assets) = abi.decode(instructionData, (uint256, uint256));

            // Complete the migration.
            _completeMigration(originNetwork, shares, assets);
        }
        /* Custom. */
        else if (instruction == CrossNetworkInstruction.CUSTOM) {
            // Unsupported by default - the call will revert.
            // Please refer to `_dispatchCustomCrossNetworkInstruction` for more information.
            _dispatchCustomCrossNetworkInstruction(originAddress, originNetwork, instructionData);
        }
    }

    /// @notice Completes a migration of backing from a Layer Y to Layer X by minting and locking the required amount of vbToken in LxLy Bridge.
    /// @notice Anyone can trigger the execution of this function by claiming the asset and message on LxLy Bridge. Please refer to `NativeConverter.sol` for more information.
    /// @dev Backing for Custom Token minted by Native Converter on Layer Ys can be migrated to Layer X.
    /// @dev When Native Converter migrates backing, it calls both `bridgeAsset` and `bridgeMessage` on LxLy Bridge to `migrateBackingToLayerX`.
    /// @dev The asset must be claimed before the message on LxLy Bridge.
    /// @dev The message tells vbToken how much Custom Token must be backed by vbToken, which is minted and bridged to address zero on the respective Layer Y. This action provides liquidity when bridging Custom Token to from Layer Ys to Layer X and increments the pessimistic proof.
    /// @param originNetwork The LxLy ID of Layer Y the backing is being migrated from.
    /// @param shares The required amount of vbToken to mint and lock up in LxLy Bridge. Assets from a dedicated migration fees fund may be used to offset transfer fees of the underlying token. If a migration cannot be completed due to insufficient assets, anyone can donate the underlying token to the migration fees fund. Please refer to `donateForCompletingMigration` for more information.
    /// @param assets The amount of the underlying token migrated from Layer Y (before transfer fees on Layer X).
    function _completeMigration(uint32 originNetwork, uint256 shares, uint256 assets) internal {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Cache the original `assets`.
        uint256 assetsBeforeTransferFee = assets;

        // Modify the input.
        // Accounts for a transfer fee when the `assets` were claimed from LxLy Bridge.
        assets = _assetsAfterTransferFee(assets);

        // Check the inputs.
        require(originNetwork != $.lxlyId, InvalidOriginNetwork());
        require(shares > 0, InvalidShares());

        // Calculate the discrepancy between the required amount of vbToken (`shares`) and the amount of the underlying token received from LxLy Bridge (`assets`).
        // A discrepancy is possible due to transfer fees of the underlying token. To offset the discrepancy, we mint more vbToken, backed by assets from the dedicated migration fees fund.
        // This ensures that the amount of vbToken locked up in LxLy Bridge on Layer X matches the supply of Custom Token on Layer Ys exactly.
        uint256 requiredAssets = convertToAssets(shares);
        uint256 discrepancy = requiredAssets - assets;
        uint256 assetsInMigrationFund = $.migrationFeesFund;
        if (discrepancy > 0) {
            require(
                assetsInMigrationFund >= discrepancy,
                CannotCompleteMigration(requiredAssets, assets, assetsInMigrationFund)
            );
        }

        // Move the discrepancy from the migration fees fund to the reserve.
        $.migrationFeesFund -= discrepancy;
        $.reservedAssets += discrepancy;

        // Calculate the amount to reserve.
        uint256 assetsToReserve = _calculateAmountToReserve(assets, shares);

        // Calculate the amount to try to deposit into the yield vault.
        uint256 assetsToDeposit = assets - assetsToReserve;

        // @todo Reentrancy?
        // Try to deposit into the yield vault.
        if (assetsToDeposit > 0) {
            $.reservedAssets += _depositIntoYieldVault(assetsToDeposit);
        }

        // Update the reserve.
        $.reservedAssets += assetsToReserve;

        // Mint vbToken to self and bridge it to address zero on the origin network.
        // The vbToken will not be claimable on the origin network, but provides liquidity when bridging from Layer Ys to Layer X and increments the pessimistic proof.
        _mint(address(this), shares);
        $.lxlyBridge.bridgeAsset(originNetwork, address(0), shares, address(this), true, "");

        // Emit the ERC-4626 event.
        emit IERC4626.Deposit(msg.sender, address(this), assets, shares);

        // Emit the event.
        emit MigrationCompleted(originNetwork, shares, assetsBeforeTransferFee, assets, discrepancy);
    }

    /// @notice Adds a specific amount of the underlying token to a dedicated fund for covering the underlying token's transfer fees during a migration by transferring it from the sender. Please refer to `_completeMigration` for more information.
    function donateForCompletingMigration(uint256 assets) external whenNotPaused nonReentrant {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Check the input.
        require(assets > 0, InvalidAssets());

        // Transfer the underlying token from the sender to self.
        assets = _receiveUnderlyingToken(msg.sender, assets);

        // Update the migration fees fund.
        $.migrationFeesFund += assets;

        // Emit the event.
        emit DonatedForCompletingMigration(msg.sender, assets);
    }

    /// @notice Sets the yield recipient.
    /// @notice Yield will be collected before changing the recipient.
    /// @notice This function can be called by the owner only.
    function setYieldRecipient(address yieldRecipient_) external whenNotPaused onlyOwner nonReentrant {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Check the input.
        require(yieldRecipient_ != address(0), InvalidYieldRecipient());

        // Try to collect yield.
        _collectYield(false);

        // Set the yield recipient.
        $.yieldRecipient = yieldRecipient_;

        // Emit the event.
        emit YieldRecipientSet(yieldRecipient_);
    }

    /// @notice Sets the transfer fee util address.
    /// @param transferFeeUtil_ The address of the transfer fee util contract.
    /// @notice This function can be called by the owner only.
    /// @dev No need to check for zero address as the zero address would mean no transfer fee.
    function setTransferFeeUtil(address transferFeeUtil_) external onlyOwner {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Set the transfer fee util.
        $.transferFeeUtil = transferFeeUtil_;

        // Emit the event.
        emit TransferFeeUtilSet(transferFeeUtil_);
    }

    /// @notice Sets the minimum reserve percentage.
    /// @notice The reserve will be rebalanced after changing the minimum reserve percentage.
    /// @notice This function can be called by the owner only.
    function setMinimumReservePercentage(uint256 minimumReservePercentage_)
        external
        whenNotPaused
        onlyOwner
        nonReentrant
    {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Check the input.
        require(minimumReservePercentage_ <= 1e18, InvalidMinimumReservePercentage());

        // Set the minimum reserve percentage.
        $.minimumReservePercentage = minimumReservePercentage_;

        // Try to rebalance the reserve.
        _rebalanceReserve(false, true);

        // Emit the event.
        emit MinimumReservePercentageSet(minimumReservePercentage_);
    }

    /// @notice Sets Native Converter on Layer Ys. One Layer Y cannot have more than one Native Converter.
    /// @notice This function can be called by the owner only.
    function setNativeConverters(NativeConverter[] calldata nativeConverters_) external onlyOwner nonReentrant {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Check the input.
        require(nativeConverters_.length > 0, InvalidNativeConverters());

        // Set the native converters.
        for (uint256 i; i < nativeConverters_.length; ++i) {
            // Check the input.
            require(nativeConverters_[i].layerYLxlyId != $.lxlyId, InvalidNativeConverters());

            // Set Native Converter.
            $.nativeConverters[nativeConverters_[i].layerYLxlyId] = nativeConverters_[i].nativeConverter;

            // Emit the event.
            emit NativeConverterSet(nativeConverters_[i].layerYLxlyId, nativeConverters_[i].nativeConverter);
        }
    }

    /// @notice Sets the minimum deposit amount that triggers a yield vault deposit.
    /// @notice This function can be called by the owner only.
    function setMinimumDepositAmount(uint256 minimumYieldVaultDeposit_) external whenNotPaused onlyOwner nonReentrant {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();
        $.minimumYieldVaultDeposit = minimumYieldVaultDeposit_;
    }

    /// @notice Calculates the amount of assets to reserve (as opposed to depositing into the yield vault).
    /// @dev @note (ATTENTION) Make any necessary changes to the reserve prior to using this function.
    /// @param assets The amount of the underlying token being deposited.
    /// @param nonMintedShares The amount of vbToken that will be minted after using this function, as a result of the deposit.
    function _calculateAmountToReserve(uint256 assets, uint256 nonMintedShares)
        internal
        view
        returns (uint256 assetsToReserve)
    {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Calculate the minimum reserve.
        uint256 minimumReserve = Math.mulDiv(totalSupply() + nonMintedShares, $.minimumReservePercentage, 1e18);

        // Calculate the amount to reserve.
        assetsToReserve = $.reservedAssets < minimumReserve ? minimumReserve - $.reservedAssets : 0;
        return assetsToReserve <= assets ? assetsToReserve : assets;
    }

    /// @notice Deposits a specific amount of the underlying token into the yield vault.
    /// @param assets The amount of the underlying token to deposit into the yield vault.
    function _depositIntoYieldVault(uint256 assets) internal returns (uint256 nonDepositedAssets) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Calculate the amount to deposit into the yield vault.
        // @note Yield vault usage.
        uint256 maxDeposit_ = $.yieldVault.maxDeposit(address(this));
        nonDepositedAssets = assets > maxDeposit_ ? assets - maxDeposit_ : 0;
        assets = assets > maxDeposit_ ? maxDeposit_ : assets;

        // Cache the balance.
        uint256 balanceBefore = $.underlyingToken.balanceOf(address(this));

        // Deposit.
        uint256 mintedYieldVaultShares = $.yieldVault.deposit(assets, address(this));

        // Check the output.
        // This code checks if the minted yield vault shares are worth enough in the underlying token, on average. Allows for 1% slippage.
        require(
            $.yieldVault.convertToAssets(mintedYieldVaultShares)
                >= Math.mulDiv(_assetsAfterTransferFee(assets), 0.99e18, 1e18),
            InsufficientYieldVaultSharesMinted(assets, mintedYieldVaultShares)
        );

        // Check the accounting.
        assert(balanceBefore - $.underlyingToken.balanceOf(address(this)) == assets);
    }

    /// @notice Withdraws a specific amount of the underlying token from the yield vault.
    /// @param assets The amount of the underlying token to withdraw from the yield vault.
    /// @param receiver The address to withdraw the underlying token to.
    /// @param originalTotalSupply The total supply of vbToken before burning the required amount of vbToken or updating the reserve.
    /// @param originalYield The uncollected yield before burning the required amount of vbToken or updating the reserve.
    /// @return withdrawnAssets The amount of the underlying token actually withdrawn from the yield vault.
    function _withdrawFromYieldVault(
        uint256 assets,
        address receiver,
        uint256 originalTotalSupply,
        uint256 originalYield
    ) internal returns (uint256 withdrawnAssets) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Cache the underlying token balance and yield vault shares balance.
        uint256 underlyingTokenBalanceBefore = $.underlyingToken.balanceOf(address(this));
        uint256 yieldVaultSharesBalanceBefore = $.yieldVault.balanceOf(address(this));

        // @todo Reentrancy?
        // Withdraw.
        uint256 burnedYieldVaultShares = $.yieldVault.withdraw(assets, receiver, address(this));

        // Check the output.
        // This code checks if the contract would go insolvent if the total supply, including uncollected yield, were withdrawn. Allows for 1% slippage.
        // require( // TODO: Fix this check
        //     Math.mulDiv(
        //         burnedYieldVaultShares,
        //         convertToAssets(Math.mulDiv(originalTotalSupply + originalYield, 0.99e18, 1e18)),
        //         assets
        //     ) <= yieldVaultSharesBalanceBefore,
        //     ExcessiveYieldVaultSharesBurned(burnedYieldVaultShares, assets)
        // );

        // Calculate the withdrawn amount.
        withdrawnAssets = $.underlyingToken.balanceOf(address(this)) - underlyingTokenBalanceBefore;
    }

    // -----================= ::: ADMIN ::: =================-----

    /// @notice Prevents usage of functions with the `whenNotPaused` modifier.
    /// @notice This function can be called by the owner only.
    function pause() external onlyOwner nonReentrant {
        _pause();
    }

    /// @notice Allows usage of functions with the `whenNotPaused` modifier.
    /// @notice This function can be called by the owner only.
    function unpause() external onlyOwner nonReentrant {
        _unpause();
    }

    // -----================= ::: DEVELOPER ::: =================-----

    /// @notice Transfers the underlying token from an external account to self.
    /// @dev This function can be overridden to implement custom transfer logic.
    /// @dev @note CAUTION! This function MUST NOT introduce reentrancy/cross-entrancy vulnerabilities.
    /// @return receivedValue The amount of the underlying token actually received (e.g., after a transfer fee).
    function _receiveUnderlyingToken(address from, uint256 value) internal virtual returns (uint256 receivedValue) {
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

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
        VaultBackedTokenStorage storage $ = _getVaultBackedTokenStorage();

        // Transfer.
        // @note IMPORTANT: Make sure the underlying token you are integrating does not enable reentrancy on `transfer`.
        $.underlyingToken.safeTransfer(to, value);
    }

    /// @notice Dispatches a custom cross-network instruction.
    /// @dev This function can be overridden to add custom cross-network instructions.
    /// @dev @note CAUTION! Do not forget to verify the `originAddress` and `originNetwork` - otherwise, an attacker could gain access unauthorized access to vbToken and other contracts.
    /// @dev @note IMPORTANT: This function MUST revert if the custom cross-network instruction is not supported.
    /// @param customData The data that was appended to the `CUSTOM` cross-network instruction.
    function _dispatchCustomCrossNetworkInstruction(
        address originAddress,
        uint32 originNetwork,
        bytes memory customData
    ) internal virtual {
        // Silence the compiler.
        {
            originAddress;
            originNetwork;
            customData;
        }

        // `CUSTOM` cross-network instruction are not supported by default.
        revert CustomCrossNetworkInstructionNotSupported();
    }

    /// @notice Accounts for the transfer fee of the underlying token.
    /// @dev You must implement the same behavior as that of the underlying token for calculating the transfer fee.
    /// @dev If the underlying token does not have a transfer fee, the output must equal the input.
    /// @dev This function is used for estimation purposes only.
    /// @dev Example:
    /// @dev Fee: 2% flat
    /// @dev Input: `100`
    /// @dev Output: `98`
    function _assetsAfterTransferFee(uint256 assetsBeforeTransferFee) internal view virtual returns (uint256);

    /// @notice Accounts for the transfer fee of the underlying token.
    /// @dev You must implement the same behavior as that of the underlying token for calculating the transfer fee.
    /// @dev If the underlying token does not have a transfer fee, the output must equal the input.
    /// @dev This function is used for estimation purposes only.
    /// @dev Example:
    /// @dev Fee: 2% flat
    /// @dev Input:  `98`
    /// @dev Output: `100`
    /// @param minimumAssetsAfterTransferFee It may not always be mathematically possible to calculate the assets before a transfer fee (because of fee tiers, etc). In those cases, the output should be the closest higher amount.
    function _assetsBeforeTransferFee(uint256 minimumAssetsAfterTransferFee) internal view virtual returns (uint256);
}
