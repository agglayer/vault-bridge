//import "setup/dispatching_GenericVaultBridgeToken.spec";
//import "dispatching_ERC4626.spec";
import "GenericVaultBridgeToken_ERC4626.spec";

rule noActivityWhenPaused(method f, env e)
    filtered {f -> !excludedMethod(f) }
{
    requireLinking();
    bool paused = paused();
    calldataarg args;
    f@withrevert(e, args);
    bool reverted = lastReverted;
    assert paused => (reverted || isPrivilegedSender(e) || canBeCalledWhenPaused(f));
}

//_simulateWithdraw(x, true) == x or revert 
rule integrityOf_simulateWithdraw_force(env e)
{   
    uint256 assets;
    uint256 res = simulateWithdraw(e, assets, true);
    assert res == assets;
}

// meaning: reservedAssets + 1 >= minimumReservedAssets
// where minimumReservedAssets = minimumReservePercentage * totalSupply / 10^18
// we add "+ 1" as a margin for rounding errors
function isBalanced() returns bool
{
    return (reservedAssets() + 1) * 10^18 >= minimumReservePercentage() * totalSupply();
}

rule integrityOfRebalance(env e)
{
    safeAssumptions(e);
    rebalanceReserve(e, false, false);
    assert isBalanced();
}
