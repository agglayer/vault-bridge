/* Integrity of preview functions */

//import "dispatching_ERC4626.spec";
import "GenericVaultBridgeToken_basicInvariants.spec";

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
