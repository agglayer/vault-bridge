import "dispatching_WETH.spec";

using WETHNativeConverter as WETHNativeConverter;

use builtin rule sanity filtered { f ->
    f.contract == currentContract &&
    f.selector != sig:reinitialize(address,string,string,uint8,address,address).selector
}

rule sanity_reinitialize() {
    env e;

    address owner_;
    string name_;
    string symbol_;
    uint8 originalUnderlyingTokenDecimals_;
    address lxlyBridge_;
    address nativeConverter_ = WETHNativeConverter;

    reinitialize(e, owner_, name_, symbol_, originalUnderlyingTokenDecimals_, lxlyBridge_, nativeConverter_);

    satisfy(true);
}
