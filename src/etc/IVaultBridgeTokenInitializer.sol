// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.28;

interface IVaultBridgeTokenInitializer {
    function __VaultBackedTokenInit_init(InitDataStruct calldata data)
        //     address owner_,
        //     string calldata name_,
        //     string calldata symbol_,
        //     address underlyingToken_,
        //     uint256 minimumReservePercentage_,
        //     address yieldVault_,
        //     address yieldRecipient_,
        //     address lxlyBridge_,
        //    // NativeConverterInfo[] calldata nativeConverters_,
        //     uint256 minimumYieldVaultDeposit_,
        //     address transferFeeUtil_
        external;
}

/// @dev Used when setting Native Converter on Layer Xs.
struct NativeConverterInfo {
    uint32 layerYLxlyId;
    address nativeConverter;
}

struct InitDataStruct {
    address owner;
    string name;
    string symbol;
    address underlyingToken;
    uint256 minimumReservePercentage;
    address yieldVault;
    address yieldRecipient;
    address lxlyBridge;
    uint256 minimumYieldVaultDeposit;
    address transferFeeUtil;
}
