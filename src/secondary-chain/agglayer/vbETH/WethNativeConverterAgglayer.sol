// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.0) (secondary-chain/agglayer/vbETH/WethNativeConverterAgglayer.sol)

pragma solidity 0.8.29;

// @remind Document the entire file.

import {NativeConverterAgglayer} from "../NativeConverterAgglayer.sol";
import {NativeConverter, Math} from "../../NativeConverter.sol";
import {WethAgglayer} from "./WethAgglayer.sol";
import {MigrationManager} from "../../../primary-chain/MigrationManager.sol";
import {IAgglayerBridge} from "../../../etc/IAgglayerBridge.sol";

/// @title WETH Native Converter (Agglayer)
/// @author See https://github.com/agglayer/vault-bridge
contract WethNativeConverterAgglayer is NativeConverterAgglayer {
    /// @dev Storage of WETHNativeConverter contract.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:agglayer.vault-bridge.WETHNativeConverter.storage
    struct WETHNativeConverterStorage {
        WethAgglayer __DEPRECATED___weth;
        bool _gasTokenIsEth;
        uint256 nonMigratableGasBackingPercentage;
    }

    /// @dev The storage slot at which WETHNativeConverter storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("agglayer.vault-bridge.WETHNativeConverter.storage")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _WETH_NATIVE_CONVERTER_AGGLAYER_STORAGE =
        hex"f9565ea242552c2a1a216404344b0c8f6a3093382a21dd5bd6f5dc2ff1934d00";

    error FunctionNotSupportedOnThisChain();
    error InvalidNonMigratableGasBackingPercentage();

    event NonMigratableGasBackingPercentageSet(uint256 nonMigratableGasBackingPercentage_);

    modifier onlyIfGasTokenIsEth() {
        WETHNativeConverterStorage storage $ = _getWethNativeConverterAgglayerStorage();
        require($._gasTokenIsEth, FunctionNotSupportedOnThisChain());
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function reinitialize1(
        address owner_,
        address customToken_,
        address underlyingToken_,
        address agglayerBridge_,
        uint32 primaryChainNetworkId_,
        uint256 nonMigratableBackingPercentage_,
        address migrationManager_,
        uint256 nonMigratableGasBackingPercentage_
    ) external locked reinitializer(_incrementGlobalInitializationCounter(1)) nonReentrant {
        WETHNativeConverterStorage storage $ = _getWethNativeConverterAgglayerStorage();

        // Initialize the base implementation.
        __NativeConverter_init1(
            owner_,
            customToken_,
            underlyingToken_,
            agglayerBridge_,
            primaryChainNetworkId_,
            nonMigratableBackingPercentage_,
            migrationManager_
        );

        require(nonMigratableGasBackingPercentage_ <= 1e18, InvalidNonMigratableBackingPercentage());

        $._gasTokenIsEth = IAgglayerBridge(agglayerBridge_).gasTokenAddress() == address(0)
            && IAgglayerBridge(agglayerBridge_).gasTokenNetwork() == 0;
        $.nonMigratableGasBackingPercentage = nonMigratableGasBackingPercentage_;
    }

    function reinitialize2() external locked reinitializer(_incrementGlobalInitializationCounter(2)) nonReentrant {
        __NativeConverter_init2();
    }

    /*
    /// @dev How to add a new reinitializer:
    function reinitialize3()
        external
        locked
        reinitializer(_incrementGlobalInitializationCounter(3))
        nonReentrant
    {}
    */

    // @remind Document (the entire function).
    function reinitialize(bytes[] calldata reinitializeData) external {
        bytes4[] memory reinitializeSelectors = new bytes4[](2);

        reinitializeSelectors[0] = this.reinitialize1.selector;
        reinitializeSelectors[1] = this.reinitialize2.selector;

        _reinitialize(reinitializeSelectors, reinitializeData);
    }

    /// @inheritdoc NativeConverter
    function _NATIVE_CONVERTER_INIT_2_COMPATIBLE() internal pure override {}

    function nonMigratableGasBackingPercentage() public view returns (uint256) {
        WETHNativeConverterStorage storage $ = _getWethNativeConverterAgglayerStorage();
        return $.nonMigratableGasBackingPercentage;
    }

    function _getWethNativeConverterAgglayerStorage() private pure returns (WETHNativeConverterStorage storage $) {
        assembly {
            $.slot := _WETH_NATIVE_CONVERTER_AGGLAYER_STORAGE
        }
    }

    function migratableGasBacking() public view returns (uint256) {
        WETHNativeConverterStorage storage $ = _getWethNativeConverterAgglayerStorage();

        uint256 nonMigratableGasBacking = _convertToAssets(
            Math.mulDiv(customToken().totalSupply(), $.nonMigratableGasBackingPercentage, 1e18, Math.Rounding.Ceil)
        );

        uint256 gasBacking = WethAgglayer(payable(address(customToken()))).gasBackingOnSecondaryChain();

        return gasBacking > nonMigratableGasBacking ? gasBacking - nonMigratableGasBacking : 0;
    }

    /// @dev This special function allows the NativeConverter owner to migrate the gas backing of the WETH Custom Token
    /// @dev It simply takes the amount of gas token from the WETH contract
    /// @dev and performs the migration using a special CrossChainInstruction called _1_WRAP_GAS_TOKEN_AND_COMPLETE_MIGRATION
    /// @dev It instructs vbETH on Primary Chain to first wrap the gas token and then deposit it to complete the migration.
    /// @notice It is known that this can lead to WETH not being able to perform withdrawals, because of a lack of gas backing.
    /// @notice However, this is acceptable, because WETH is a vault backed token so its backing should actually be staked.
    /// @notice Users can still bridge WETH back to Primary Chain to receive wETH or ETH.
    function migrateGasBackingToPrimaryChain(uint256 amount)
        external
        onlyIfGasTokenIsEth
        onlyRole(MIGRATOR_ROLE)
        nonReentrant
    {
        WethAgglayer weth = WethAgglayer(payable(address(customToken())));

        uint256 migratableGasBacking_ = migratableGasBacking();

        // Check the input.
        require(amount > 0, InvalidAssets());
        require(amount <= migratableGasBacking_, AssetsTooLarge(migratableGasBacking_, amount));

        _addMigrationInProgress(amount);

        // Precalculate the amount of Custom Token for which backing is being migrated.
        uint256 amountOfCustomToken = _convertToShares(amount);

        // Taking agglayerBridge's gas balance here
        weth.moveGasBackingToNativeConverter(amount);
        bridge().bridgeAsset{value: amount}(
            primaryChainAgglayerId(), address(migrationManager()), amount, address(0), true, ""
        );

        // Bridge a message to Migration Manager on Primary Chain to complete the migration.
        bridge()
            .bridgeMessage(
                primaryChainAgglayerId(),
                address(migrationManager()),
                true,
                abi.encode(
                    MigrationManager.CrossChainInstruction._1_WRAP_GAS_TOKEN_AND_COMPLETE_MIGRATION,
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
        WETHNativeConverterStorage storage $ = _getWethNativeConverterAgglayerStorage();

        // Check the input.
        require(nonMigratableGasBackingPercentage_ <= 1e18, InvalidNonMigratableGasBackingPercentage());

        // Set the non-migratable backing percentage.
        $.nonMigratableGasBackingPercentage = nonMigratableGasBackingPercentage_;

        // Emit the event.
        emit NonMigratableGasBackingPercentageSet(nonMigratableGasBackingPercentage_);
    }
}
