import "dispatching_VaultBridgeTokenInitializer-VbUSDT.spec";

using BridgeL2SovereignChain as BridgeL2SovereignChain;
using MockERC20 as MockERC20;

use builtin rule sanity filtered { f ->
    f.contract == currentContract &&
    f.selector != sig:initialize(VaultBridgeToken.InitializationParameters).selector
}

rule sanity_initialize() {
    env e;

    VaultBridgeToken.InitializationParameters ip;
    require(ip.lxlyBridge == BridgeL2SovereignChain);
    require(ip.underlyingToken == MockERC20);
    require(ip.transferFeeCalculator == USDTTransferFeeCalculator);

    initialize(e, ip);

    satisfy(true);
}
