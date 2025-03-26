// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.28;

interface IVaultBridgeTokenInitializer {
    function __VaultBackedTokenInit_init(
        address owner_,
        string calldata name_,
        string calldata symbol_,
        address underlyingToken_,
        uint256 minimumReservePercentage_,
        address yieldVault_,
        address yieldRecipient_,
        address lxlyBridge_,
        NativeConverterInfo[] calldata nativeConverters_,
        uint256 minimumYieldVaultDeposit_,
        address transferFeeUtil_
    ) external;
}

/// @dev Used when setting Native Converter on Layer Xs.
struct NativeConverterInfo {
    uint32 layerYLxlyId;
    address nativeConverter;
}
