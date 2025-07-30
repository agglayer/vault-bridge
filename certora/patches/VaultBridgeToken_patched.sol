// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (VaultBridgeToken.sol)

pragma solidity 0.8.29;

// Main functionality.
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC20PermitUpgradeable} from
    "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {IVaultBridgeTokenInitializer} from "./etc/IVaultBridgeTokenInitializer.sol";

// Other functionality.
import {Initializable} from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardTransientUpgradeable} from
    "@openzeppelin-contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
import {ERC20PermitUser} from "./etc/ERC20PermitUser.sol";
import {Versioned} from "./etc/Versioned.sol";

// Libraries.
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// External contracts.
import {ILxLyBridge} from "./etc/ILxLyBridge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Other.
import {ERC20Upgradeable} from "@openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title Vault Bridge Token
/// @author See https://github.com/agglayer/vault-bridge
/// @notice A vbToken is an ERC-20 token, ERC-4626 vault, and LxLy Bridge extension, enabling deposits and bridging of select assets, such as WBTC, WETH, USDT, USDC, and USDS, while putting the assets to work to produce yield.
/// @dev A base contract used to create vbTokens.
/// @dev @note IMPORTANT: In order to not drive the complexity of the Vault Bridge protocol up, vbToken MUST NOT have transfer, deposit, or withdrawal fees. The underlying token on Layer X MUST NOT have a transfer fee; this contract will revert if it detects a transfer fee. The underlying token and Custom Token on Layer Ys MAY have transfer fees. The yield vault SHOULD NOT have deposit and/or withdrawal fees; however, it is expected that produced yield will offset any costs incurred when depositing to and withdrawing from the yield vault for the purpose of producing yield or rebalancing the internal reserve. The price of the yield vault's shares MUST NOT decrease (e.g., no bad debt realization); still, this contract implements solvency checks for protection with a configurable slippage parameter. Additionally, the underlying token MUST NOT be a rebasing token, and MUST NOT have transfer hooks (i.e., does not enable reentrancy/crossentrancy).
abstract contract VaultBridgeToken is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardTransientUpgradeable,
    IERC4626,
    ERC20PermitUpgradeable,
    ERC20PermitUser,
    Versioned
{
    // Libraries.
    using SafeERC20 for IERC20;

    /// @dev Storage of Vault Bridge Token contract.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:agglayer.vault-bridge.VaultBridgeToken.storage
    struct VaultBridgeTokenStorage {
        IERC20 underlyingToken;
        uint8 decimals;
        uint256 minimumReservePercentage;
        uint256 reservedAssets;
        IERC4626 yieldVault;
        address yieldRecipient;
        uint256 _netCollectedYield;
        uint32 lxlyId;
        ILxLyBridge lxlyBridge;
        uint256 migrationFeesFund;
        uint256 minimumYieldVaultDeposit;
        address migrationManager;
        uint256 yieldVaultMaximumSlippagePercentage;
        address _vaultBridgeTokenPart2;
    }

    /// @dev Parameters for initializing Vault Bridge Token contract.
    /// @dev @note (ATTENTION) `decimals` will match the underlying token. Defaults to 18 decimals if the underlying token reverts on `decimals`.
    /// @param owner (ATTENTION) This address will be granted the `DEFAULT_ADMIN_ROLE`, as well as all basic roles. Roles can be modified at any time.
    /// @param minimumReservePercentage vbTokens can maintain an internal reserve of the underlying token for serving withdrawals from first (as opposed to staking all assets). `1e18` is 100%. @note (ATTENTION) Automatic reserve rebalancing will be disabled for values greater than `1e18` (100%).
    /// @param yieldVault An external, ERC-4246 compliant vault into which the underlying token is deposited to produce yield.
    /// @param yieldRecipient The address that receives yield produced by the yield vault. The yield collector collects yield, while the yield recipient receives it.
    /// @param minimumYieldVaultDeposit The minimum amount of the underlying token that triggers a yield vault deposit. Amounts below this value will be reserved regardless of the reserve percentage, in order to save gas for users. The limit does not apply when rebalancing the reserve. Set to `0` to disable.
    /// @param yieldVaultMaximumSlippagePercentage The maximum slippage percentage when depositing into or withdrawing from the yield vault. @note IMPORTANT: Any losses incurred due to slippage (and not fully covered by produced yield) will need to be covered by whomever is responsible for this contract. `1e18` is 100%. The recommended value is `0.01e18` (1%).
    struct InitializationParameters {
        address owner;
        string name;
        string symbol;
        address underlyingToken;
        uint256 minimumReservePercentage;
        address yieldVault;
        address yieldRecipient;
        address lxlyBridge;
        uint256 minimumYieldVaultDeposit;
        address migrationManager;
        uint256 yieldVaultMaximumSlippagePercentage;
        address vaultBridgeTokenPart2;
    }

    // Certora: munge to simplify delegation to Part2
    address PART2;

    // Basic roles.
    bytes32 public constant REBALANCER_ROLE = keccak256("REBALANCER_ROLE");
    bytes32 public constant YIELD_COLLECTOR_ROLE = keccak256("YIELD_COLLECTOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @dev The storage slot at which Vault Bridge Token storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("agglayer.vault-bridge.VaultBridgeToken.storage")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _VAULT_BRIDGE_TOKEN_STORAGE =
        hex"f082fbc4cfb4d172ba00d34227e208a31ceb0982bc189440d519185302e44700";

    // Errors.
    error Unauthorized();
    error InvalidInitializer();
    error InvalidOwner();
    error InvalidName();
    error InvalidSymbol();
    error InvalidUnderlyingToken();
    error InvalidMinimumReservePercentage();
    error InvalidYieldVault();
    error InvalidYieldRecipient();
    error InvalidLxLyBridge();
    error InvalidMigrationManager();
    error InvalidYieldVaultMaximumSlippagePercentage();
    error InvalidVaultBridgeTokenPart2();
    error InvalidAssets();
    error InvalidDestinationNetworkId();
    error InvalidReceiver();
    error InvalidPermitData();
    error InvalidShares();
    error IncorrectAmountOfSharesMinted(uint256 mintedShares, uint256 requiredShares);
    error AssetsTooLarge(uint256 availableAssets, uint256 requestedAssets);
    error IncorrectAmountOfSharesRedeemed(uint256 redeemedShares, uint256 requiredShares);
    error CannotRebalanceReserve();
    error NoNeedToRebalanceReserve();
    error NoYield();
    error InvalidOriginNetwork();
    error CannotCompleteMigration(uint256 requiredAssets, uint256 receivedAssets, uint256 assetsInMigrationFund);
    error YieldVaultRedemptionFailed(uint256 sharesToRedeem, uint256 redemptionLimit);
    error MinimumYieldVaultDepositNotMet(uint256 assetsToDeposit, uint256 minimumYieldVaultDeposit);
    error YieldVaultDepositFailed(uint256 assetsToDeposit, uint256 depositLimit);
    error InsufficientYieldVaultSharesMinted(uint256 depositedAssets, uint256 mintedShares);
    error UnknownError(bytes data);
    error YieldVaultWithdrawalFailed(uint256 assetsToWithdraw, uint256 withdrawalLimit);
    error ExcessiveYieldVaultSharesBurned(uint256 burnedShares, uint256 withdrawnAssets);
    error InsufficientUnderlyingTokenReceived(uint256 receivedAssets, uint256 requestedAssets);
    error UnknownFunction(bytes4 functionSelector);

    // Events.
    event ReserveRebalanced(uint256 oldReservedAssets, uint256 newReservedAssets, uint256 reservePercentage);
    event YieldCollected(address indexed yieldRecipient, uint256 vbTokenAmount);
    event Burned(uint256 vbTokenAmount);
    event DonatedAsYield(address indexed who, uint256 assets);
    event DonatedForCompletingMigration(address indexed who, uint256 assets);
    event MigrationCompleted(
        uint32 indexed originNetwork,
        uint256 indexed shares,
        uint256 indexed assets,
        uint256 migrationFeesFundUtilization
    );
    event YieldRecipientSet(address indexed yieldRecipient);
    event MinimumReservePercentageSet(uint256 minimumReservePercentage);
    event YieldVaultDrained(uint256 redeemedShares, uint256 receivedAssets);
    event YieldVaultSet(address yieldVault);
    event YieldVaultMaximumSlippagePercentageSet(uint256 slippagePercentage);

    // -----================= ::: MODIFIERS ::: =================-----

    /// @dev Checks if the sender is the yield recipient.
    modifier onlyYieldRecipient() {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();
        require(msg.sender == $.yieldRecipient, Unauthorized());
        _;
    }

    /// @dev Checks if the sender is LxLy Bridge.
    modifier onlyLxLyBridge() {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();
        require(msg.sender == address($.lxlyBridge), Unauthorized());
        _;
    }

    /// @dev Checks if the sender is Migration Manager.
    modifier onlyMigrationManager() {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();
        require(msg.sender == $.migrationManager, Unauthorized());
        _;
    }

    /// @dev Checks if the sender is the vbToken itself.
    modifier onlySelf() {
        require(msg.sender == address(this), Unauthorized());
        _;
    }

    /// @dev Delegates the call to `VaultBridgeTokenPart2`.
    modifier delegatedToPart2() {
        _;
        _delegateToPart2();
    }

    // -----================= ::: SETUP ::: =================-----

    /// @param initializer_ The address of `VaultBridgeTokenInitializer`.
    /// @param initParams Please refer to `InitializationParameters` for more information.
    function __VaultBridgeToken_init(address initializer_, InitializationParameters calldata initParams)
        internal
        onlyInitializing
    {
        // Check the input.
        require(initializer_ != address(0), InvalidInitializer());

        // Verify the version of the initializer.
        // The version string must be the same as that of this contract.
        require(
            keccak256(bytes(VaultBridgeToken(initializer_).version())) == keccak256(bytes(version())),
            InvalidInitializer()
        );

        // Initialize the contract using the external initializer.
        (bool ok, bytes memory data) =
            initializer_.delegatecall(abi.encodeCall(IVaultBridgeTokenInitializer.initialize, (initParams)));

        // Check the result.
        if (!ok) {
            // If the call failed, bubble up the revert data.
            assembly ("memory-safe") {
                revert(add(32, data), mload(data))
            }
        }
    }

    // -----================= ::: STORAGE ::: =================-----

    /// @notice The underlying token that backs vbToken.
    function underlyingToken() public view returns (IERC20) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();
        return $.underlyingToken;
    }

    /// @notice The number of decimals of vbToken.
    /// @notice The number of decimals is the same as that of the underlying token, or `18` if the underlying token reverted on `decimals`.
    function decimals() public view override(ERC20Upgradeable, IERC20Metadata) returns (uint8) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();
        return $.decimals;
    }

    /// @notice vbTokens can maintain an internal reserve of the underlying token for serving withdrawals from first (as opposed to staking all assets).
    /// @notice The owner can rebalance the reserve by calling `rebalanceReserve` when it is below or above the `minimumReservePercentage`. The reserve may also be rebalanced automatically on deposits and withdrawals.
    /// @return 1e18 is 100%.
    function minimumReservePercentage() public view returns (uint256) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();
        return $.minimumReservePercentage;
    }

    /// @notice vbTokens can maintain an internal reserve of the underlying token for serving withdrawals from first (as opposed to staking all assets).
    /// @notice How much of the underlying token is in the internal reserve.
    function reservedAssets() public view returns (uint256) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();
        return $.reservedAssets;
    }

    /// @notice An external, ERC-4246 compliant vault into which the underlying token is deposited to produce yield.
    function yieldVault() public view returns (IERC4626) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();
        return $.yieldVault;
    }

    /// @notice The address that receives yield produced by the yield vault.
    /// @notice The yield collector collects yield, while the yield recipient receives it.
    function yieldRecipient() public view returns (address) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();
        return $.yieldRecipient;
    }

    /// @notice The LxLy ID of this network.
    function lxlyId() public view returns (uint32) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();
        return $.lxlyId;
    }

    /// @notice LxLy Bridge, which connects AggLayer networks.
    function lxlyBridge() public view returns (ILxLyBridge) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();
        return $.lxlyBridge;
    }

    /// @notice A dedicated fund for covering any fees on Layer Y during a migration of backing to Layer X. Please refer to `completeMigration` for more information.
    function migrationFeesFund() public view returns (uint256) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();
        return $.migrationFeesFund;
    }

    /// @notice The minimum amount of the underlying token that triggers a yield vault deposit.
    /// @dev Amounts below this value will be reserved regardless of the reserve percentage, in order to save gas for users.
    /// @dev The limit does not apply when rebalancing the reserve.
    function minimumYieldVaultDeposit() public view returns (uint256) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();
        return $.minimumYieldVaultDeposit;
    }

    /// @notice The address of Migration Manager. Please refer to `MigrationManager.sol` for more information.
    function migrationManager() public view returns (address) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();
        return $.migrationManager;
    }

    /// @notice The maximum slippage percentage when depositing into or withdrawing from the yield vault.
    /// @return 1e18 is 100%.
    function yieldVaultMaximumSlippagePercentage() public view returns (uint256) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();
        return $.yieldVaultMaximumSlippagePercentage;
    }

    /// @dev Returns a pointer to the ERC-7201 storage namespace.
    function _getVaultBridgeTokenStorage() internal pure returns (VaultBridgeTokenStorage storage $) {
        assembly {
            $.slot := _VAULT_BRIDGE_TOKEN_STORAGE
        }
    }

    // -----================= ::: ERC-4626 ::: =================-----

    /// @notice The underlying token that backs vbToken.
    function asset() public view returns (address assetTokenAddress) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();
        return address($.underlyingToken);
    }

    /// @notice The total backing of vbToken in the underlying token in real-time.
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

        return convertToShares(assets);
    }

    /// @notice Deposit a specific amount of the underlying token and mint vbToken.
    function deposit(uint256 assets, address receiver) external whenNotPaused nonReentrant returns (uint256 shares) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();
        (shares,) = _deposit(assets, $.lxlyId, receiver, false, 0);
    }

    /// @notice Deposit a specific amount of the underlying token, and bridge minted vbToken to another network.
    /// @dev The `receiver` in the ERC-4626 `Deposit` event will be this contract.
    function depositAndBridge(
        uint256 assets,
        address receiver,
        uint32 destinationNetworkId,
        bool forceUpdateGlobalExitRoot
    ) external whenNotPaused nonReentrant returns (uint256 shares) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();

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
        return _depositUsingCustomReceivingFunction(
            _receiveUnderlyingToken, assets, destinationNetworkId, receiver, forceUpdateGlobalExitRoot, maxShares
        );
    }

    /// @notice Locks the underlying token, mints vbToken, and optionally bridges it to another network.
    /// @param receiveUnderlyingToken A custom function to use for receiving the underlying token from the sender. @note CAUTION! This function MUST NOT introduce reentrancy/crossentrancy vulnerabilities. @note IMPORTANT: The function MUST detect and revert if there was a transfer fee.
    /// @param maxShares Caps the amount of vbToken that is minted. Unused underlying token will be refunded to the sender. Set to `0` to disable.
    /// @dev If bridging to another network, the `receiver` in the ERC-4626 `Deposit` event will be this contract.
    function _depositUsingCustomReceivingFunction(
        function(address, uint256) internal receiveUnderlyingToken,
        uint256 assets,
        uint32 destinationNetworkId,
        address receiver,
        bool forceUpdateGlobalExitRoot,
        uint256 maxShares
    ) internal returns (uint256 shares, uint256 spentAssets) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();

        // Check the inputs.
        require(assets > 0, InvalidAssets());
        require(receiver != address(0), InvalidReceiver());
        require(receiver != address(this), InvalidReceiver());

        // Transfer the underlying token from the sender to self.
        receiveUnderlyingToken(msg.sender, assets);

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

        // Calculate the amount to reserve.
        uint256 assetsToReserve = _calculateAmountToReserve(assets, shares);

        // Calculate the amount to try to deposit into the yield vault.
        uint256 assetsToDeposit = assets - assetsToReserve;

        // Try to deposit into the yield vault.
        if (assetsToDeposit > 0) {
            // Deposit, and update the amount to reserve if necessary.
            assetsToReserve += _depositIntoYieldVault(assetsToDeposit, false);
        }

        // Update the reserve.
        $.reservedAssets += assetsToReserve;

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

        // Cache the reserve percentage.
        uint256 reservePercentage_ = reservePercentage();

        // Check if the reserve needs to be rebalanced.
        if (
            $.minimumReservePercentage < 1e18 && reservePercentage_ > 3 * $.minimumReservePercentage
                && reservePercentage_ > 0.1e18
        ) {
            // Rebalance the reserve.
            _rebalanceReserve(false, true);
        }
    }

    /// @notice Deposit a specific amount of the underlying token and mint vbToken.
    /// @dev Uses EIP-2612 permit to transfer the underlying token from the sender to self.
    function depositWithPermit(uint256 assets, address receiver, bytes calldata permitData)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 shares)
    {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();
        (shares,) = _depositWithPermit(assets, permitData, $.lxlyId, receiver, false, 0);
    }

    /// @notice Deposit a specific amount of the underlying token, and bridge minted vbToken to another network.
    /// @dev Uses EIP-2612 permit to transfer the underlying token from the sender to self.
    /// @dev The `receiver` in the ERC-4626 `Deposit` event will be this contract.
    function depositWithPermitAndBridge(
        uint256 assets,
        address receiver,
        uint32 destinationNetworkId,
        bool forceUpdateGlobalExitRoot,
        bytes calldata permitData
    ) external whenNotPaused nonReentrant returns (uint256 shares) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();

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
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();

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

        return convertToAssets(shares);
    }

    /// @notice Mint a specific amount of vbToken by locking the required amount of the underlying token.
    function mint(uint256 shares, address receiver) external whenNotPaused nonReentrant returns (uint256 assets) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();

        // Check the input.
        require(shares > 0, InvalidShares());

        // Mint vbToken to the receiver.
        uint256 mintedShares;
        (mintedShares, assets) = _deposit(convertToAssets(shares), $.lxlyId, receiver, false, shares);

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
    /// @dev @note IMPORTANT: `reservedAssets` must be up-to-date before using this function!
    /// @param assets The maximum amount of the underlying token to simulate a withdrawal for.
    /// @param force Whether to revert if the all of the `assets` would not be withdrawn.
    function _simulateWithdraw(uint256 assets, bool force) internal view returns (uint256 withdrawnAssets) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();

        // Check the input.
        require(assets > 0, InvalidAssets());

        // The amount that cannot be withdrawn at the moment.
        uint256 remainingAssets = assets;

        // Simulate a withdrawal from the reserve.
        if ($.reservedAssets >= remainingAssets) return assets;
        remainingAssets -= $.reservedAssets;

        // Calculate the amount to preview a withdrawal from the yield vault for.
        uint256 maxWithdraw_ = $.yieldVault.maxWithdraw(address(this));
        maxWithdraw_ = remainingAssets > maxWithdraw_ ? maxWithdraw_ : remainingAssets;

        // Simulate a withdrawal from the yield vault.
        uint256 burnedYieldVaultShares;
        try $.yieldVault.previewWithdraw(maxWithdraw_) returns (uint256 shares) {
            // Capture the amount of the yield vault shares that would be burned.
            burnedYieldVaultShares = shares;
        } catch (bytes memory data) {
            // If `previewWithdraw` reverted, and all of the `assets` must be withdrawn, bubble up the revert data.
            if (force) {
                assembly ("memory-safe") {
                    revert(add(32, data), mload(data))
                }
            }
            // Otherwise, return the reserved assets.
            else {
                return $.reservedAssets;
            }
        }

        // Perform the same solvency check as `_withdrawFromYieldVault` would.
        bool solvencyCheckPassed = Math.mulDiv(
            convertToAssets(totalSupply() + yield()) - reservedAssets(), burnedYieldVaultShares, maxWithdraw_
        ) <= Math.mulDiv($.yieldVault.balanceOf(address(this)), 1e18 + $.yieldVaultMaximumSlippagePercentage, 1e18);

        // Revert if the solvency check failed and all of the `assets` must be withdrawn.
        if (!solvencyCheckPassed) {
            if (force) revert ExcessiveYieldVaultSharesBurned(burnedYieldVaultShares, maxWithdraw_);
            return $.reservedAssets;
        }

        // Return if all of the `assets` would be withdrawn.
        if (remainingAssets == maxWithdraw_) return assets;
        remainingAssets -= maxWithdraw_;

        // Set the return value (the amount of the underlying token that can be withdrawn right now).
        withdrawnAssets = assets - remainingAssets;

        // Revert if all of the `assets` must have been withdrawn and there is a remaining amount.
        if (force) require(remainingAssets == 0, AssetsTooLarge(withdrawnAssets, assets));
    }

    /// @notice Withdraw a specific amount of the underlying token by burning the required amount of vbToken.
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
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();

        // Check the inputs.
        require(assets > 0, InvalidAssets());
        require(receiver != address(0), InvalidReceiver());
        require(owner != address(0), InvalidOwner());

        // Cache the total supply, uncollected yield, and reserved assets.
        uint256 originalTotalSupply = totalSupply();
        uint256 originalUncollectedYield = yield();
        uint256 originalReservedAssets = $.reservedAssets;

        // Set the return value.
        shares = convertToShares(assets);

        // Check the input.
        if (msg.sender != owner) _spendAllowance(owner, msg.sender, shares);

        // The amount that cannot be withdrawn at the moment.
        uint256 remainingAssets = assets;

        // Calculate the amount to withdraw from the reserve.
        uint256 amountToWithdraw = originalReservedAssets > remainingAssets ? remainingAssets : originalReservedAssets;

        // Withdraw the underlying token from the reserve.
        if (amountToWithdraw > 0) {
            // Update the reserve.
            $.reservedAssets -= amountToWithdraw;

            // Update the remaining assets.
            remainingAssets -= amountToWithdraw;
        }

        uint256 receivedAssets;

        if (remainingAssets != 0) {
            // Calculate the amount to withdraw from the yield vault.
            uint256 maxWithdraw_ = $.yieldVault.maxWithdraw(address(this));

            // Withdraw the underlying token from the yield vault.
            if (maxWithdraw_ >= remainingAssets) {
                // Withdraw to this contract.
                (, receivedAssets) = _withdrawFromYieldVault(
                    remainingAssets,
                    true,
                    address(this),
                    originalTotalSupply,
                    originalUncollectedYield,
                    originalReservedAssets
                );
            } else {
                // Update the remaining assets.
                remainingAssets -= maxWithdraw_;

                // Revert because all of the `assets` could not be withdrawn.
                revert AssetsTooLarge(assets - remainingAssets, assets);
            }
        }

        // Burn vbToken.
        _burn(owner, shares);

        // Send the underlying token to the receiver.
        _sendUnderlyingToken(receiver, amountToWithdraw + receivedAssets);

        // Emit the ERC-4626 event.
        emit IERC4626.Withdraw(msg.sender, receiver, owner, assets, shares);

        // Check if the reserve needs to be rebalanced.
        if ($.minimumReservePercentage < 1e18 && reservePercentage() <= 0.01e18 && $.minimumReservePercentage >= 0.1e18)
        {
            // Rebalance the reserve.
            _rebalanceReserve(false, false);
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
    function claimAndRedeem(
        bytes32[32] calldata smtProofLocalExitRoot,
        bytes32[32] calldata smtProofRollupExitRoot,
        uint256 globalIndex,
        bytes32 mainnetExitRoot,
        bytes32 rollupExitRoot,
        address destinationAddress,
        uint256 amount,
        address receiver,
        bytes calldata metadata
    ) external whenNotPaused nonReentrant returns (uint256 assets) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();

        // Claim vbToken from LxLy Bridge.
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
            metadata
        );

        // Set the return value.
        assets = convertToAssets(amount);

        // Burn vbToken and unlock the underlying token.
        uint256 redeemedShares = _withdraw(assets, receiver, destinationAddress);

        // Check the output.
        require(redeemedShares == amount, IncorrectAmountOfSharesRedeemed(redeemedShares, amount));
    }

    // -----================= ::: ERC-20 ::: =================-----

    /// @dev Pausable ERC-20 `transfer` function.
    function transfer(address to, uint256 value)
        public
        override(ERC20Upgradeable, IERC20)
        whenNotPaused
        returns (bool)
    {
        return ERC20Upgradeable.transfer(to, value);
    }

    /// @dev Pausable ERC-20 `transferFrom` function.
    function transferFrom(address from, address to, uint256 value)
        public
        override(ERC20Upgradeable, IERC20)
        whenNotPaused
        returns (bool)
    {
        return ERC20Upgradeable.transferFrom(from, to, value);
    }

    /// @dev Pausable ERC-20 `approve` function.
    function approve(address spender, uint256 value)
        public
        override(ERC20Upgradeable, IERC20)
        whenNotPaused
        returns (bool)
    {
        return ERC20Upgradeable.approve(spender, value);
    }

    /// @dev Pausable ERC-20 Permit `permit` function.
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        public
        override
        whenNotPaused
    {
        super.permit(owner, spender, value, deadline, v, r, s);
    }

    // -----================= ::: VAULT BRIDGE TOKEN ::: =================-----

    /// @notice The amount of the underlying token in the yield vault, as reported by the yield vault in real-time.
    function stakedAssets() public view returns (uint256) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();
        return $.yieldVault.convertToAssets($.yieldVault.balanceOf(address(this)));
    }

    /// @notice The reserve percentage in real-time.
    /// @notice The reserve is based on the total supply of vbToken, and does not account for uncompleted migrations of backing from Layer Ys to Layer X. Please refer to `completeMigration` for more information.
    function reservePercentage() public view returns (uint256) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();

        // Return zero if the total supply is zero.
        if (totalSupply() == 0) return 0;

        // Calculate the reserve percentage.
        return Math.mulDiv($.reservedAssets, 1e18, convertToAssets(totalSupply()));
    }

    /// @notice The amount of yield available for collection.
    function yield() public view returns (uint256) {
        // The formula for calculating yield is:
        // yield = assets reported by yield vault + reserved assets - vbToken total supply in assets
        (bool positive, uint256 difference) = backingDifference();

        // Returns zero if the backing is negative.
        return positive ? convertToShares(difference) : 0;
    }

    /// @notice The difference between the total assets and the minimum assets required to back the total supply of vbToken in real-time.
    function backingDifference() public view returns (bool positive, uint256 difference) {
        // Get the state.
        uint256 totalAssets_ = totalAssets();
        uint256 minimumAssets = convertToAssets(totalSupply());

        // Calculate the difference.
        return
            totalAssets_ >= minimumAssets ? (true, totalAssets_ - minimumAssets) : (false, minimumAssets - totalAssets_);
    }

    /// @notice Rebalances the internal reserve by withdrawing the underlying token from, or depositing the underlying token into, the yield vault.
    /// @notice This function can be called by a rebalancer only.
    /// @dev Delegates the call to `VaultBridgeTokenPart2`.
    function rebalanceReserve() external virtual {
        PART2.delegatecall(abi.encodeWithSignature("rebalanceReserve()"));
    }

    /// @notice Rebalances the internal reserve by withdrawing the underlying token from, or depositing the underlying token into, the yield vault.
    /// @param force Whether to revert if the reserve cannot be rebalanced.
    /// @param allowRebalanceDown Whether to allow the reserve to be rebalanced down (by depositing into the yield vault).
    function _rebalanceReserve(bool force, bool allowRebalanceDown) internal {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();

        // Cache the reserved assets, total supply, and uncollected yield.
        uint256 originalReservedAssets = $.reservedAssets;
        uint256 originalTotalSupply = totalSupply();
        uint256 originalUncollectedYield = yield();

        // Calculate the minimum reserve amount.
        uint256 minimumReserve =
            convertToAssets(Math.mulDiv(originalTotalSupply, $.minimumReservePercentage, 1e18, Math.Rounding.Ceil));

        // Check if the reserve is below, above, or at the minimum threshold.
        /* Below. */
        if (originalReservedAssets < minimumReserve) {
            // Calculate the amount to try to withdraw from the yield vault.
            uint256 shortfall = minimumReserve - originalReservedAssets;

            // Try to withdraw from the yield vault.
            (uint256 nonWithdrawnAssets, uint256 receivedAssets) = _withdrawFromYieldVault(
                shortfall, false, address(this), originalTotalSupply, originalUncollectedYield, originalReservedAssets
            );

            // Revert if the the reserve could not be rebalanced and `force` is set to `true`.
            if (force && nonWithdrawnAssets == shortfall) revert CannotRebalanceReserve();

            // Update the reserve.
            $.reservedAssets += receivedAssets;

            // Emit the event.
            emit ReserveRebalanced(originalReservedAssets, $.reservedAssets, reservePercentage());
        }
        /* Above */
        else if (originalReservedAssets > minimumReserve && allowRebalanceDown) {
            // Calculate the amount to try to deposit into the yield vault.
            uint256 excess = originalReservedAssets - minimumReserve;

            // Try to deposit into the yield vault.
            uint256 nonDepositedAssets = _depositIntoYieldVault(excess, false);

            // Revert if the the reserve could not be rebalanced and `force` is set to `true`.
            if (force && nonDepositedAssets == excess) revert CannotRebalanceReserve();

            // Update the reserve.
            $.reservedAssets -= (excess - nonDepositedAssets);

            // Emit the event.
            emit ReserveRebalanced(originalReservedAssets, $.reservedAssets, reservePercentage());
        }
        /* At. */
        else if (force) {
            revert NoNeedToRebalanceReserve();
        }
    }

    /// @notice Transfers yield produced by the yield vault to the yield recipient in the form of vbToken.
    /// @notice Does not rebalance the reserve after collecting yield to allow usage while the contract is paused.
    /// @notice This function can be called by a yield collector only.
    /// @dev Increases the net collected yield.
    /// @dev Delegates the call to `VaultBridgeTokenPart2`.
    function collectYield() external virtual {
        PART2.delegatecall(abi.encodeWithSignature("collectYield()"));
    }

    /// @notice Burns a specific amount of vbToken.
    /// @notice This function can be used if the yield recipient has collected an unrealistic amount of yield over time.
    /// @notice This function can be called by the yield recipient only.
    /// @dev Decreases the net collected yield.
    /// @dev Does not rebalance the reserve after burning to allow usage while the contract is paused.
    /// @dev Delegates the call to `VaultBridgeTokenPart2`.
    function burn(uint256 shares) external virtual {
        PART2.delegatecall(abi.encodeWithSignature("burn(uint256)", shares));
    }

    /// @notice Adds a specific amount of the underlying token to the reserve by transferring it from the sender.
    /// @notice This function can be used to restore backing difference by donating the underlying token.
    /// @notice This function can be called by anyone.
    /// @dev Delegates the call to `VaultBridgeTokenPart2`.
    function donateAsYield(uint256 assets) external virtual {
        PART2.delegatecall(abi.encodeWithSignature("donateAsYield(uint256)", assets));
    }

    /// @notice Adds a specific amount of the underlying token to a dedicated fund for covering any fees on Layer Y during a migration of backing to Layer X by transferring it from the sender. Please refer to `completeMigration` for more information.
    /// @dev Delegates the call to `VaultBridgeTokenPart2`.
    function donateForCompletingMigration(uint256 assets) external virtual {
        PART2.delegatecall(abi.encodeWithSignature("donateForCompletingMigration(uint256)", assets));
    }

    /// @notice Completes a migration of backing from a Layer Y to Layer X by minting and locking the required amount of vbToken in LxLy Bridge.
    /// @notice Anyone can trigger the execution of this function by claiming the asset and message on LxLy Bridge. Please refer to `NativeConverter.sol` for more information.
    /// @dev Backing for Custom Token minted by Native Converter on Layer Ys can be migrated to Layer X.
    /// @dev When Native Converter migrates backing, it calls both `bridgeAsset` and `bridgeMessage` on LxLy Bridge to `migrateBackingToLayerX`.
    /// @dev The asset must be claimed before the message on LxLy Bridge.
    /// @dev The message tells vbToken how much Custom Token must be backed by vbToken, which is minted and bridged to address zero on the respective Layer Y. This action provides liquidity when bridging Custom Token to from Layer Ys to Layer X and increments the pessimistic proof.
    /// @dev This function can be called by Migraton Manager only.
    /// @dev Delegates the call to `VaultBridgeTokenPart2`.
    /// @param originNetwork The LxLy ID of Layer Y the backing is being migrated from.
    /// @param shares The amount of vbToken required to mint and lock up in LxLy Bridge. Assets from a dedicated migration fees fund may be used to offset any fees incurred on Layer Y during the process. If a migration cannot be completed due to insufficient assets, anyone can donate the underlying token to the migration fees fund. Please refer to `donateForCompletingMigration` for more information.
    /// @param assets The amount of the underlying token migrated from Layer Y (after any fees on Layer Y).
    function completeMigration(uint32 originNetwork, uint256 shares, uint256 assets)
        external
        virtual
    {
        PART2.delegatecall(abi.encodeWithSignature("completeMigration(uint32,uint256,uint256)", originNetwork, shares, assets));
    }

    /// @notice Drains the yield vault by redeeming yield vault shares. Assets will be put into the internal reserve.
    /// @notice This function may utilize availabe yield to ensure successful draining if there is larger slippage. Consider collecting yield before calling this function to disable this behavior.
    /// @dev This function can be called by the owner only.
    /// @dev Delegates the call to `VaultBridgeTokenPart2`.
    /// @param shares The amount of the yield vault shares to redeem.
    /// @param exact Whether to revert if the exact amount of shares could not be redeemed.
    function drainYieldVault(uint256 shares, bool exact) external virtual {
        PART2.delegatecall(abi.encodeWithSignature("drainYieldVault(uint256,bool)", shares, exact));
    }

    /// @notice Sets the minimum reserve percentage.
    /// @notice @note (ATTENTION) Automatic reserve rebalancing will be disabled for values greater than `1e18` (100%).
    /// @notice This function can be called by the owner only.
    /// @dev Delegates the call to `VaultBridgeTokenPart2`.
    /// @param minimumReservePercentage_ `1e18` is 100%.
    function setMinimumReservePercentage(uint256 minimumReservePercentage_) external virtual {
        PART2.delegatecall(abi.encodeWithSignature("setMinimumReservePercentage(uint256)", minimumReservePercentage_));
    }

    /// @notice Sets the yield vault.
    /// @notice @note CAUTION! Use `drainYieldVault` to drain the current yield vault completely before changing it. Any yield vault shares that are not redeemed will not count toward the underlying token backing after changing the yield vault.
    /// @notice This function can be called by the owner only.
    /// @dev Delegates the call to `VaultBridgeTokenPart2`.
    function setYieldVault(address yieldVault_) external virtual {
        PART2.delegatecall(abi.encodeWithSignature("setYieldVault(address)", yieldVault_));
    }

    /// @notice Sets the yield recipient.
    /// @notice Yield will be collected before changing the recipient.
    /// @notice This function can be called by the owner only.
    /// @dev Delegates the call to `VaultBridgeTokenPart2`.
    function setYieldRecipient(address yieldRecipient_) external virtual {
        PART2.delegatecall(abi.encodeWithSignature("setYieldRecipient(address)", yieldRecipient_));
    }

    /// @notice The minimum amount of the underlying token that triggers a yield vault deposit.
    /// @notice Amounts below this value will be reserved regardless of the reserve percentage, in order to save gas for users.
    /// @notice The limit does not apply when rebalancing the reserve.
    /// @notice This function can be called by the owner only.
    /// @dev Delegates the call to `VaultBridgeTokenPart2`.
    /// @param minimumYieldVaultDeposit_ Set to `0` to disable.
    function setMinimumYieldVaultDeposit(uint256 minimumYieldVaultDeposit_) external virtual {
        PART2.delegatecall(abi.encodeWithSignature("setMinimumYieldVaultDeposit(uint256)", minimumYieldVaultDeposit_));
    }

    /// @notice The maximum slippage percentage when depositing into or withdrawing from the yield vault.
    /// @notice @note IMPORTANT: Any losses incurred due to slippage (and not fully covered by produced yield) will need to be covered by whomever is responsible for this contract.
    /// @param maximumSlippagePercentage 1e18 is 100%. The recommended value is `0.01e18` (1%).
    function setYieldVaultMaximumSlippagePercentage(uint256 maximumSlippagePercentage)
        external
        virtual
    {
        PART2.delegatecall(abi.encodeWithSignature("setYieldVaultMaximumSlippagePercentage(uint256)", maximumSlippagePercentage));
    }

    /// @notice Calculates the amount of assets to reserve (as opposed to depositing into the yield vault) based on the current and minimum reserve percentages.
    /// @dev @note (ATTENTION) `reservedAssets` must be up-to-date before using this function.
    /// @param assets The amount of the underlying token being deposited.
    /// @param nonMintedShares The amount of vbToken that will be minted after using this function as a result of the deposit. (Set to `0` if you have already minted all the shares).
    function _calculateAmountToReserve(uint256 assets, uint256 nonMintedShares)
        internal
        view
        returns (uint256 assetsToReserve)
    {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();

        // Calculate the minimum reserve.
        uint256 minimumReserve = convertToAssets(
            Math.mulDiv(totalSupply() + nonMintedShares, $.minimumReservePercentage, 1e18, Math.Rounding.Ceil)
        );

        // Calculate the amount to reserve.
        assetsToReserve = $.reservedAssets < minimumReserve ? minimumReserve - $.reservedAssets : 0;
        return assetsToReserve <= assets ? assetsToReserve : assets;
    }

    /// @notice Deposit a specific amount of the underlying token into the yield vault.
    /// @param assets The amount of the underlying token to deposit into the yield vault.
    /// @param exact Whether to revert if the exact amount of the underlying token could not be deposited into the yield vault.
    /// @return nonDepositedAssets The amount of the underlying token that could not be deposited into the yield vault. The value will be `0` if `exact` is set to `true`.
    function _depositIntoYieldVault(uint256 assets, bool exact) internal returns (uint256 nonDepositedAssets) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();

        // Check whether to skip depositing into the yield vault.
        if (assets < $.minimumYieldVaultDeposit) {
            if (exact) revert MinimumYieldVaultDepositNotMet(assets, $.minimumYieldVaultDeposit);
            return assets;
        }

        // Cache the original assets.
        uint256 originalAssets = assets;

        // Get the yield vault's deposit limit.
        uint256 maxDeposit_ = $.yieldVault.maxDeposit(address(this));

        // Revert if the assets are greater than the deposit limit and `exact` is set to `true`.
        if (exact) require(assets <= maxDeposit_, YieldVaultDepositFailed(assets, maxDeposit_));

        // Set the return value.
        nonDepositedAssets = assets > maxDeposit_ ? assets - maxDeposit_ : 0;

        // Calculate the amount to deposit into the yield vault.
        assets = assets > maxDeposit_ ? maxDeposit_ : assets;

        // Return if no assets would be deposited.
        if (assets == 0) return nonDepositedAssets;

        // Try to deposit into the yield vault.
        try this.performReversibleYieldVaultDeposit(assets) {}
        // If the deposit failed, decode the revert data.
        catch (bytes memory data) {
            (bool depositSucceeded, bytes memory depositData, bool solvencyCheckPassed) =
                abi.decode(data, (bool, bytes, bool));

            // The yield vault deposit failed.
            if (!depositSucceeded) {
                // Revert if the assets must have been put into the yield vault.
                if (exact) {
                    // Bubble up the revert data.
                    assembly ("memory-safe") {
                        revert(add(32, depositData), mload(depositData))
                    }
                } else {
                    // Return the amount of non-deposited assets.
                    return originalAssets;
                }
            }

            // The yield vault deposit succeeded, but the solvency check did not pass.
            if (!solvencyCheckPassed) {
                // Revert if the assets must have been put into the yield vault.
                if (exact) {
                    // Revert with the standard solvency check error.
                    uint256 mintedYieldVaultShares = abi.decode(depositData, (uint256));
                    revert InsufficientYieldVaultSharesMinted(assets, mintedYieldVaultShares);
                } else {
                    // Return the amount of non-deposited assets.
                    return originalAssets;
                }
            }

            // The yield vault deposit succeeded and the solvency check passed but the call still reverted for some reason. (Sanity check - should not happen).
            revert UnknownError(data);
        }
    }

    /// @notice Enables infinte deposits regardless of the behavior of the yield vault.
    /// @dev This function reverts if the yield vault deposit fails, or the solvency check does not pass with revert data ABI-encoded in the following format: `abi.encode(depositSucceeded, depositData, solvencyCheckPassed)`, which can be decoded in another function.
    /// @notice This function can be called by the this contract only.
    function performReversibleYieldVaultDeposit(uint256 assets) external whenNotPaused onlySelf {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();

        // Prepare the variables.
        bool depositSucceeded;
        bytes memory depositData;
        bool solvencyCheckPassed;

        // Cache the staked assets before the deposit.
        uint256 oldStakedAssets = stakedAssets();

        // Try to deposit into the yield vault.
        (depositSucceeded, depositData) =
            address($.yieldVault).call(abi.encodeCall(IERC4626.deposit, (assets, address(this))));

        // The deposit succeeded.
        if (depositSucceeded) {
            // Check the output.
            // This code checks if the minted yield vault shares are worth enough in the underlying token. Allows slippage.
            solvencyCheckPassed = stakedAssets() - oldStakedAssets
                >= Math.mulDiv(assets, 1e18 - $.yieldVaultMaximumSlippagePercentage, 1e18);
        }

        // The deposit failed or the solvency check did not pass.
        if (!depositSucceeded || !solvencyCheckPassed) {
            // Encode the information in the revert data.
            bytes memory data = abi.encode(depositSucceeded, depositData, solvencyCheckPassed);
            // Revert with the encoded data.
            assembly ("memory-safe") {
                revert(add(32, data), mload(data))
            }
        }
    }

    /// @notice Withdraws a specific amount of the underlying token from the yield vault.
    /// @param assets The amount of the underlying token to withdraw from the yield vault.
    /// @param exact Whether to revert if the exact amount of the underlying token could not be withdrawn from the yield vault.
    /// @param receiver The address to withdraw the underlying token to.
    /// @param originalTotalSupply The total supply of vbToken before burning the required amount of vbToken or updating the reserve. Used for the solvency check.
    /// @param originalUncollectedYield The uncollected yield before burning the required amount of vbToken or updating the reserve. Used for the solvency check.
    /// @return nonWithdrawnAssets The amount of the underlying token that could not be withdrawn from the yield vault. The value will be `0` if `exact` is set to `true`.
    /// @return receivedAssets The amount of the underlying token actually received (e.g., after any fees). The value will be `0` if `receiver` is not `address(this)`.
    function _withdrawFromYieldVault(
        uint256 assets,
        bool exact,
        address receiver,
        uint256 originalTotalSupply,
        uint256 originalUncollectedYield,
        uint256 originalReservedAssets
    ) internal returns (uint256 nonWithdrawnAssets, uint256 receivedAssets) {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();

        // Get the yield vault's withdraw limit.
        uint256 maxWithdraw_ = $.yieldVault.maxWithdraw(address(this));

        // Revert if the assets are greater than the withdraw limit and `exact` is set to `true`.
        if (exact) require(assets <= maxWithdraw_, YieldVaultWithdrawalFailed(assets, maxWithdraw_));

        // Set a return value.
        nonWithdrawnAssets = assets > maxWithdraw_ ? assets - maxWithdraw_ : 0;

        // Calculate the amount to withdraw from the yield vault.
        assets = assets > maxWithdraw_ ? maxWithdraw_ : assets;

        // Return if no assets would be withdrawn.
        if (assets == 0) return (nonWithdrawnAssets, 0);

        // Cache the underlying token balance and yield vault shares balance.
        // The underying token balance is cached only when the receiver is vbToken.
        uint256 underlyingTokenBalanceBefore;
        if (receiver == address(this)) underlyingTokenBalanceBefore = $.underlyingToken.balanceOf(address(this));
        uint256 yieldVaultSharesBalanceBefore = $.yieldVault.balanceOf(address(this));

        // Withdraw.
        uint256 burnedYieldVaultShares = $.yieldVault.withdraw(assets, receiver, address(this));

        // Check the output.
        // This code checks if the contract would go insolvent if the amount of the underlying token required to back the portion of the total supply (including the uncollected yield) not backed by the reserved assets were withdrawn at this exchange rate. Allows slippage.
        require(
            Math.mulDiv(
                convertToAssets(originalTotalSupply + originalUncollectedYield) - originalReservedAssets,
                burnedYieldVaultShares,
                assets
            ) <= Math.mulDiv(yieldVaultSharesBalanceBefore, 1e18 + $.yieldVaultMaximumSlippagePercentage, 1e18),
            ExcessiveYieldVaultSharesBurned(burnedYieldVaultShares, assets)
        );

        // Calculate the withdrawn amount.
        // The withdrawn amount is only calculated when the receiver is vbToken.
        receivedAssets =
            receiver == address(this) ? ($.underlyingToken.balanceOf(address(this)) - underlyingTokenBalanceBefore) : 0;
    }

    // -----================= ::: UNDERLYING TOKEN ::: =================-----

    /// @notice Transfers the underlying token from an external account to self.
    /// @dev @note CAUTION! This function MUST NOT introduce reentrancy/crossentrancy vulnerabilities.
    function _receiveUnderlyingToken(address from, uint256 value) internal {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();

        // Cache the balance.
        uint256 balanceBefore = $.underlyingToken.balanceOf(address(this));

        // Transfer.
        // @note IMPORTANT: Make sure the underlying token you are integrating does not enable reentrancy on `transferFrom`.
        $.underlyingToken.safeTransferFrom(from, address(this), value);

        // Calculate the received amount.
        uint256 receivedValue = $.underlyingToken.balanceOf(address(this)) - balanceBefore;

        // Check the output.
        require(receivedValue == value, InsufficientUnderlyingTokenReceived(receivedValue, value));
    }

    /// @notice Transfers the underlying token to an external account.
    /// @dev @note CAUTION! This function MUST NOT introduce reentrancy/crossentrancy vulnerabilities.
    function _sendUnderlyingToken(address to, uint256 value) internal {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();

        // Transfer.
        // @note IMPORTANT: Make sure the underlying token you are integrating does not enable reentrancy on `transfer`.
        $.underlyingToken.safeTransfer(to, value);
    }

    // -----================= ::: ADMIN ::: =================-----

    /// @notice Prevents usage of functions with the `whenNotPaused` modifier.
    /// @notice This function can be called by a pauser only.
    /// @dev Delegates the call to `VaultBridgeTokenPart2`.
    function pause() external virtual {
        PART2.delegatecall(abi.encodeWithSignature("pause()"));
    }

    /// @notice Allows usage of functions with the `whenNotPaused` modifier.
    /// @notice This function can be called by the owner only.
    /// @dev Delegates the call to `VaultBridgeTokenPart2`.
    function unpause() external virtual {
        PART2.delegatecall(abi.encodeWithSignature("unpause()"));
    }

    // -----================= ::: PART 2 ::: =================-----

    /// @notice Delegates the call to `VaultBridgeTokenPart2`.
    function _delegateToPart2() private {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();

        address vaultBridgeTokenPart2 = $._vaultBridgeTokenPart2;

        assembly {
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(gas(), vaultBridgeTokenPart2, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch success
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
