import "dispatching_GenericVaultBridgeToken.spec";

using GenericVaultBridgeToken as GenericVaultBridgeToken;
using MigrationManager as MigrationManager;

methods {
    function asset() external returns address envfree;
}

use builtin rule sanity filtered { f -> f.contract == currentContract }

rule underlyingCannotChange() {
    address originalAsset = asset();

    env e;
    method f;
    if (f.selector == sig:MigrationManager.configureNativeConverters(uint32[],address[],address).selector) {
        uint32[] layerYLxlyIds;
        address[] nativeConverters;
        address vbToken = GenericVaultBridgeToken;
        MigrationManager.configureNativeConverters(e, layerYLxlyIds, nativeConverters, vbToken);
    } else {
        calldataarg args;
        f(e, args);
    }
    address newAsset = asset();

    assert originalAsset == newAsset,
        "the underlying asset of a contract must not change";
}
