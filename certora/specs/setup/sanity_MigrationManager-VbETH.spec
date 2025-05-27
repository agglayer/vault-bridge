import "dispatching_MigrationManager.spec";

using VbETH as VbETH;

methods {
    function VbETH.underlyingToken() external returns (address) envfree;
    function _.underlyingToken() external => VbETH.underlyingToken() expect (address);
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
