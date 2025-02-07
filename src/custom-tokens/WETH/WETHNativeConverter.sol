// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.28;

import {NativeConverter} from "../../NativeConverter.sol";
import {ZETH} from "./zETH.sol";
import {IVersioned} from "../../etc/IVersioned.sol";

/// @title WETH Native Converter
contract WETHNativeConverter is NativeConverter {
    ZETH zETH;

    error AmountTooLarge();

    enum CustomCrossNetworkInstruction {
        WRAP_COIN_AND_COMPLETE_MIGRATION
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address payable zETH_,
        address owner_,
        uint8 originalUnderlyingTokenDecimals_,
        address customToken_,
        address wrappedUnderlyingToken_,
        uint256 nonMigratableBackingPercentage_,
        uint256 minimumBackingAfterMigration_,
        address lxlyBridge_,
        uint32 layerXNetworkId_,
        address yeToken_
    ) external initializer {
        // Initialize the base implementation.
        __NativeConverter_init(
            owner_,
            originalUnderlyingTokenDecimals_,
            customToken_,
            wrappedUnderlyingToken_,
            nonMigratableBackingPercentage_,
            minimumBackingAfterMigration_,
            lxlyBridge_,
            layerXNetworkId_,
            yeToken_
        );

        zETH = ZETH(zETH_);
    }

    /// @dev This special function allows the NativeConverter owner to migrate the gas backing of the zETH Custom Token
    /// @dev It simply takes the amount of gas token from the zETH contract
    /// @dev and performs the migration using a special CrossNetworkInstruction called WRAP_COIN_AND_COMPLETE_MIGRATION
    /// @dev It instructs yeETH on Layer X to first wrap the gas token and then deposit it to complete the migration.
    /// @notice It is known that this can lead to zETH not being able to perform withdrawals, because of a lack of gas backing.
    /// @notice However, this is acceptable, because zETH is a yield-exposed token so its backing should actually be staked.
    /// @notice Users can still bridge zETH back to Layer X to receive WETH or ETH.
    function migrateGasBackingToLayerX(uint256 amount) external whenNotPaused onlyOwner {
        // Check the input.
        require(amount <= address(zETH).balance, AmountTooLarge());

        // Precalculate the amount of Custom Token for which backing is being migrated.
        uint256 amountOfCustomToken = _convertToShares(amount);

        // Taking lxlyBridge's gas balance here
        zETH.bridgeBackingToLayerX(amount);
        lxlyBridge().bridgeAsset{value: amount}(layerXLxlyId(), address(yeToken()), amount, address(0), true, "");

        // Bridge a message to Migration Manager on Layer X to complete the migration.
        lxlyBridge().bridgeMessage(
            layerXLxlyId(),
            address(yeToken()),
            true,
            abi.encode(
                CrossNetworkInstruction.CUSTOM,
                CustomCrossNetworkInstruction.WRAP_COIN_AND_COMPLETE_MIGRATION,
                amountOfCustomToken,
                amount
            )
        );

        // Emit the event.
        emit MigrationStarted(msg.sender, amountOfCustomToken, amount);
    }

    /// @inheritdoc IVersioned
    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }
}
