// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.29;

// Main functionality.
import {VaultBridgeToken} from "../VaultBridgeToken.sol";

// @remind Document.
interface IVaultBridgeTokenInitializer {
    // @remind Document.
    function initialize(VaultBridgeToken.InitializationParameters calldata initParams)
        external
        returns (bool success);
}
