import "dispatching_MigrationManager.spec";

using VbETH as VbETH;

methods {
    function _.underlyingToken() external returns (address) => VbETH.underlyingToken();
}

use builtin rule sanity filtered { f ->
    f.contract == currentContract && 
    f.selector != sig:configureNativeConverters(uint32[],address[],address).selector
}

rule sanity_configureNativeConverters() {
    env e;

    uint32[] layerYLxlyIds;
    address[] nativeConverters;
    address vbToken = VbETH;

    configureNativeConverters(e, layerYLxlyIds, nativeConverters, vbToken);

    satisfy(true);
}
