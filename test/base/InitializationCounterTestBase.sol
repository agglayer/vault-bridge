// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity 0.8.29;

// Test infrastructure
import {TestConstants} from "test/base/TestConstants.sol";

// Core contract
import {InitializationCounterUpgradeable} from "src/etc/InitializationCounterUpgradeable.sol";

// Test utilities
import {MockInitializationCounterUpgradeable} from "test/utils/mocks/MockInitializationCounterUpgradeable.sol";

/// @title InitializationCounter Test Base
/// @notice Base contract for testing InitializationCounterUpgradeable functionality
/// @dev Provides common setup and utilities for testing initialization counter behavior
abstract contract InitializationCounterTestBase is TestConstants {
    // ========= MAIN CONTRACT =========
    MockInitializationCounterUpgradeable internal initCounter;

    // ========= TEST STATE =========
    uint64 internal constant INITIAL_COUNTER_VALUE = 0;
    uint64 internal constant FIRST_INCREMENT = 1;
    uint64 internal constant SECOND_INCREMENT = 2;
    uint64 internal constant THIRD_INCREMENT = 3;

    // ========= SETUP =========

    /// @notice Deploy InitializationCounter testing infrastructure
    /// @dev Sets up the mock contract and verifies initial state
    function deployInitializationCounterInfrastructure() internal {
        deployInitializationCounter();
        verifyInitializationCounterSetup();
        setupLabels();
    }

    /// @notice Deploy the mock InitializationCounterUpgradeable contract
    function deployInitializationCounter() internal {
        initCounter = new MockInitializationCounterUpgradeable();
    }

    /// @notice Verify the initial setup of the initialization counter
    function verifyInitializationCounterSetup() internal view {
        // Verify all counters start at 0
        assertEq(initCounter.globalInitializationCounter(), INITIAL_COUNTER_VALUE);
        assertEq(initCounter.localInitializationCounter(), INITIAL_COUNTER_VALUE);
        assertEq(initCounter.extensionInitializationCounter(), INITIAL_COUNTER_VALUE);

        // Verify storage slot is correct
        assertEq(initCounter.getStorageSlot(), 0x8d679e361eeeac0b879fa197c8b3bda76a3db4f57c9f89335c04a065390bbb00);
    }

    /// @notice Set up test labels for better debugging
    function setupLabels() internal {
        vm.label(address(initCounter), "InitializationCounter");
    }

    // ========= HELPER FUNCTIONS =========

    /// @notice Helper to get all current counter values
    /// @return global Current global initialization counter
    /// @return local Current local initialization counter
    /// @return extension Current extension initialization counter
    function getCurrentCounters() internal view returns (uint64 global, uint64 local, uint64 extension) {
        global = initCounter.globalInitializationCounter();
        local = initCounter.localInitializationCounter();
        extension = initCounter.extensionInitializationCounter();
    }

    /// @notice Helper to verify counter values match expected values
    /// @param expectedGlobal Expected global counter value
    /// @param expectedLocal Expected local counter value
    /// @param expectedExtension Expected extension counter value
    function assertCounterValues(uint64 expectedGlobal, uint64 expectedLocal, uint64 expectedExtension) internal view {
        assertEq(initCounter.globalInitializationCounter(), expectedGlobal, "Global counter mismatch");
        assertEq(initCounter.localInitializationCounter(), expectedLocal, "Local counter mismatch");
        assertEq(initCounter.extensionInitializationCounter(), expectedExtension, "Extension counter mismatch");
    }

    /// @notice Helper to simulate successful local counter increment
    /// @param expectedValue The expected new value after increment
    function incrementLocalCounterSuccessfully(uint64 expectedValue) internal {
        initCounter.incrementLocalInitializationCounterWithModifier(expectedValue);
        assertEq(initCounter.localInitializationCounter(), expectedValue);
    }

    /// @notice Helper to simulate successful global counter increment
    /// @param expectedValue The expected new value after increment
    function incrementGlobalCounterSuccessfully(uint64 expectedValue) internal {
        uint64 returnedValue = initCounter.incrementGlobalInitializationCounter(expectedValue);
        assertEq(returnedValue, expectedValue, "Returned value should match expected");
        assertEq(initCounter.globalInitializationCounter(), expectedValue, "Global counter should be updated");
    }

    /// @notice Helper to simulate successful extension counter increment
    /// @param requiredLocalValue The required local counter value
    /// @param expectedExtensionValue The expected new extension counter value
    function incrementExtensionCounterSuccessfully(uint64 requiredLocalValue, uint64 expectedExtensionValue) internal {
        initCounter.incrementExtensionInitializationCounterWithModifier(requiredLocalValue, expectedExtensionValue);
        assertEq(initCounter.extensionInitializationCounter(), expectedExtensionValue);
    }

    /// @notice Helper to test local counter increment failure with wrong expected value
    /// @param wrongExpectedValue Incorrect expected value that should cause assertion failure
    function expectLocalCounterIncrementFailure(uint64 wrongExpectedValue) internal {
        vm.expectRevert();
        initCounter.incrementLocalInitializationCounterWithModifier(wrongExpectedValue);
    }

    /// @notice Helper to test global counter increment failure with wrong expected value
    /// @param wrongExpectedValue Incorrect expected value that should cause revert
    function expectGlobalCounterIncrementFailure(uint64 wrongExpectedValue) internal {
        uint64 currentGlobal = initCounter.globalInitializationCounter();
        uint64 actualExpected = currentGlobal + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                InitializationCounterUpgradeable.IncorrectInitializationOrder.selector,
                wrongExpectedValue,
                actualExpected
            )
        );
        initCounter.incrementGlobalInitializationCounter(wrongExpectedValue);
    }

    /// @notice Helper to test extension counter increment failure with wrong local requirement
    /// @param wrongLocalValue Incorrect local counter requirement
    /// @param expectedExtensionValue Expected extension value (doesn't matter since local check fails first)
    function expectExtensionCounterIncrementFailure(uint64 wrongLocalValue, uint64 expectedExtensionValue) internal {
        vm.expectRevert();
        initCounter.incrementExtensionInitializationCounterWithModifier(wrongLocalValue, expectedExtensionValue);
    }

    /// @notice Helper to test extension counter increment failure with wrong expected extension value
    /// @param correctLocalValue Correct local counter requirement
    /// @param wrongExpectedExtensionValue Incorrect expected extension value
    function expectExtensionCounterIncrementFailureWithWrongExtension(
        uint64 correctLocalValue,
        uint64 wrongExpectedExtensionValue
    ) internal {
        vm.expectRevert();
        initCounter.incrementExtensionInitializationCounterWithModifier(correctLocalValue, wrongExpectedExtensionValue);
    }
}
