import "dispatching_MigrationManager.spec";

using GenericVaultBridgeToken as GenericVaultBridgeToken;

methods {
    function GenericVaultBridgeToken.underlyingToken() external returns (address) envfree;
    function _.underlyingToken() external => CVL_underlyingToken() expect (address);
}

function CVL_underlyingToken() returns address {
    return GenericVaultBridgeToken.underlyingToken();
}

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
