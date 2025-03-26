// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.28;

// @todo Remove `SafeERC20`, `IERC20`.
import {NativeConverter, SafeERC20, IERC20} from "../../NativeConverter.sol";
import {WETH} from "./WETH.sol";
import {IVersioned} from "../../etc/IVersioned.sol";

/// @title WETH Native Converter
contract WETHNativeConverter is NativeConverter {
    // @todo Remove.
    using SafeERC20 for IERC20;

    WETH weth;

    enum CustomCrossNetworkInstruction {
        WRAP_COIN_AND_COMPLETE_MIGRATION
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
        address vbToken_,
        address migrator_
    ) external initializer {
        // Initialize the base implementation.
        __NativeConverter_init(
            owner_,
            originalUnderlyingTokenDecimals_,
            customToken_,
            underlyingToken_,
            lxlyBridge_,
            layerXNetworkId_,
            vbToken_,
            migrator_
        );

        weth = WETH(payable(customToken_));
    }

    // @todo Remove.
    function reinitialize(
        address owner_,
        uint8 originalUnderlyingTokenDecimals_,
        address customToken_,
        address underlyingToken_,
        address lxlyBridge_,
        uint32 layerXNetworkId_,
        address vbToken_,
        address migrator_
    ) external reinitializer(2) {
        underlyingToken().forceApprove(address(lxlyBridge()), 0);

        // Reinitialize the base implementation.
        __NativeConverter_init(
            owner_,
            originalUnderlyingTokenDecimals_,
            customToken_,
            underlyingToken_,
            lxlyBridge_,
            layerXNetworkId_,
            vbToken_,
            migrator_
        );

        weth = WETH(payable(customToken_));
    }

    /// @dev This special function allows the NativeConverter owner to migrate the gas backing of the WETH Custom Token
    /// @dev It simply takes the amount of gas token from the WETH contract
    /// @dev and performs the migration using a special CrossNetworkInstruction called WRAP_COIN_AND_COMPLETE_MIGRATION
    /// @dev It instructs vbETH on Layer X to first wrap the gas token and then deposit it to complete the migration.
    /// @notice It is known that this can lead to WETH not being able to perform withdrawals, because of a lack of gas backing.
    /// @notice However, this is acceptable, because WETH is a vault backed token so its backing should actually be staked.
    /// @notice Users can still bridge WETH back to Layer X to receive wETH or ETH.
    function migrateGasBackingToLayerX(uint256 amount) external whenNotPaused onlyOwner {
        // Check the input.
        require(amount > 0, InvalidAssets());
        require(amount <= address(weth).balance, AssetsTooLarge(address(weth).balance, amount));

        // Precalculate the amount of Custom Token for which backing is being migrated.
        uint256 amountOfCustomToken = _convertToShares(amount);

        // Taking lxlyBridge's gas balance here
        weth.bridgeBackingToLayerX(amount);
        lxlyBridge().bridgeAsset{value: amount}(layerXLxlyId(), address(vbToken()), amount, address(0), true, "");

        // Bridge a message to Migration Manager on Layer X to complete the migration.
        lxlyBridge().bridgeMessage(
            layerXLxlyId(),
            address(vbToken()),
            true,
            abi.encode(
                CrossNetworkInstruction.CUSTOM,
                abi.encode(
                    CustomCrossNetworkInstruction.WRAP_COIN_AND_COMPLETE_MIGRATION,
                    abi.encode(amountOfCustomToken, amount)
                )
            )
        );

        // Emit the event.
        emit MigrationStarted(msg.sender, amountOfCustomToken, amount);
    }

    receive() external payable {}

    /// @inheritdoc IVersioned
    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }
}
