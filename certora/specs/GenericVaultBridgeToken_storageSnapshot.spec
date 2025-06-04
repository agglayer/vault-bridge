// Allows to mirror the current storage in persistent ghost state to be easily accesible in rules.
// How to use:
// 1. call snapshotStorage(0) to capture current storage with index 0
// 2. call snapshotStorage(1) to capture current storage with index 1
// both snapshots will be accessible in the calltrace
// the snapshots_1 are updated in both calls so you can see the difference also via the Global state diff

import "GenericVaultBridgeToken_helpers.spec";

persistent ghost address underlyingToken0;
persistent ghost uint256 minimumReservePercentage0;
persistent ghost address yieldRecipient0;
persistent ghost uint256 minimumYieldVaultDeposit0;
persistent ghost uint256 yieldVaultMaximumSlippagePercentage0;
persistent ghost uint256 totalAssets0; 
persistent ghost uint256 totalSupply0; 
persistent ghost uint256 stakedAssets0;
persistent ghost uint256 reservedAssets0;
persistent ghost uint256 yieldVaultShares0;

persistent ghost address underlyingToken1;
persistent ghost uint256 minimumReservePercentage1;
persistent ghost address yieldRecipient1;
persistent ghost uint256 minimumYieldVaultDeposit1;
persistent ghost uint256 yieldVaultMaximumSlippagePercentage1;
persistent ghost uint256 totalAssets1; 
persistent ghost uint256 totalSupply1; 
persistent ghost uint256 stakedAssets1;
persistent ghost uint256 reservedAssets1;
persistent ghost uint256 yieldVaultShares1;

function snapshotStorage(uint256 index)
{
    if (index == 0)
    {
        underlyingToken0 = asset();
        minimumReservePercentage0 = minimumReservePercentage();
        yieldRecipient0 = yieldRecipient();
        minimumYieldVaultDeposit0 = minimumYieldVaultDeposit();
        yieldVaultMaximumSlippagePercentage0 = yieldVaultMaximumSlippagePercentage();
        totalAssets0 = totalAssets();
        totalSupply0 = totalSupply();
        stakedAssets0 = stakedAssets();
        reservedAssets0 = reservedAssets();
        yieldVaultShares0 = yieldVaultContract.balanceOf(GenericVaultBridgeToken);
    }
        
    underlyingToken1 = asset();
    minimumReservePercentage1 = minimumReservePercentage();
    yieldRecipient1 = yieldRecipient();
    minimumYieldVaultDeposit1 = minimumYieldVaultDeposit();
    yieldVaultMaximumSlippagePercentage1 = yieldVaultMaximumSlippagePercentage();
    totalAssets1 = totalAssets();
    totalSupply1 = totalSupply();
    stakedAssets1 = stakedAssets();
    reservedAssets1 = reservedAssets();
    yieldVaultShares1 = yieldVaultContract.balanceOf(GenericVaultBridgeToken);
    
}