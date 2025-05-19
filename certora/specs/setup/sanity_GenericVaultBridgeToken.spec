import "dispatching_GenericVaultBridgeToken.spec";

methods {
    function asset() external returns address envfree;
}

use builtin rule sanity filtered { f -> f.contract == currentContract }

rule underlyingCannotChange() {
    address originalAsset = asset();

    method f; env e; calldataarg args;
    f(e, args);

    address newAsset = asset();

    assert originalAsset == newAsset,
        "the underlying asset of a contract must not change";
}
