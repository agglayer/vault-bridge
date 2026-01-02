// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test Base
import {
    NonDefaultMintBurnOftAdapterTestBase,
    TestHarnessNonDefaultMintBurnOftAdapter,
    TransparentUpgradeableProxy
} from "test/base/secondary-chain/NonDefaultMintBurnOftAdapterTestBase.sol";

// Core contracts
import {NonDefaultMintBurnOftAdapter} from "src/secondary-chain/layerzero/NonDefaultMintBurnOftAdapter.sol";
import {GenericCustomTokenLayerZero} from "src/secondary-chain/layerzero/GenericCustomTokenLayerZero.sol";
import {InitializationCounterUpgradeable} from "src/etc/InitializationCounterUpgradeable.sol";

// Mock contracts
import {MockFiatTokenLayerZero} from "test/utils/mocks/MockFiatTokenLayerZero.sol";

// OpenZeppelin
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @dev NonDefaultMintBurnOftAdapter tests
/// @notice Comprehensive tests for NonDefaultMintBurnOftAdapter covering all functionality and branches
contract NonDefaultMintBurnOftAdapterTest is NonDefaultMintBurnOftAdapterTestBase {
    function setUp() public virtual {
        deployNonDefaultMintBurnOftAdapterInfrastructure();
    }

    // ==========================================
    // ========== INITIALIZATION TESTS ==========
    // ==========================================

    function test_initialize_revert_zeroToken() public {
        vm.revertToState(stateBeforeInitialize);

        bytes[] memory reinitializeCallData = new bytes[](1);
        reinitializeCallData[0] =
            abi.encodeCall(NonDefaultMintBurnOftAdapter.reinitialize1, (address(0), false, owner, delegate));

        vm.expectRevert(abi.encodeWithSelector(NonDefaultMintBurnOftAdapter.InvalidToken.selector));
        nonDefaultMintBurnOftAdapterProxy = TransparentUpgradeableProxy(
            payable(
                _proxify(
                    nonDefaultMintBurnOftAdapterImpl,
                    proxyAdmin,
                    abi.encodeCall(NonDefaultMintBurnOftAdapter.reinitialize, (reinitializeCallData))
                )
            )
        );
    }

    function test_initialize_revert_invalidTokenDecimals() public {
        vm.revertToState(stateBeforeInitialize);

        // Create a token with different decimals using a mock bridge
        GenericCustomTokenLayerZero wrongDecimalToken = deployCustomTokenLz(
            "Wrong Token",
            "WRG",
            6, // Different decimals (6 instead of 18)
            address(mockAgglayerBridge)
        );

        bytes[] memory reinitializeCallData = new bytes[](1);
        reinitializeCallData[0] = abi.encodeCall(
            NonDefaultMintBurnOftAdapter.reinitialize1, (address(wrongDecimalToken), false, owner, delegate)
        );

        vm.expectRevert(abi.encodeWithSelector(NonDefaultMintBurnOftAdapter.InvalidTokenDecimals.selector));
        nonDefaultMintBurnOftAdapterProxy = TransparentUpgradeableProxy(
            payable(
                _proxify(
                    nonDefaultMintBurnOftAdapterImpl,
                    proxyAdmin,
                    abi.encodeCall(NonDefaultMintBurnOftAdapter.reinitialize, (reinitializeCallData))
                )
            )
        );
    }

    function test_initialize_revert_alreadyInitialized() public {
        bytes[] memory reinitializeCallData = new bytes[](1);
        reinitializeCallData[0] = abi.encodeCall(
            NonDefaultMintBurnOftAdapter.reinitialize1, (address(customTokenLayerZero), false, owner, delegate)
        );

        vm.expectRevert();
        nonDefaultMintBurnOftAdapter.reinitialize(reinitializeCallData);
    }

    function test_initialize_withApprovalRequired() public {
        vm.revertToState(stateBeforeInitialize);

        bytes[] memory reinitializeCallData = new bytes[](1);
        reinitializeCallData[0] = abi.encodeCall(
            NonDefaultMintBurnOftAdapter.reinitialize1, (address(customTokenLayerZero), true, owner, delegate)
        );

        NonDefaultMintBurnOftAdapter newAdapter = NonDefaultMintBurnOftAdapter(
            address(
                new TransparentUpgradeableProxy(
                    nonDefaultMintBurnOftAdapterImpl,
                    proxyAdmin,
                    abi.encodeCall(NonDefaultMintBurnOftAdapter.reinitialize, (reinitializeCallData))
                )
            )
        );

        assertTrue(newAdapter.approvalRequired());
    }

    // ========================================
    // ====== SET TOKEN AND APPROVAL TESTS ====
    // ========================================

    function test_setTokenAndApprovalRequired_revert_unauthorized() public {
        vm.prank(sender);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sender));
        nonDefaultMintBurnOftAdapter.setTokenAndApprovalRequired(address(customTokenLayerZero), true);
    }

    function test_setTokenAndApprovalRequired_revert_nonZeroSecondaryChainBalance() public {
        // Manually set secondaryChainBalance to a non-zero value by manipulating storage
        uint256 nonZeroBalance = 1000e18;
        bytes32 baseSlot = hex"9a6d185a7513716cb084495e8826e193b97e9aa66dc42826208b30227953df00";
        bytes32 secondaryChainBalanceSlot = bytes32(uint256(baseSlot) + 1); // Slot 1, not 2
        vm.store(address(nonDefaultMintBurnOftAdapter), secondaryChainBalanceSlot, bytes32(nonZeroBalance));

        // Verify the balance was set correctly
        assertEq(nonDefaultMintBurnOftAdapter.secondaryChainBalance(), nonZeroBalance);

        // Try to set token and approval required, should revert
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(NonDefaultMintBurnOftAdapter.CannotSetTokenIfSecondaryChainBalanceIsNotZero.selector)
        );
        nonDefaultMintBurnOftAdapter.setTokenAndApprovalRequired(address(customTokenLayerZero), true);
    }

    function test_setTokenAndApprovalRequired_revert_zeroToken() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(NonDefaultMintBurnOftAdapter.InvalidToken.selector));
        nonDefaultMintBurnOftAdapter.setTokenAndApprovalRequired(address(0), true);
    }

    function test_setTokenAndApprovalRequired_revert_invalidTokenDecimals() public {
        // Create token with wrong decimals
        address mockBridge = makeAddr("mockBridgeWrongDecimals");
        GenericCustomTokenLayerZero wrongToken = deployCustomTokenLz(
            "Wrong Token",
            "WRG",
            6, // Wrong decimals
            mockBridge
        );

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(NonDefaultMintBurnOftAdapter.InvalidTokenDecimals.selector));
        nonDefaultMintBurnOftAdapter.setTokenAndApprovalRequired(address(wrongToken), true);
    }

    function test_setTokenAndApprovalRequired_revert_nonZeroTotalSupply() public {
        // Deploy new token
        GenericCustomTokenLayerZero newToken = deployCustomTokenLz("New Token", "NEW", 18, address(this));

        // Mint some tokens to make total supply non-zero
        newToken.mint(sender, 1000e18);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(NonDefaultMintBurnOftAdapter.CannotSetTokenIfItsTotalSupplyIsNotZero.selector)
        );
        nonDefaultMintBurnOftAdapter.setTokenAndApprovalRequired(address(newToken), true);
    }

    function test_setTokenAndApprovalRequired_success() public {
        // Deploy new token with zero supply
        GenericCustomTokenLayerZero newToken =
            deployCustomTokenLz("New Token", "NEW", 18, address(nonDefaultMintBurnOftAdapter));

        // Ensure secondary chain balance is zero
        assertEq(nonDefaultMintBurnOftAdapter.secondaryChainBalance(), 0);

        vm.prank(owner);
        nonDefaultMintBurnOftAdapter.setTokenAndApprovalRequired(address(newToken), true);

        assertEq(nonDefaultMintBurnOftAdapter.token(), address(newToken));
        assertTrue(nonDefaultMintBurnOftAdapter.approvalRequired());
    }

    // ========================================
    // ====== INTERNAL FUNCTION TESTS =========
    // ========================================

    // ===== _debit tests =====

    function test_debit_success_withApprovalRequired() public {
        vm.revertToState(stateBeforeInitialize);

        // Calculate the adapter address (after deploying the token's proxy and proxy admin)
        address calculatedAdapterAddr = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 2);

        // Deploy MockFiatTokenLayerZero using the helper function
        MockFiatTokenLayerZero fiatToken =
            deployMockFiatTokenLayerZero("Fiat Token LayerZero", "FTLZ", 18, calculatedAdapterAddr);

        // Initialize adapter with approvalRequired=true
        bytes[] memory reinitializeCallData = new bytes[](1);
        reinitializeCallData[0] =
            abi.encodeCall(NonDefaultMintBurnOftAdapter.reinitialize1, (address(fiatToken), true, owner, delegate));

        TestHarnessNonDefaultMintBurnOftAdapter newAdapter = TestHarnessNonDefaultMintBurnOftAdapter(
            address(
                new TransparentUpgradeableProxy(
                    nonDefaultMintBurnOftAdapterImpl,
                    proxyAdmin,
                    abi.encodeCall(NonDefaultMintBurnOftAdapter.reinitialize, (reinitializeCallData))
                )
            )
        );
        // Verify approvalRequired is set correctly
        assertTrue(newAdapter.approvalRequired());

        // Setup: Credit tokens to sender first (simulates receiving from another chain)
        uint256 mintAmount = 1000e18;
        newAdapter.exposed_credit(sender, mintAmount, 1);

        // Verify setup
        assertEq(fiatToken.balanceOf(sender), mintAmount);
        assertEq(newAdapter.secondaryChainBalance(), mintAmount);

        uint256 debitAmount = 500e18;
        uint32 dstEid = 1;

        // Sender approves adapter to burn tokens
        vm.prank(sender);
        fiatToken.approve(address(newAdapter), debitAmount);

        vm.prank(sender);
        (uint256 amountSentLD, uint256 amountReceivedLD) =
            newAdapter.exposed_debit(sender, debitAmount, debitAmount, dstEid);
        assertEq(amountSentLD, debitAmount);
        assertEq(amountReceivedLD, debitAmount);
        assertEq(fiatToken.balanceOf(sender), mintAmount - debitAmount);
        assertEq(newAdapter.secondaryChainBalance(), mintAmount - debitAmount);
    }

    function test_debit_success_withoutApprovalRequired() public {
        // Setup: Credit tokens to sender first (simulates receiving from another chain)
        uint256 mintAmount = 1000e18;
        nonDefaultMintBurnOftAdapter.exposed_credit(sender, mintAmount, 1);

        // Verify setup
        assertEq(customTokenLayerZero.balanceOf(sender), mintAmount);
        assertEq(nonDefaultMintBurnOftAdapter.secondaryChainBalance(), mintAmount);

        uint256 debitAmount = 500e18;
        uint32 dstEid = 1;

        vm.prank(sender);
        (uint256 amountSentLD, uint256 amountReceivedLD) =
            nonDefaultMintBurnOftAdapter.exposed_debit(sender, debitAmount, debitAmount, dstEid);

        assertEq(amountSentLD, debitAmount);
        assertEq(amountReceivedLD, debitAmount);
        assertEq(customTokenLayerZero.balanceOf(sender), mintAmount - debitAmount);
        assertEq(nonDefaultMintBurnOftAdapter.secondaryChainBalance(), mintAmount - debitAmount);
    }

    function testFuzz_debit_anyAmount(uint256 debitAmount) public {
        // Bound the amount to reasonable values that are divisible by 10^12 (conversion rate)
        // This avoids SlippageExceeded errors from decimal conversion
        debitAmount = bound(debitAmount, 1e12, 1e27); // 0.000001 to 1 billion tokens
        debitAmount = (debitAmount / 1e12) * 1e12; // Round down to nearest 10^12

        // Setup: Credit tokens to sender first (simulates receiving from another chain)
        nonDefaultMintBurnOftAdapter.exposed_credit(sender, debitAmount, 1);

        // Verify setup
        assertEq(customTokenLayerZero.balanceOf(sender), debitAmount);
        assertEq(nonDefaultMintBurnOftAdapter.secondaryChainBalance(), debitAmount);

        uint32 dstEid = 1;

        vm.prank(sender);
        (uint256 amountSentLD, uint256 amountReceivedLD) =
            nonDefaultMintBurnOftAdapter.exposed_debit(sender, debitAmount, debitAmount, dstEid);

        assertEq(amountSentLD, debitAmount);
        assertEq(amountReceivedLD, debitAmount);
        assertEq(customTokenLayerZero.balanceOf(sender), 0);
        assertEq(nonDefaultMintBurnOftAdapter.secondaryChainBalance(), 0);
    }

    // ===== _credit tests =====

    function test_credit_revert_addressZero() public {
        uint256 creditAmount = 1000e18;
        vm.expectRevert(NonDefaultMintBurnOftAdapter.CannotCreditAddressZero.selector);
        nonDefaultMintBurnOftAdapter.exposed_credit(address(0), creditAmount, 0);
    }

    function test_credit_success() public {
        uint256 creditAmount = 1000e18;

        uint256 initialBalance = nonDefaultMintBurnOftAdapter.secondaryChainBalance();

        uint256 amountReceivedLD = nonDefaultMintBurnOftAdapter.exposed_credit(recipient, creditAmount, 0);

        assertEq(amountReceivedLD, creditAmount);
        assertEq(customTokenLayerZero.balanceOf(recipient), creditAmount);
        assertEq(nonDefaultMintBurnOftAdapter.secondaryChainBalance(), initialBalance + creditAmount);
    }

    function testFuzz_credit_anyAmount(uint256 creditAmount) public {
        // Bound the amount to reasonable values
        creditAmount = bound(creditAmount, 1, 1e27); // 1 to 1 billion tokens (with 18 decimals)

        uint256 initialBalance = nonDefaultMintBurnOftAdapter.secondaryChainBalance();

        uint256 amountReceivedLD = nonDefaultMintBurnOftAdapter.exposed_credit(recipient, creditAmount, 0);

        assertEq(amountReceivedLD, creditAmount);
        assertEq(customTokenLayerZero.balanceOf(recipient), creditAmount);
        assertEq(nonDefaultMintBurnOftAdapter.secondaryChainBalance(), initialBalance + creditAmount);
    }

    // ===== _receiveToken tests =====

    function test_receiveToken_revert_insufficientReceived() public {
        uint256 transferAmount = 1000e18;

        // Mint tokens to sender via the adapter
        vm.prank(address(nonDefaultMintBurnOftAdapter));
        customTokenLayerZero.mint(sender, transferAmount);

        // Sender approves adapter
        vm.prank(sender);
        customTokenLayerZero.approve(address(nonDefaultMintBurnOftAdapter), transferAmount);

        // Mock transferFrom to return true WITHOUT actually transferring tokens
        // This simulates a fee-on-transfer (100% fee) token where the call succeeds but less arrives
        vm.mockCall(
            address(customTokenLayerZero),
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)", sender, address(nonDefaultMintBurnOftAdapter), transferAmount
            ),
            abi.encode(true)
        );

        // The exact received amount doesn't matter for this test - we just need to verify
        // that the function reverts when less than the requested amount is received
        vm.expectRevert(
            abi.encodeWithSelector(NonDefaultMintBurnOftAdapter.InsufficientTokenReceived.selector, 0, transferAmount)
        );

        nonDefaultMintBurnOftAdapter.exposed_receiveToken(sender, transferAmount);

        // Clean up
        vm.clearMockedCalls();
    }

    function test_receiveToken_success() public {
        uint256 transferAmount = 1000e18;

        // Mint tokens to sender via the adapter
        vm.prank(address(nonDefaultMintBurnOftAdapter));
        customTokenLayerZero.mint(sender, transferAmount);

        // Sender approves adapter
        vm.prank(sender);
        customTokenLayerZero.approve(address(nonDefaultMintBurnOftAdapter), transferAmount);

        uint256 adapterBalanceBefore = customTokenLayerZero.balanceOf(address(nonDefaultMintBurnOftAdapter));
        uint256 senderBalanceBefore = customTokenLayerZero.balanceOf(sender);

        nonDefaultMintBurnOftAdapter.exposed_receiveToken(sender, transferAmount);

        assertEq(
            customTokenLayerZero.balanceOf(address(nonDefaultMintBurnOftAdapter)), adapterBalanceBefore + transferAmount
        );
        assertEq(customTokenLayerZero.balanceOf(sender), senderBalanceBefore - transferAmount);
    }

    function testFuzz_receiveToken_anyAmount(uint256 transferAmount) public {
        // Bound the amount to reasonable values
        transferAmount = bound(transferAmount, 1, 1e27); // 1 to 1 billion tokens (with 18 decimals)

        // Mint tokens to sender via the adapter
        vm.prank(address(nonDefaultMintBurnOftAdapter));
        customTokenLayerZero.mint(sender, transferAmount);

        // Sender approves adapter
        vm.prank(sender);
        customTokenLayerZero.approve(address(nonDefaultMintBurnOftAdapter), transferAmount);

        uint256 adapterBalanceBefore = customTokenLayerZero.balanceOf(address(nonDefaultMintBurnOftAdapter));

        nonDefaultMintBurnOftAdapter.exposed_receiveToken(sender, transferAmount);

        assertEq(
            customTokenLayerZero.balanceOf(address(nonDefaultMintBurnOftAdapter)), adapterBalanceBefore + transferAmount
        );
    }
}
