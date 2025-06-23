import "GenericVaultBridgeToken_ERC4626.spec";

// Only allowed methods may be called when paused
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
    uint256 res = simulateWithdraw_harness(e, assets, true);
    assert res == assets;
}

// meaning: reservedAssets + 1 >= minimumReservedAssets
// where minimumReservedAssets = minimumReservePercentage * totalSupply / 10^18
// we add "+ 1" as a margin for rounding errors
function isBalanced() returns bool
{
    return (reservedAssets() + 1) * 10^18 >= minimumReservePercentage() * totalSupply();
}

// After calling rebalanceReserve, the reservedAssets >= minimumReservedAssets  
rule integrityOfRebalance(env e)
{
    safeAssumptions(e);
    uint256 assetsBefore = totalAssets();
    rebalanceReserve_harness(e, false, false);
    uint256 assetsAfter = totalAssets();
    assert isBalanced();
    assert assetsBefore == assetsAfter;
}

// nonDeposited = depositIntoYieldVault(assets) then nonDeposited <= assets
rule integrityOf_depositIntoYieldVault(env e)
{
    safeAssumptions(e);
    uint assets; bool exact;
    uint nonDeposited = depositIntoYieldVault_harness(e, assets, exact);
    assert nonDeposited <= assets;
}

rule previewRedeemCorrectness_strict(env e, address receiver)
{
    requireNonSceneSender(e);
    requireLinking();
    
    uint256 shares;
    uint256 assetsReported = previewRedeem(shares);
    uint256 assetsReceived = redeem(e, shares, receiver, e.msg.sender);

    assert assetsReported == assetsReceived;
}

rule previewWithdrawCorrectness_strict(env e, address receiver)
{
    requireNonSceneSender(e);
    requireLinking();
    
    uint256 assets;
    uint256 sharesReported = previewWithdraw(assets);
    uint256 sharesPaid = withdraw(e, assets, receiver, e.msg.sender);
    assert sharesPaid == sharesReported;
}

rule previewMintCorrectness_strict(env e, address receiver)
{
    requireNonSceneSender(e);
    requireLinking();
    
    uint256 shares;
    uint256 assetsReported = previewMint(shares);
    uint256 assetsPaid = mint(e, shares, receiver);

    assert assetsReported == assetsPaid;
}   

rule previewDepositCorrectness_strict(env e, address receiver)
{
    requireNonSceneSender(e);
    requireLinking();
    
    uint256 assets;
    uint256 sharesReported = previewDeposit(assets);
    uint256 sharesReceived = deposit(e, assets, receiver);

    assert sharesReported == sharesReceived;
}