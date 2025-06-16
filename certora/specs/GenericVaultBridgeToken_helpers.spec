import "MathSummaries.spec";
import "GenericVaultBridgeToken_methods.spec";

using VaultMock as yieldVaultContract;

function userAssets(address a) returns uint256
{
    return ERC20a.balanceOf(a);
}

function requireLinking() 
{
    require yieldVault() == yieldVaultContract;
    require yieldVaultContract.asset() == ERC20a;
    require asset() == ERC20a;

    require lxlyBridge() == ILxLyBridgeMock;
}

function callContributionMethods(env e, method f, uint256 assets, uint256 shares, address receiver) {
    if (f.selector == sig:deposit(uint256,address).selector) {
        deposit(e, assets, receiver);
    }
    if (f.selector == sig:depositAndBridge(uint256,address,uint32,bool).selector) {
        uint32 destinationNetworkId;
        bool forceUpdateGlobalExitRoot;
        depositAndBridge(e, assets, receiver, destinationNetworkId, forceUpdateGlobalExitRoot);
    }
    if (f.selector == sig:depositWithPermit(uint256,address,bytes).selector) {
        bytes permitData;
        depositWithPermit(e, assets, receiver, permitData);
    }
    if (f.selector == sig:depositWithPermitAndBridge(uint256,address,uint32,bool,bytes).selector) {
        uint32 destinationNetworkId;
        bool forceUpdateGlobalExitRoot;
        bytes permitData;
        depositWithPermitAndBridge(e, assets, receiver, destinationNetworkId, forceUpdateGlobalExitRoot, permitData);
    }
    if (f.selector == sig:mint(uint256,address).selector) {
        mint(e, shares, receiver);
    }
}

function callReclaimingMethods(env e, method f, uint256 assets, uint256 shares, address receiver, address owner) {
    if (f.selector == sig:withdraw(uint256,address,address).selector) {
        withdraw(e, assets, receiver, owner);
    }
    if (f.selector == sig:redeem(uint256,address,address).selector) {
        redeem(e, shares, receiver, owner);
    }
    if (f.selector == sig:claimAndRedeem(bytes32[32],bytes32[32],uint256,bytes32,bytes32,address,uint256,address,bytes).selector) {
        bytes32[32] smtProofLocalExitRoot;
        bytes32[32] smtProofRollupExitRoot;
        uint256 globalIndex;
        bytes32 mainnetExitRoot;
        bytes32 rollupExitRoot;
        bytes metadata;
        claimAndRedeem(e, 
            smtProofLocalExitRoot,
            smtProofRollupExitRoot,
            globalIndex,
            mainnetExitRoot,
            rollupExitRoot,
            owner, shares, receiver, metadata);
    }
}

function requireNonSceneSender(env e)
{
    require e.msg.sender != GenericVaultBridgeToken;
    require !hasRole(e, DEFAULT_ADMIN_ROLE(e), e.msg.sender);
    require e.msg.sender != yieldVaultContract;
}

function isPrivilegedSender(env e) returns bool
{
    return e.msg.sender == GenericVaultBridgeToken ||
        hasRole(e, DEFAULT_ADMIN_ROLE(e), e.msg.sender) ||
        hasRole(e, PAUSER_ROLE(e), e.msg.sender) ||
        hasRole(e, REBALANCER_ROLE(e), e.msg.sender) ||
        hasRole(e, YIELD_COLLECTOR_ROLE(e), e.msg.sender) ||
        e.msg.sender == yieldRecipient() 
        ;
}

definition canBeCalledWhenPaused(method f) returns bool =
    //f.selector == sig:initialize(address,address,string,string,address,uint256,address,address,address,uint256,address,uint256).selector ||
    f.selector == sig:burn(uint256).selector ||
    f.selector == sig:grantRole(bytes32,address).selector ||
    f.selector == sig:revokeRole(bytes32,address).selector ||
    f.selector == sig:renounceRole(bytes32,address).selector ||
    f.selector == sig:donateAsYield(uint256).selector
;

definition excludedMethod(method f) returns bool =
    f.isView || f.isFallback ||
    f.selector == sig:initialize(address, VaultBridgeToken.InitializationParameters).selector ||
    
    // harness methods
    f.selector == sig:simulateWithdraw(uint256,bool).selector ||
    f.selector == sig:rebalanceReserve(bool,bool).selector 
;

