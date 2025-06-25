import "dispatching_MigrationManager.spec";

using GenericVaultBridgeToken as GenericVaultBridgeToken;
using VaultBridgeTokenPart2 as VaultBridgeTokenPart2;

methods {
    function _.completeMigration(uint32 o, uint256 s, uint256 a) external with(env e) => CVL_completeMigration(e, o, s, a) expect void;
    function GenericVaultBridgeToken.underlyingToken() external returns (address) envfree;
    function _.underlyingToken() external => CVL_underlyingToken() expect (address);
}

function CVL_completeMigration(env e, uint32 o, uint256 s, uint256 a) {
    VaultBridgeTokenPart2.completeMigration(e, o, s, a);
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

rule onMsgReceived_doesntAlwaysRevert(env e)
{
    address originAddress; uint32 originNetwork; bytes data;
    onMessageReceived(e, originAddress, originNetwork, data);
    satisfy true;
}
