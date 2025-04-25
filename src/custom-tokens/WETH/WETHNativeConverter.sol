// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.29;

// @todo REVIEW.

// @todo Remove `SafeERC20`, `IERC20`. (Required for the reinitializer).
import {NativeConverter, SafeERC20, IERC20} from "../../NativeConverter.sol";
import {WETH} from "./WETH.sol";
import {IVersioned} from "../../etc/IVersioned.sol";
import {MigrationManager} from "../../MigrationManager.sol";
import {ILxLyBridge} from "../../etc/ILxLyBridge.sol";

/// @title WETH Native Converter
contract WETHNativeConverter is NativeConverter {
    // @todo Remove. (Required for the reinitializer).
    using SafeERC20 for IERC20;

    /// @dev Storage of WETHNativeConverter contract.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:0xpolygon.storage.WETH
    struct WETHNativeConverterStorage {
        WETH _weth;
        bool _gasTokenIsEth;
    }

    // @todo Change the namespace. If upgrading the testnet contracts, add a reinitializer and clean the old slots using assembly.
    /// @dev The storage slot at which WETHNativeConverter storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("0xpolygon.storage.WETHNativeConverter")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _WETH_NATIVE_CONVERTER_STORAGE =
        hex"bf2d0f52fc90c2e373874d27ef2034a489f8af72128c9dcedd13ea84d2ba4700";

    error FunctionNotSupportedOnThisNetwork();

    // @todo Remove. If upgrading the testnet contracts, add a reinitializer and clean the slot using assembly.
    WETH __OUTDATED__weth;

    modifier onlyIfGasTokenIsEth() {
        WETHNativeConverterStorage storage $ = _getWETHNativeConverterStorage();
        require($._gasTokenIsEth, FunctionNotSupportedOnThisNetwork());
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        uint8 originalUnderlyingTokenDecimals_,
        address customToken_,
        address underlyingToken_,
        address lxlyBridge_,
        uint32 layerXNetworkId_,
        uint256 nonMigratableBackingPercentage_,
        address migrationManager_
    ) external initializer {
        WETHNativeConverterStorage storage $ = _getWETHNativeConverterStorage();

        // Initialize the base implementation.
        __NativeConverter_init(
            owner_,
            originalUnderlyingTokenDecimals_,
            customToken_,
            underlyingToken_,
            lxlyBridge_,
            layerXNetworkId_,
            nonMigratableBackingPercentage_,
            migrationManager_
        );

        $._weth = WETH(payable(customToken_));
        $._gasTokenIsEth =
            ILxLyBridge(lxlyBridge_).gasTokenAddress() == address(0) && ILxLyBridge(lxlyBridge_).gasTokenNetwork() == 0;
    }

    function _getWETHNativeConverterStorage() private pure returns (WETHNativeConverterStorage storage $) {
        assembly {
            $.slot := _WETH_NATIVE_CONVERTER_STORAGE
        }
    }

    /*
    // @todo Remove. (Required for the testnet).
    function reinitialize(
        address owner_,
        uint8 originalUnderlyingTokenDecimals_,
        address customToken_,
        address underlyingToken_,
        address lxlyBridge_,
        uint32 layerXNetworkId_,
        uint256 nonMigratableBackingPercentage_,
        address migrationManager_
    ) external reinitializer(3) {
        underlyingToken().forceApprove(address(lxlyBridge()), 0);

        // Reinitialize the base implementation.
        __NativeConverter_init(
            owner_,
            originalUnderlyingTokenDecimals_,
            customToken_,
            underlyingToken_,
            lxlyBridge_,
            layerXNetworkId_,
            nonMigratableBackingPercentage_,
            migrationManager_
        );

        weth = WETH(payable(customToken_));
    }
    */

    /// @dev This special function allows the NativeConverter owner to migrate the gas backing of the WETH Custom Token
    /// @dev It simply takes the amount of gas token from the WETH contract
    /// @dev and performs the migration using a special CrossNetworkInstruction called WRAP_GAS_TOKEN_AND_COMPLETE_MIGRATION
    /// @dev It instructs vbETH on Layer X to first wrap the gas token and then deposit it to complete the migration.
    /// @notice It is known that this can lead to WETH not being able to perform withdrawals, because of a lack of gas backing.
    /// @notice However, this is acceptable, because WETH is a vault backed token so its backing should actually be staked.
    /// @notice Users can still bridge WETH back to Layer X to receive wETH or ETH.
    function migrateGasBackingToLayerX(uint256 amount)
        external
        whenNotPaused
        onlyIfGasTokenIsEth
        onlyRole(MIGRATOR_ROLE)
        nonReentrant
    {
        WETHNativeConverterStorage storage $ = _getWETHNativeConverterStorage();
        WETH weth = $._weth;

        uint256 migratableBacking_ = migratableBacking();

        // Check the input.
        require(amount > 0, InvalidAssets());
        // @follow-up Consider implementing a better limit.
        require(amount <= migratableBacking_, AssetsTooLarge(migratableBacking_, amount));
        require(amount <= address(weth).balance, AssetsTooLarge(address(weth).balance, amount));

        // Precalculate the amount of Custom Token for which backing is being migrated.
        uint256 amountOfCustomToken = _convertToShares(amount);

        // Taking lxlyBridge's gas balance here
        weth.bridgeBackingToLayerX(amount);
        lxlyBridge().bridgeAsset{value: amount}(
            layerXLxlyId(), address(migrationManager()), amount, address(0), true, ""
        );

        // Bridge a message to Migration Manager on Layer X to complete the migration.
        lxlyBridge().bridgeMessage(
            layerXLxlyId(),
            address(migrationManager()),
            true,
            abi.encode(
                MigrationManager.CrossNetworkInstruction.WRAP_GAS_TOKEN_AND_COMPLETE_MIGRATION,
                abi.encode(amountOfCustomToken, amount)
            )
        );

        // Emit the event.
        emit MigrationStarted(msg.sender, amountOfCustomToken, amount);
    }

    receive() external payable whenNotPaused onlyIfGasTokenIsEth nonReentrant {}

    /// @inheritdoc IVersioned
    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }
}
