// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.28;

import {NativeConverter} from "../../NativeConverter.sol";
import {ZETH} from "../../customTokens/zETH.sol";

/// @title WETH Native Converter
/// @dev No customization is required.
/// @dev This contract does not need to be deployed. You can point WETHNativeConverter proxy to GenericNativeConverter instead.
contract WETHNativeConverter is NativeConverter {
    ZETH zETH;

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
        address lxlyBridge_,
        uint32 layerXNetworkId_,
        address migrationManager_
    ) external initializer {
        // Initialize the base implementation.
        __NativeConverter_init(
            owner_,
            originalUnderlyingTokenDecimals_,
            customToken_,
            wrappedUnderlyingToken_,
            nonMigratableBackingPercentage_,
            lxlyBridge_,
            layerXNetworkId_,
            migrationManager_
        );

        zETH = ZETH(zETH_);
    }

    function migrateGasBackingToLayerX(uint256 amount) external whenNotPaused onlyOwner {
        _migrateGasBackingToLayerX(amount);
    }

    function _migrateGasBackingToLayerX(uint256 amount) internal {

        // Check the input.
        require(amount > 0, "INVALID_AMOUNT");
        require(amount <= address(zETH).balance, "AMOUNT_TOO_LARGE");

        // Precalculate the amount of the custom token for which backing is being migrated.
        uint256 amountOfCustomToken = _convertToShares(amount);

        // Taking lxlyBridge's gas balance here
        uint256 previousBalance = address(lxlyBridge()).balance;
        zETH.bridgeBackingToLayerX(amount);
        lxlyBridge().bridgeAsset{value: amount}(layerXNetworkId(), migrationManager(), amount, address(0), true, "");
        amount = address(lxlyBridge()).balance - previousBalance;

        // Bridge a message to Migration Manager on Layer X to complete the migration.
        lxlyBridge().bridgeMessage(
            layerXNetworkId(),
            migrationManager(),
            true,
            abi.encode(CrossNetworkInstruction.COMPLETE_MIGRATION, amountOfCustomToken, amount)
        );

        // Emit the event.
        emit MigrationStarted(msg.sender, amountOfCustomToken, amount);
    }
}
