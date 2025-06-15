//import "setup/dispatching_GenericVaultBridgeToken.spec";
//import "dispatching_ERC4626.spec";
import "GenericVaultBridgeToken_basicInvariants.spec";
import "GenericVaultBridgeToken_storageSnapshot.spec";

methods {
    // function VaultBridgeToken._rebalanceReserve(bool force, bool allowRebalanceDown) internal => rebalanceCVL(force, allowRebalanceDown);
}


ghost bool rebalanceWasCalled;

function initGhosts()
{
    rebalanceWasCalled = false;
}

function rebalanceCVL(bool force, bool allowRebalanceDown)
{
    rebalanceWasCalled = true;
}

function isBalanced() returns bool
{
    return reservePercentage() >= minimumReservePercentage();
}

rule rebalanceIsCalledAfterEveryPublicMethod(method f, env e)
    filtered {f -> !excludedMethod(f) }
{
    initGhosts();
    calldataarg args;
    f(e, args);
    
    assert !isPrivilegedSender(e) => (rebalanceWasCalled || isBalanced());
}

rule staysBalanced(method f, env e)
    filtered { f -> !excludedMethod(f) }
{
    requireNonSceneSender(e);
    require !isPrivilegedSender(e), "admin methods are allowed to break this";
    require minimumReservePercentage() <= 10^18, "TODO change to requireInvariant and prove";
    initGhosts();
    snapshotStorage(0);
    bool balancedBefore = isBalanced();
    calldataarg args;
    f(e, args);
    bool balancedAfter = isBalanced();
    snapshotStorage(1);
    assert balancedBefore => (balancedAfter || rebalanceWasCalled);
}

rule balancedAfterRebalance(env e)
{
    safeAssmuptions(e);
    _rebalanceReserve(e, false, false);
    assert isBalanced();
}

