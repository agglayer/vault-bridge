// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test base
import "test/base/primary-chain/VaultBridgeTokenTestBase.sol";

// OpenZeppelin
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Core contracts
import {VaultBridgeToken} from "src/primary-chain/VaultBridgeToken.sol";

contract VaultBridgeTokenHarness is TestHarnessVaultBridgeToken {
    function internal_withdrawFromYieldVault(
        uint256 assets,
        bool exact,
        address receiver,
        uint256 originalTotalSupply,
        uint256 originalUncollectedYield,
        uint256 originalReservedAssets
    ) public returns (uint256 nonWithdrawnAssets, uint256 receivedAssets) {
        (nonWithdrawnAssets, receivedAssets) = _withdrawFromYieldVault(
            assets, exact, receiver, originalTotalSupply, originalUncollectedYield, originalReservedAssets
        );
    }

    function internal_depositIntoYieldVault(uint256 assets, bool exact) public returns (uint256 nonDepositedAssets) {
        nonDepositedAssets = _depositIntoYieldVault(assets, exact);
    }
}

contract GenericVaultBridgeTokenFuzzTest is VaultBridgeTokenTestBase {
    using SafeERC20 for IERC20;
    using SafeERC20 for VaultBridgeTokenHarness;

    // Override the vbToken with our harness version for internal function testing
    VaultBridgeTokenHarness internal vbTokenHarness;

    function setUp() public virtual {
        deployVaultBridgeTokenInfrastructure();

        // Deploy harness version for testing internal functions
        address harnessImplementation = address(new VaultBridgeTokenHarness());

        VaultBridgeToken.InitializationParameters memory initParams = VaultBridgeToken.InitializationParameters({
            owner: owner,
            name: tokenName,
            symbol: tokenSymbol,
            underlyingToken: underlyingToken,
            minimumReservePercentage: minimumReservePercentage,
            yieldVault: address(yieldVault),
            yieldRecipient: yieldRecipient,
            agglayerBridge: agglayerBridge,
            minimumYieldVaultDeposit: MINIMUM_YIELD_VAULT_DEPOSIT,
            migrationManager: migrationManagerAddr,
            yieldVaultMaximumSlippagePercentage: YIELD_VAULT_ALLOWED_SLIPPAGE,
            vaultBridgeTokenPart2: address(vbTokenPart2Implementation)
        });

        bytes[] memory reinitializeCallData = new bytes[](2);
        reinitializeCallData[0] = abi.encodeCall(
            VaultBridgeTokenHarness(harnessImplementation).reinitialize1, (address(initializer), initParams)
        );
        reinitializeCallData[1] = abi.encodeCall(VaultBridgeTokenHarness(harnessImplementation).reinitialize2, ());

        bytes memory vaultBridgeTokenInitData =
            abi.encodeCall(VaultBridgeTokenHarness(harnessImplementation).reinitialize, (reinitializeCallData));

        address harnessProxy = _proxify(harnessImplementation, address(this), vaultBridgeTokenInitData);
        vbTokenHarness = VaultBridgeTokenHarness(payable(harnessProxy));

        vm.label(address(vbTokenHarness), "VaultBridgeToken Harness");
    }

    function testFuzz_depositIntoYieldVault_minimumDepositNotMet_revert(uint256 assets) public {
        assets = bound(assets, 1, MINIMUM_YIELD_VAULT_DEPOSIT - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                VaultBridgeToken.MinimumYieldVaultDepositNotMet.selector, assets, MINIMUM_YIELD_VAULT_DEPOSIT
            )
        );
        vbTokenHarness.internal_depositIntoYieldVault(assets, true);
    }

    function testFuzz_depositIntoYieldVault_minimumDepositNotMet_nonExact(uint256 assets) public {
        assets = bound(assets, 1, MINIMUM_YIELD_VAULT_DEPOSIT - 1);

        uint256 nonDepositedAssets = vbTokenHarness.internal_depositIntoYieldVault(assets, false);
        assertEq(nonDepositedAssets, assets);
    }

    function testFuzz_depositIntoYieldVault_exceedsMaxDeposit_revert(uint256 assets) public {
        assets = bound(assets, MAX_DEPOSIT + 1, type(uint128).max);

        vm.expectRevert(abi.encodeWithSelector(VaultBridgeToken.YieldVaultDepositFailed.selector, assets, MAX_DEPOSIT));
        vbTokenHarness.internal_depositIntoYieldVault(assets, true);
    }

    function testFuzz_depositIntoYieldVault_exceedsMaxDeposit_nonExact(uint256 assets) public {
        assets = bound(assets, MAX_DEPOSIT + 1, type(uint128).max);

        // Provide the contract with enough tokens to handle the deposit
        deal(underlyingToken, address(vbTokenHarness), MAX_DEPOSIT);

        uint256 nonDepositedAssets = vbTokenHarness.internal_depositIntoYieldVault(assets, false);
        assertEq(nonDepositedAssets, assets - MAX_DEPOSIT);
    }

    function testFuzz_depositIntoYieldVault_slippageFailure_revert(uint256 assets, uint256 slippageAmount) public {
        assets = bound(assets, MINIMUM_YIELD_VAULT_DEPOSIT, MAX_DEPOSIT);

        // Calculate minimum expected shares for 1% slippage tolerance
        uint256 minimumExpectedShares = Math.mulDiv(assets, 1e18 - YIELD_VAULT_ALLOWED_SLIPPAGE, 1e18);

        // Bound slippage to be large enough to cause solvency failure
        // The actual shares after slippage will be (assets - slippageAmount)
        // We need this to be less than minimumExpectedShares
        uint256 maxAllowedSlippage = assets - minimumExpectedShares;
        slippageAmount = bound(slippageAmount, maxAllowedSlippage + 1, assets - 1);

        // Setup vault to have slippage that exceeds the allowed threshold
        deal(underlyingToken, address(vbTokenHarness), assets);
        yieldVault.setSlippage(true, slippageAmount);

        // Calculate the actual shares minted after slippage
        uint256 actualMintedShares = assets - slippageAmount;

        vm.expectRevert(
            abi.encodeWithSelector(
                VaultBridgeToken.InsufficientYieldVaultSharesMinted.selector, assets, actualMintedShares
            )
        );
        vbTokenHarness.internal_depositIntoYieldVault(assets, true);
    }

    function testFuzz_depositIntoYieldVault_slippageFailure_nonExact(uint256 assets, uint256 slippageAmount) public {
        assets = bound(assets, MINIMUM_YIELD_VAULT_DEPOSIT, MAX_DEPOSIT);

        // Calculate minimum expected shares for 1% slippage tolerance
        uint256 minimumExpectedShares = Math.mulDiv(assets, 1e18 - YIELD_VAULT_ALLOWED_SLIPPAGE, 1e18);

        // Bound slippage to be large enough to cause solvency failure
        // The actual shares after slippage will be (assets - slippageAmount)
        // We need this to be less than minimumExpectedShares
        uint256 maxAllowedSlippage = assets - minimumExpectedShares;
        slippageAmount = bound(slippageAmount, maxAllowedSlippage + 1, assets - 1);

        // Setup vault to have slippage that exceeds the allowed threshold
        deal(underlyingToken, address(vbTokenHarness), assets);
        yieldVault.setSlippage(true, slippageAmount);

        uint256 nonDepositedAssets = vbTokenHarness.internal_depositIntoYieldVault(assets, false);
        assertEq(nonDepositedAssets, assets);
    }

    function testFuzz_depositIntoYieldVault_success(uint256 assets, uint256 slippageAmount) public {
        assets = bound(assets, MINIMUM_YIELD_VAULT_DEPOSIT, MAX_DEPOSIT);

        // Calculate minimum expected shares for 1% slippage tolerance
        uint256 minimumExpectedShares = Math.mulDiv(assets, 1e18 - YIELD_VAULT_ALLOWED_SLIPPAGE, 1e18);

        // Bound slippage to be within allowed threshold
        // The actual shares after slippage will be (assets - slippageAmount)
        // We need this to be >= minimumExpectedShares
        uint256 maxAllowedSlippage = assets - minimumExpectedShares;
        slippageAmount = bound(slippageAmount, 0, maxAllowedSlippage);

        // Calculate expected minted shares after slippage
        uint256 expectedMintedShares = assets - slippageAmount;

        // Setup vault with acceptable slippage
        deal(underlyingToken, address(vbTokenHarness), assets);
        yieldVault.setSlippage(true, slippageAmount);

        uint256 nonDepositedAssets = vbTokenHarness.internal_depositIntoYieldVault(assets, false);
        assertEq(nonDepositedAssets, 0);
        assertEq(yieldVault.balanceOf(address(vbTokenHarness)), expectedMintedShares);
    }

    function testFuzz_depositIntoYieldVault_successNoSlippage(uint256 assets) public {
        assets = bound(assets, MINIMUM_YIELD_VAULT_DEPOSIT, MAX_DEPOSIT);

        // Setup vault without slippage
        deal(underlyingToken, address(vbTokenHarness), assets);
        yieldVault.setSlippage(false, 0);

        uint256 nonDepositedAssets = vbTokenHarness.internal_depositIntoYieldVault(assets, true);
        assertEq(nonDepositedAssets, 0);
        assertEq(yieldVault.balanceOf(address(vbTokenHarness)), assets);
    }

    function testFuzz_withdrawFromYieldVault_revert(uint256 assets, uint256 originalTotalSupply, uint256 slippageAmount)
        public
    {
        vm.assume(assets <= MAX_WITHDRAW);
        vm.assume(originalTotalSupply >= assets);
        vm.assume(slippageAmount > Math.mulDiv(assets, 0.01e18, 1e18) && slippageAmount < assets);

        deal(underlyingToken, address(yieldVault), assets);
        yieldVault.setBalance(address(vbTokenHarness), assets);
        yieldVault.setSlippage(true, slippageAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                VaultBridgeToken.ExcessiveYieldVaultSharesBurned.selector, assets + slippageAmount, assets
            )
        );
        vbTokenHarness.internal_withdrawFromYieldVault(
            assets, false, sender, originalTotalSupply, 0, originalTotalSupply - assets
        );
    }

    function testFuzz_withdrawFromYieldVault(uint256 assets, uint256 originalTotalSupply, uint256 slippageAmount)
        public
    {
        vm.assume(assets <= MAX_WITHDRAW);
        vm.assume(originalTotalSupply >= assets);
        vm.assume(slippageAmount <= Math.mulDiv(assets, 0.01e18, 1e18) && slippageAmount < assets);

        deal(underlyingToken, address(yieldVault), assets);
        yieldVault.setBalance(address(vbTokenHarness), assets);
        yieldVault.setSlippage(true, slippageAmount);

        vbTokenHarness.internal_withdrawFromYieldVault(
            assets, false, sender, originalTotalSupply, 0, originalTotalSupply - assets
        );
        assertEq(IERC20(underlyingToken).balanceOf(sender), assets);
    }

    function testFuzz_setMinimumReservePercentage(uint256 percentage) public {
        vm.assume(percentage <= 1e18);
        vm.prank(owner);
        vbTokenPart2.setMinimumReservePercentage(percentage);
        assertEq(vbToken.minimumReservePercentage(), percentage);
    }
}
