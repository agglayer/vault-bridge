/* Integrity of preview functions */

import "dispatching_ERC4626.spec";
import "GenericVaultBridgeToken_helpers.spec";

rule previewRedeemCorrectness_strict(env e, address receiver)
{
    requireNonSceneSender(e);
    requireLinking();
    
    uint256 shares;
    uint256 assetsReported = previewRedeem(shares);
    uint256 assetsReceived = redeem(e, shares, receiver, e.msg.sender);

    assert assetsReported == assetsReceived;
}

rule previewRedeemCorrectness(env e, address receiver)
{
    requireNonSceneSender(e);
    requireLinking();
    
    uint256 shares;
    uint256 assetsReported = previewRedeem(shares);
    uint256 assetsReceived = redeem(e, shares, receiver, e.msg.sender);

    assert assetsReported <= assetsReceived;
}

// rule previewBorrowCorrectness_strict(env e, address receiver)
// {
//     requireNonSceneSender(e);
//     requireLinking();
    
//     // bool sameAsset;
//     uint256 assets;
//     uint256 debtSharesReported = previewBorrow(assets);
//     uint256 debtSharesReceived = borrow(e, assets, receiver, e.msg.sender); // , sameAsset);
//     assert debtSharesReported == debtSharesReceived;
// }

// rule previewBorrowCorrectness(env e, address receiver)
// {
//     requireNonSceneSender(e);
//     requireLinking();
    
//     // bool sameAsset;
//     uint256 assets;
//     uint256 debtSharesReported = previewBorrow(assets);
//     uint256 debtSharesReceived = borrow(e, assets, receiver, e.msg.sender); // , sameAsset);
//     assert debtSharesReported >= debtSharesReceived;
// }

// rule previewBorrowSharesCorrectness_strict(env e, address receiver)
// {
//     requireNonSceneSender(e);
//     requireLinking();
    
//     // bool sameAsset;
//     uint256 shares;
//     uint256 assetsReported = previewBorrowShares(shares);
//     uint256 assetsReceived = borrowShares(e, shares, receiver, e.msg.sender); // , sameAsset);
//     assert assetsReported == assetsReceived;
// }

// rule previewBorrowSharesCorrectness(env e, address receiver)
// {
//     requireNonSceneSender(e);
//     requireLinking();
    
//     // bool sameAsset;
//     uint256 shares;
//     uint256 assetsReported = previewBorrowShares(shares);
//     uint256 assetsReceived = borrowShares(e, shares, receiver, e.msg.sender); // , sameAsset);
//     assert assetsReported <= assetsReceived;
// }

// rule previewRepaySharesCorrectness_strict(env e, address receiver)
// {
//     requireNonSceneSender(e);
//     requireLinking();
    
//     uint256 shares;
//     uint256 assetsReported = previewRepayShares(shares);
//     uint256 assetsPaid = repayShares(e, shares, receiver);
//     assert assetsReported == assetsPaid;
// }

// rule previewRepaySharesCorrectness(env e, address receiver)
// {
//     requireNonSceneSender(e);
//     requireLinking();
    
//     uint256 shares;
//     uint256 assetsReported = previewRepayShares(shares);
//     uint256 assetsPaid = repayShares(e, shares, receiver);
//     assert assetsReported >= assetsPaid;
// }

rule previewWithdrawCorrectness_strict(env e, address receiver)
{
    requireNonSceneSender(e);
    requireLinking();
    
    uint256 assets;
    uint256 sharesReported = previewWithdraw(assets);
    uint256 sharesPaid = withdraw(e, assets, receiver, e.msg.sender);
    assert sharesPaid == sharesReported;
}

rule previewWithdrawCorrectness(env e, address receiver)
{
    requireNonSceneSender(e);
    requireLinking();
    
    uint256 assets;
    uint256 sharesReported = previewWithdraw(assets);
    uint256 sharesPaid = withdraw(e, assets, receiver, e.msg.sender);
    assert sharesPaid <= sharesReported;
}

// rule previewRepayCorrectness_strict(env e, address receiver)
// {
//     requireNonSceneSender(e);
//     requireLinking();
    
//     uint256 assets;
//     uint256 debtSharesReported = previewRepay(assets);
//     uint256 debtSharesRepaid = repay(e, assets, receiver);
//     assert debtSharesReported == debtSharesRepaid;
// }

// rule previewRepayCorrectness(env e, address receiver)
// {
//     requireNonSceneSender(e);
//     requireLinking();
    
//     uint256 assets;
//     uint256 debtSharesReported = previewRepay(assets);
//     uint256 debtSharesRepaid = repay(e, assets, receiver);
//     assert debtSharesReported <= debtSharesRepaid;
// }

rule previewMintCorrectness_strict(env e, address receiver)
{
    requireNonSceneSender(e);
    requireLinking();
    
    uint256 shares;
    uint256 assetsReported = previewMint(shares);
    uint256 assetsPaid = mint(e, shares, receiver);

    assert assetsReported == assetsPaid;
}   

rule previewMintCorrectness(env e, address receiver)
{
    requireNonSceneSender(e);
    requireLinking();

    uint256 shares;
    uint256 assetsReported = previewMint(shares);
    uint256 assetsPaid = mint(e, shares, receiver);

    assert assetsReported <= assetsPaid;
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

rule previewDepositCorrectness(env e, address receiver)
{
    requireNonSceneSender(e);
    requireLinking();
    
    uint256 assets;
    uint256 sharesReported = previewDeposit(assets);
    uint256 sharesReceived = deposit(e, assets, receiver);

    assert sharesReported <= sharesReceived;
}