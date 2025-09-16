// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity 0.8.29;

// Test base
import "test/base/InitializationCounterTestBase.sol";

// Core contract
import {InitializationCounterUpgradeable} from "src/etc/InitializationCounterUpgradeable.sol";

/// @dev Tests for InitializationCounterUpgradeable
contract InitializationCounterUpgradeableTest is InitializationCounterTestBase {
    function setUp() public virtual {
        deployInitializationCounterInfrastructure();
    }

    // ========= INITIAL STATE TESTS =========

    function test_initialState() public view {
        assertCounterValues(INITIAL_COUNTER_VALUE, INITIAL_COUNTER_VALUE, INITIAL_COUNTER_VALUE);
    }

    function test_globalInitializationCounter_view() public view {
        assertEq(initCounter.globalInitializationCounter(), INITIAL_COUNTER_VALUE);
    }

    function test_storageSlot_correct() public view {
        // Verify the storage slot matches the expected ERC-7201 calculation
        bytes32 expectedSlot = keccak256(
            abi.encode(uint256(keccak256("agglayer.vault-bridge.InitializationCounterUpgradeable.storage")) - 1)
        ) & ~bytes32(uint256(0xff));

        assertEq(initCounter.getStorageSlot(), expectedSlot);
    }

    // ========= LOCAL INITIALIZATION COUNTER TESTS =========

    function test_incrementLocalInitializationCounter_success() public {
        // First increment: 0 -> 1
        incrementLocalCounterSuccessfully(FIRST_INCREMENT);
        assertCounterValues(INITIAL_COUNTER_VALUE, FIRST_INCREMENT, INITIAL_COUNTER_VALUE);

        // Second increment: 1 -> 2
        incrementLocalCounterSuccessfully(SECOND_INCREMENT);
        assertCounterValues(INITIAL_COUNTER_VALUE, SECOND_INCREMENT, INITIAL_COUNTER_VALUE);

        // Third increment: 2 -> 3
        incrementLocalCounterSuccessfully(THIRD_INCREMENT);
        assertCounterValues(INITIAL_COUNTER_VALUE, THIRD_INCREMENT, INITIAL_COUNTER_VALUE);
    }

    function test_incrementLocalInitializationCounter_wrongExpectedValue_reverts() public {
        // Try to increment from 0 to 2 (should expect 1)
        expectLocalCounterIncrementFailure(SECOND_INCREMENT);

        // Counter should remain unchanged
        assertCounterValues(INITIAL_COUNTER_VALUE, INITIAL_COUNTER_VALUE, INITIAL_COUNTER_VALUE);
    }

    function test_incrementLocalInitializationCounter_modifier_works() public {
        // Verify the modifier correctly increments the counter
        initCounter.incrementLocalInitializationCounterWithModifier(FIRST_INCREMENT);

        // Verify state changed
        assertEq(initCounter.localInitializationCounter(), FIRST_INCREMENT);
    }

    // ========= GLOBAL INITIALIZATION COUNTER TESTS =========

    function test_incrementGlobalInitializationCounter_success() public {
        // First increment: 0 -> 1
        incrementGlobalCounterSuccessfully(FIRST_INCREMENT);
        assertCounterValues(FIRST_INCREMENT, INITIAL_COUNTER_VALUE, INITIAL_COUNTER_VALUE);

        // Second increment: 1 -> 2
        incrementGlobalCounterSuccessfully(SECOND_INCREMENT);
        assertCounterValues(SECOND_INCREMENT, INITIAL_COUNTER_VALUE, INITIAL_COUNTER_VALUE);

        // Third increment: 2 -> 3
        incrementGlobalCounterSuccessfully(THIRD_INCREMENT);
        assertCounterValues(THIRD_INCREMENT, INITIAL_COUNTER_VALUE, INITIAL_COUNTER_VALUE);
    }

    function test_incrementGlobalInitializationCounter_wrongExpectedValue_reverts() public {
        // Try to increment from 0 to 2 (should expect 1)
        expectGlobalCounterIncrementFailure(SECOND_INCREMENT);

        // Counter should remain unchanged
        assertCounterValues(INITIAL_COUNTER_VALUE, INITIAL_COUNTER_VALUE, INITIAL_COUNTER_VALUE);
    }

    function test_incrementGlobalInitializationCounter_returnsCorrectValue() public {
        uint64 returnedValue = initCounter.incrementGlobalInitializationCounter(FIRST_INCREMENT);
        assertEq(returnedValue, FIRST_INCREMENT);
    }

    function test_incrementGlobalInitializationCounter_errorMessage_correct() public {
        uint64 wrongValue = 5;
        uint64 expectedCorrectValue = FIRST_INCREMENT;

        vm.expectRevert(
            abi.encodeWithSelector(
                InitializationCounterUpgradeable.IncorrectInitializationOrder.selector, wrongValue, expectedCorrectValue
            )
        );

        initCounter.incrementGlobalInitializationCounter(wrongValue);
    }

    // ========= EXTENSION INITIALIZATION COUNTER TESTS =========

    function test_incrementExtensionInitializationCounter_success() public {
        // First, increment local counter to meet requirements
        incrementLocalCounterSuccessfully(FIRST_INCREMENT);

        // Now increment extension counter: 0 -> 1
        incrementExtensionCounterSuccessfully(FIRST_INCREMENT, FIRST_INCREMENT);
        assertCounterValues(INITIAL_COUNTER_VALUE, FIRST_INCREMENT, FIRST_INCREMENT);

        // Increment local again
        incrementLocalCounterSuccessfully(SECOND_INCREMENT);

        // Increment extension counter again: 1 -> 2
        incrementExtensionCounterSuccessfully(SECOND_INCREMENT, SECOND_INCREMENT);
        assertCounterValues(INITIAL_COUNTER_VALUE, SECOND_INCREMENT, SECOND_INCREMENT);
    }

    function test_incrementExtensionInitializationCounter_wrongLocalRequirement_reverts() public {
        // Try to increment extension without meeting local counter requirement
        expectExtensionCounterIncrementFailure(FIRST_INCREMENT, FIRST_INCREMENT);

        // Counter should remain unchanged
        assertCounterValues(INITIAL_COUNTER_VALUE, INITIAL_COUNTER_VALUE, INITIAL_COUNTER_VALUE);
    }

    function test_incrementExtensionInitializationCounter_wrongExpectedValue_reverts() public {
        // Set up local counter properly
        incrementLocalCounterSuccessfully(FIRST_INCREMENT);

        // Try to increment extension with wrong expected value
        expectExtensionCounterIncrementFailureWithWrongExtension(FIRST_INCREMENT, SECOND_INCREMENT);

        // Counters should remain unchanged (except local which was incremented above)
        assertCounterValues(INITIAL_COUNTER_VALUE, FIRST_INCREMENT, INITIAL_COUNTER_VALUE);
    }

    function test_incrementExtensionInitializationCounter_modifier_works() public {
        // Set up prerequisites
        incrementLocalCounterSuccessfully(FIRST_INCREMENT);

        // Test the modifier
        initCounter.incrementExtensionInitializationCounterWithModifier(FIRST_INCREMENT, FIRST_INCREMENT);

        // Verify state changed
        assertEq(initCounter.extensionInitializationCounter(), FIRST_INCREMENT);
    }

    // ========= INTEGRATION TESTS =========

    function test_multipleCounterTypes_independent() public {
        // Increment all three types independently
        incrementLocalCounterSuccessfully(FIRST_INCREMENT);
        incrementGlobalCounterSuccessfully(FIRST_INCREMENT);
        incrementExtensionCounterSuccessfully(FIRST_INCREMENT, FIRST_INCREMENT);

        // Verify all are at expected values
        assertCounterValues(FIRST_INCREMENT, FIRST_INCREMENT, FIRST_INCREMENT);

        // Increment local and extension again
        incrementLocalCounterSuccessfully(SECOND_INCREMENT);
        incrementExtensionCounterSuccessfully(SECOND_INCREMENT, SECOND_INCREMENT);

        // Global should remain unchanged, others incremented
        assertCounterValues(FIRST_INCREMENT, SECOND_INCREMENT, SECOND_INCREMENT);
    }

    function test_sequentialOperations() public {
        // Complex sequence testing various combinations
        incrementLocalCounterSuccessfully(FIRST_INCREMENT);
        incrementGlobalCounterSuccessfully(FIRST_INCREMENT);
        incrementExtensionCounterSuccessfully(FIRST_INCREMENT, FIRST_INCREMENT);

        incrementLocalCounterSuccessfully(SECOND_INCREMENT);
        incrementGlobalCounterSuccessfully(SECOND_INCREMENT);
        incrementExtensionCounterSuccessfully(SECOND_INCREMENT, SECOND_INCREMENT);

        incrementLocalCounterSuccessfully(THIRD_INCREMENT);
        incrementGlobalCounterSuccessfully(THIRD_INCREMENT);
        incrementExtensionCounterSuccessfully(THIRD_INCREMENT, THIRD_INCREMENT);

        assertCounterValues(THIRD_INCREMENT, THIRD_INCREMENT, THIRD_INCREMENT);
    }

    // ========= EDGE CASES =========

    function test_largeCounterValues() public {
        // Test with larger counter values
        uint64 largeValue = 1000;

        // Increment local counter many times to reach large value
        for (uint64 i = 1; i <= largeValue; i++) {
            incrementLocalCounterSuccessfully(i);
        }

        assertEq(initCounter.localInitializationCounter(), largeValue);
    }

    function test_maxUint64Values() public {
        // Test behavior near uint64 max (we can't test overflow due to gas limits,
        // but we can test large values)
        uint64 nearMaxValue = type(uint64).max - 10;

        // This would normally be done through proper initialization sequence,
        // but for testing purposes we'll just verify the function handles large values
        vm.expectRevert();
        initCounter.incrementLocalInitializationCounterWithModifier(nearMaxValue);
    }
}
