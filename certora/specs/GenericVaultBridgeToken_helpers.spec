import "MathSummaries.spec";
import "GenericVaultBridgeToken_methods.spec";

//using DummyERC20B as ERC20b; 
using VaultMock as yieldVaultContract;

function userAssets(address a) returns uint256
{
    return ERC20a.balanceOf(a);
}

// An alternative solution to the linking. We prefer the requireLinking instead which is called in safeAssmuptions
// hook Sload address addr GenericVaultBridgeToken.vaultBridgeTokenStorage.underlyingToken {
//     require(addr == ERC20a);
// }

// This is needed since the linking in the conf doesn't work
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
}

function requireNonSceneSender(env e)
{
    require e.msg.sender != GenericVaultBridgeToken;
    require !hasRole(e, DEFAULT_ADMIN_ROLE(e), e.msg.sender);
    require e.msg.sender != yieldVaultContract;
}

function callFunctionsWithReceiverAndOwner2(env e, method f, address receiver, address owner) 
{
    uint256 assets; uint256 shares;
    callFunctionsWithReceiverAndOwner(e, f, assets, shares, receiver, owner);
}

function callFunctionsWithReceiverAndOwner(env e, method f, uint256 assets, uint256 shares, address receiver, address owner) {
    if (f.selector == sig:withdraw(uint256,address,address).selector) {
        withdraw(e, assets, receiver, owner);
    }
    // both versions of redeem:
    else if (f.selector == sig:redeem(uint256,address,address).selector) {
        redeem(e, shares, receiver, owner);
    }
    else if (f.selector == sig:claimAndRedeem(bytes32[32],bytes32[32],uint256,bytes32,bytes32,address,uint256,address,bytes).selector) {
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
    // all versions of deposit: 
    else if (f.selector == sig:deposit(uint256,address).selector) {
        deposit(e, assets, receiver);
    }
    else if (f.selector == sig:depositAndBridge(uint256,address,uint32,bool).selector) {
        uint32 destinationNetworkId;
        bool forceUpdateGlobalExitRoot;
        depositAndBridge(e, assets, receiver, destinationNetworkId, forceUpdateGlobalExitRoot);
    }
    else if (f.selector == sig:depositWithPermit(uint256,address,bytes).selector) {
        bytes permitData;
        depositWithPermit(e, assets, receiver, permitData);
    }
    else if (f.selector == sig:depositWithPermitAndBridge(uint256,address,uint32,bool,bytes).selector) {
        uint32 destinationNetworkId;
        bool forceUpdateGlobalExitRoot;
        bytes permitData;
        depositWithPermitAndBridge(e, assets, receiver, destinationNetworkId, forceUpdateGlobalExitRoot, permitData);
    }
    else if (f.selector == sig:mint(uint256,address).selector) {
        mint(e, shares, receiver);
    }
    else if (f.selector == sig:transferFrom(address,address,uint256).selector) {
        transferFrom(e, owner, receiver, shares);
    }
    else {
        calldataarg args;
        f(e, args);
    }
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
    f.selector == sig:renounceRole(bytes32,address).selector
;

definition excludedMethod(method f) returns bool =
    f.isView || f.isFallback ||
    //f.selector == sig:initialize(address,address,string,string,address,uint256,address,address,address,uint256,address,uint256).selector ||
    f.selector == sig:initialize(address, VaultBridgeToken.InitializationParameters).selector
    //f.selector == sig:initialize(address,string,string,address,uint256,address,address,address,address,uint256,address,uint256,address).selector
;

function totalSupplyMoreThanBalance(address user1) {
    require (
        ERC20a.totalSupply() >= ERC20a.balanceOf(user1)
    );
    require (
        GenericVaultBridgeToken.totalSupply() >= GenericVaultBridgeToken.balanceOf(user1)
    );
}

function totalSuppliesMoreThanBalances(address user1, address user2) {
    if (user1 == user2) 
    {
        totalSupplyMoreThanBalance(user1);
        return;
    }
    //require user1 != user2;
    require (
        ERC20a.totalSupply() >= require_uint256(ERC20a.balanceOf(user1) + ERC20a.balanceOf(user2))
    );
    require (
        GenericVaultBridgeToken.totalSupply() >= require_uint256(GenericVaultBridgeToken.balanceOf(user1) + GenericVaultBridgeToken.balanceOf(user2))
    );
}

function totalSuppliesMoreThanThreeBalances(address user1, address user2, address user3) {
    if (user1 == user2 || user2 == user3)
    {
        totalSuppliesMoreThanBalances(user1, user3);
        return;
    } 
    if (user1 == user3)
    {
        totalSuppliesMoreThanBalances(user2, user3);
        return;
    }    

    require (
        ERC20a.totalSupply() >= require_uint256(
            ERC20a.balanceOf(user1) + ERC20a.balanceOf(user2) + ERC20a.balanceOf(user3)
        )
    );
    require (
        GenericVaultBridgeToken.totalSupply() >= require_uint256(
            GenericVaultBridgeToken.balanceOf(user1) +
            GenericVaultBridgeToken.balanceOf(user2) +
            GenericVaultBridgeToken.balanceOf(user3)
        )
    );
}

function totalSuppliesMoreThanFourBalances(address user1, address user2, address user3, address user4) {
    if (user1 == user2 || user1 == user3 || user1 == user4)
    {
        totalSuppliesMoreThanThreeBalances(user2, user3, user4);
        return;
    } 
    if (user2 == user3 || user2 == user4)
    {
        totalSuppliesMoreThanThreeBalances(user1, user3, user4);
        return;
    } 
    if (user3 == user4)
    {
        totalSuppliesMoreThanThreeBalances(user1, user2, user4);
        return;
    } 

    require (
        ERC20a.totalSupply() >= require_uint256(
            ERC20a.balanceOf(user1) + ERC20a.balanceOf(user2) + ERC20a.balanceOf(user3) + ERC20a.balanceOf(user4)
        )
    );
    require (
        GenericVaultBridgeToken.totalSupply() >= require_uint256(
            GenericVaultBridgeToken.balanceOf(user1) +
            GenericVaultBridgeToken.balanceOf(user2) +
            GenericVaultBridgeToken.balanceOf(user3) +
            GenericVaultBridgeToken.balanceOf(user4)
        )
    );
}