import "dispatching_VbETH.spec";

using VaultBridgeTokenInitializer as VaultBridgeTokenInitializer;

use builtin rule sanity filtered { f ->
    f.contract == currentContract &&
    f.selector != sig:initialize(address,VaultBridgeToken.InitializationParameters).selector
}

rule sanity_initialize() {
    env e;

    address initializer = VaultBridgeTokenInitializer;
    VaultBridgeToken.InitializationParameters ip;
    require(ip.transferFeeCalculator == 0);

    initialize(e, initializer, ip);

    satisfy(true);
}