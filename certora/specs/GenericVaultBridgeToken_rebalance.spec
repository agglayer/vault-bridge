import "GenericVaultBridgeToken_basicInvariants.spec";

function isBalanced() returns bool
{
    return (reservedAssets() + 1) * 10^18 >= minimumReservePercentage() * totalSupply();
}

rule balancedAfterRebalance(env e)
{
    safeAssumptions(e);
    rebalanceReserve(e, false, false);
    assert isBalanced();
}

