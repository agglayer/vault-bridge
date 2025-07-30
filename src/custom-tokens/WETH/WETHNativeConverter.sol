// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (custom-tokens/WETH/WETHNativeConverter.sol)

pragma solidity 0.8.29;

import {NativeConverter, Math} from "../../NativeConverter.sol";
import {WETH} from "./WETH.sol";
import {MigrationManager} from "../../MigrationManager.sol";
import {ILxLyBridge} from "../../etc/ILxLyBridge.sol";

/// @title WETH Native Converter
/// @author See https://github.com/agglayer/vault-bridge
contract WETHNativeConverter is NativeConverter {
    /// @dev Storage of WETHNativeConverter contract.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:agglayer.vault-bridge.WETHNativeConverter.storage
    struct WETHNativeConverterStorage {
        WETH _weth;
        bool _gasTokenIsEth;
        uint256 nonMigratableGasBackingPercentage;
    }

    /// @dev The storage slot at which WETHNativeConverter storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("agglayer.vault-bridge.WETHNativeConverter.storage")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _WETH_NATIVE_CONVERTER_STORAGE =
        hex"f9565ea242552c2a1a216404344b0c8f6a3093382a21dd5bd6f5dc2ff1934d00";

    error FunctionNotSupportedOnThisNetwork();
    error InvalidNonMigratableGasBackingPercentage();

    event NonMigratableGasBackingPercentageSet(uint256 nonMigratableGasBackingPercentage_);

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
        address customToken_,
        address underlyingToken_,
        address lxlyBridge_,
        uint32 layerXNetworkId_,
        uint256 nonMigratableBackingPercentage_,
        address migrationManager_,
        uint256 nonMigratableGasBackingPercentage_
    ) external initializer {
        WETHNativeConverterStorage storage $ = _getWETHNativeConverterStorage();

        // Initialize the base implementation.
        __NativeConverter_init(
            owner_,
            customToken_,
            underlyingToken_,
            lxlyBridge_,
            layerXNetworkId_,
            nonMigratableBackingPercentage_,
            migrationManager_
        );

        require(nonMigratableGasBackingPercentage_ <= 1e18, InvalidNonMigratableBackingPercentage());

        $._weth = WETH(payable(customToken_));
        $._gasTokenIsEth =
            ILxLyBridge(lxlyBridge_).gasTokenAddress() == address(0) && ILxLyBridge(lxlyBridge_).gasTokenNetwork() == 0;
        $.nonMigratableGasBackingPercentage = nonMigratableGasBackingPercentage_;
    }

    function nonMigratableGasBackingPercentage() public view returns (uint256) {
        WETHNativeConverterStorage storage $ = _getWETHNativeConverterStorage();
        return $.nonMigratableGasBackingPercentage;
    }

    function _getWETHNativeConverterStorage() private pure returns (WETHNativeConverterStorage storage $) {
        assembly {
            $.slot := _WETH_NATIVE_CONVERTER_STORAGE
        }
    }

    function migratableGasBacking() public view returns (uint256) {
        WETHNativeConverterStorage storage $ = _getWETHNativeConverterStorage();

        uint256 nonMigratableGasBacking =
            _convertToAssets(Math.mulDiv(customToken().totalSupply(), $.nonMigratableGasBackingPercentage, 1e18));

        uint256 gasBalance = address(customToken()).balance;

        return gasBalance > nonMigratableGasBacking ? gasBalance - nonMigratableGasBacking : 0;
    }

    /// @dev This special function allows the NativeConverter owner to migrate the gas backing of the WETH Custom Token
    /// @dev It simply takes the amount of gas token from the WETH contract
    /// @dev and performs the migration using a special CrossNetworkInstruction called _1_WRAP_GAS_TOKEN_AND_COMPLETE_MIGRATION
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

        uint256 migratableGasBacking_ = migratableGasBacking();

        // Check the input.
        require(amount > 0, InvalidAssets());
        require(amount <= migratableGasBacking_, AssetsTooLarge(migratableGasBacking_, amount));

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
                MigrationManager.CrossNetworkInstruction._1_WRAP_GAS_TOKEN_AND_COMPLETE_MIGRATION,
                abi.encode(amountOfCustomToken, amount)
            )
        );

        // Emit the event.
        emit MigrationStarted(amountOfCustomToken, amount);
    }

    receive() external payable whenNotPaused onlyIfGasTokenIsEth {}

    function setNonMigratableGasBackingPercentage(uint256 nonMigratableGasBackingPercentage_)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        WETHNativeConverterStorage storage $ = _getWETHNativeConverterStorage();

        // Check the input.
        require(nonMigratableGasBackingPercentage_ <= 1e18, InvalidNonMigratableGasBackingPercentage());

        // Set the non-migratable backing percentage.
        $.nonMigratableGasBackingPercentage = nonMigratableGasBackingPercentage_;

        // Emit the event.
        emit NonMigratableGasBackingPercentageSet(nonMigratableGasBackingPercentage_);
    }
}
