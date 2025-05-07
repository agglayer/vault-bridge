import "dispatching_WETHNativeConverter.spec";
use builtin rule sanity filtered { f ->
    f.contract == currentContract &&
    f.selector != sig:initialize(address,uint8,address,address,address,uint32,uint256,address).selector &&
    f.selector != sig:reinitialize(address,uint8,address,address,address,uint32,uint256,address).selector

}
