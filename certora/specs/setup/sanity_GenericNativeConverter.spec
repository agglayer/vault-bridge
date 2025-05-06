import "dispatching_GenericNativeConverter.spec";
use builtin rule sanity filtered { f ->
    f.contract == currentContract &&
    f.selector != sig:initialize(address,uint8,address,address,address,uint32,address,address,uint256).selector
}
