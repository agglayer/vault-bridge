import "bridgeSummary.spec";
import "GenericVaultBridgeToken_helpers.spec";

methods {
    function GenericVaultBridgeToken.balanceOf(address) external returns (uint256) envfree;
    function GenericVaultBridgeToken.totalSupply() external returns (uint256) envfree;
    function GenericVaultBridgeToken.transfer(address,uint256) external returns (bool);
}

// Partial sum of balances.
//  sumOfBalancesGVBT[x] = \sum_{i=0}^{x-1} balances[i];
ghost mapping(mathint => mathint) sumOfBalancesGVBT {
    init_state axiom forall mathint addr. sumOfBalancesGVBT[addr] == 0;
}

// ghost copy of balances
ghost mapping(address => uint256) ghost_balancesGVBT {
    init_state axiom forall address addr. ghost_balancesGVBT[addr] == 0;
}

hook Sload uint256 _balance (slot 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00).(offset 0)[KEY address account].(offset 0) {
    require ghost_balancesGVBT[account] == _balance;
}

hook Sstore (slot 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00).(offset 0)[KEY address account].(offset 0) uint256 _balance (uint256 _balance_old) {
    // update partial sums for x > to_mathint(account)
    havoc sumOfBalancesGVBT assuming
        forall mathint x. sumOfBalancesGVBT@new[x] ==
            sumOfBalancesGVBT@old[x] + (to_mathint(account) < x ? _balance - _balance_old : 0);
    ghost_balancesGVBT[account] = _balance;
}

// rules and invariant all hold

invariant sumOfBalancesGVBTStartsAtZero()
    sumOfBalancesGVBT[0] == 0
    filtered { f -> !excludedMethod(f) }
    {
    preserved {
        requireLinking();
    }
}


invariant sumOfBalancesGVBTGrowsCorrectly()
    forall address addr. sumOfBalancesGVBT[to_mathint(addr) + 1] ==
        sumOfBalancesGVBT[to_mathint(addr)] + ghost_balancesGVBT[addr]
    filtered { f -> !excludedMethod(f) }
    {
    preserved {
        requireLinking();
    }
}

invariant sumOfBalancesGVBTMonotone()
    forall mathint i. forall mathint j. i <= j => sumOfBalancesGVBT[i] <= sumOfBalancesGVBT[j]
    filtered { f -> !excludedMethod(f) }
    {
        preserved {
            requireLinking();
            requireInvariant sumOfBalancesGVBTStartsAtZero();
            requireInvariant sumOfBalancesGVBTGrowsCorrectly();
        }
    }

invariant sumOfBalancesGVBTEqualsTotalSupply()
    sumOfBalancesGVBT[2^160] == to_mathint(GenericVaultBridgeToken.totalSupply())
    filtered { f -> !excludedMethod(f) }
    {
        preserved {
            requireLinking();
            requireInvariant sumOfBalancesGVBTStartsAtZero();
            requireInvariant sumOfBalancesGVBTGrowsCorrectly();
            requireInvariant sumOfBalancesGVBTMonotone();
        }
    }

rule twoBalancesCannotExceedTotalSupply(address accountA, address accountB) {
    requireLinking();
    requireInvariant sumOfBalancesGVBTStartsAtZero();
    requireInvariant sumOfBalancesGVBTGrowsCorrectly();
    requireInvariant sumOfBalancesGVBTMonotone();
    requireInvariant sumOfBalancesGVBTEqualsTotalSupply();
    uint256 balanceA = GenericVaultBridgeToken.balanceOf(accountA);
    uint256 balanceB = GenericVaultBridgeToken.balanceOf(accountB);

    assert accountA != accountB =>
        balanceA + balanceB <= to_mathint(GenericVaultBridgeToken.totalSupply());
    satisfy(accountA != accountB && balanceA > 0 && balanceB > 0);
}


rule threeBalancesCannotExceedTotalSupply(address accountA, address accountB, address accountC) {
    requireLinking();
    requireInvariant sumOfBalancesGVBTStartsAtZero();
    requireInvariant sumOfBalancesGVBTGrowsCorrectly();
    requireInvariant sumOfBalancesGVBTMonotone();
    requireInvariant sumOfBalancesGVBTEqualsTotalSupply();
    uint256 balanceA = GenericVaultBridgeToken.balanceOf(accountA);
    uint256 balanceB = GenericVaultBridgeToken.balanceOf(accountB);
    uint256 balanceC = GenericVaultBridgeToken.balanceOf(accountC);

    assert accountA != accountB && accountA != accountC && accountB != accountC =>
        balanceA + balanceB + balanceC <= to_mathint(GenericVaultBridgeToken.totalSupply());
    satisfy(accountA != accountB && balanceA + balanceB + balanceC > to_mathint(GenericVaultBridgeToken.totalSupply()));
}
