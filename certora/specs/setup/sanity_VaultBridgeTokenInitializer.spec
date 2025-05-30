import "dispatching_VaultBridgeTokenInitializer.spec";

using TokenMock as TokenMock;

use builtin rule sanity filtered { f ->
    f.contract == currentContract &&
    f.selector != sig:initialize(VaultBridgeToken.InitializationParameters).selector
}

rule sanity_initialize() {
    env e;

    VaultBridgeToken.InitializationParameters ip;
    require(ip.underlyingToken == TokenMock);

    initialize(e, ip);

    satisfy(true);
}
