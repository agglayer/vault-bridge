import "dispatching_MigrationManager.spec";

using GenericVaultBridgeToken as GenericVaultBridgeToken;

use builtin rule sanity filtered { f ->
    f.contract == currentContract && 
    f.selector != sig:configureNativeConverters(uint32[],address[],address).selector
}

rule sanity_configureNativeConverters() {
    env e;

    uint32[] layerYLxlyIds;
    address[] nativeConverters;
    address vbToken = GenericVaultBridgeToken;

    require(layerYLxlyIds.length > 0);

    configureNativeConverters(e, layerYLxlyIds, nativeConverters, vbToken);

    satisfy(true);
}
