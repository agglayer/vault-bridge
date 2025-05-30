import "MathSummaries.spec";
import "GenericVaultBridgeToken_methods.spec";

//using DummyERC20B as ERC20b; 
using VaultMock as yieldVaultContract;

function userAssets(address a) returns uint256
{
    return ERC20a.balanceOf(a);
}

function requireLinking() 
{
    // TODO no longer needed since the storage harness works again. Get rid of this method
    //require yieldVault() == yieldVaultContract;
    //require VaultBridgeTokenPart2.yieldVault() == yieldVaultContract;
}

// A helper function to set the receiver 
function callReceiverFunctions(method f, env e, address receiver) {
    uint256 amount;
    if (f.selector == sig:deposit(uint256,address).selector) {
        deposit(e, amount, receiver);
    } else if (f.selector == sig:mint(uint256,address).selector) {
        mint(e, amount, receiver);
    } else if (f.selector == sig:withdraw(uint256,address,address).selector) {
        address owner;
        withdraw(e, amount, receiver, owner);
    } else if (f.selector == sig:redeem(uint256,address,address).selector) {
        address owner;
        redeem(e, amount, receiver, owner);
    } else {
        calldataarg args;
        f(e, args);
    }
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

function callFunctionsWithReceiverAndOwner(env e, method f, uint256 assets, uint256 shares, address receiver, address owner) {
    if (f.selector == sig:withdraw(uint256,address,address).selector) {
        withdraw(e, assets, receiver, owner);
    }
    if (f.selector == sig:redeem(uint256,address,address).selector) {
        redeem(e, shares, receiver, owner);
    } 
    if (f.selector == sig:deposit(uint256,address).selector) {
        deposit(e, assets, receiver);
    }
    if (f.selector == sig:mint(uint256,address).selector) {
        mint(e, shares, receiver);
    }
     if (f.selector == sig:transferFrom(address,address,uint256).selector) {
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
    // || f.selector == sig:__VaultBridgeToken_init(address, VaultBridgeToken.InitializationParameters).selector
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