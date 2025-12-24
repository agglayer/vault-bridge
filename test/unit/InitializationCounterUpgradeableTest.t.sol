// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity 0.8.29;

// Test base
import "test/base/InitializationCounterTestBase.sol";

// Core contract
import {InitializationCounterUpgradeable} from "src/etc/InitializationCounterUpgradeable.sol";

// Proxy contract
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Mock contract
import {MockInitializationCounterUpgradeable} from "test/utils/mocks/MockInitializationCounterUpgradeable.sol";

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

    function test_reinitializersLocked() public {
        // Deploy a new proxy with the mock implementation
        MockInitializationCounterUpgradeable newInitCounter =
            MockInitializationCounterUpgradeable(address(_proxify(address(initCounter), address(this), bytes(""))));
        // Attempting to call reinitialize1 should revert as it is only supposed to be called by the reinitialize function
        vm.expectRevert(InitializationCounterUpgradeable.ReinitializersLocked.selector);
        newInitCounter.reinitialize1();

        // Should be able to call reinitialize1 from reinitialize function
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockInitializationCounterUpgradeable.reinitialize1.selector;

        bytes[] memory reinitData = new bytes[](1);
        reinitData[0] = abi.encodeWithSelector(MockInitializationCounterUpgradeable.reinitialize1.selector, "");
        newInitCounter.reinitialize(selectors, reinitData);
        assertEq(newInitCounter.globalInitializationCounter(), FIRST_INCREMENT);

        // Trying to call reinitialize1 again should revert with ReinitializersLocked
        vm.expectRevert(InitializationCounterUpgradeable.ReinitializersLocked.selector);
        newInitCounter.reinitialize1();

        // Trying to reinitialize again with same selectors should revert with AlreadyReinitialized
        vm.expectRevert(InitializationCounterUpgradeable.AlreadyReinitialized.selector);
        newInitCounter.reinitialize(selectors, reinitData);

        // Should be able to call reinitialize2 from reinitialize function
        // Need to include BOTH reinitialize1 and reinitialize2 in selectors array
        bytes4[] memory selectors2 = new bytes4[](2);
        selectors2[0] = MockInitializationCounterUpgradeable.reinitialize1.selector;
        selectors2[1] = MockInitializationCounterUpgradeable.reinitialize2.selector;
        // Only provide data for reinitialize2 (the new one at index 1)
        bytes[] memory reinitData2 = new bytes[](1);
        reinitData2[0] = abi.encodeWithSelector(MockInitializationCounterUpgradeable.reinitialize2.selector, "");
        newInitCounter.reinitialize(selectors2, reinitData2);
        assertEq(newInitCounter.globalInitializationCounter(), SECOND_INCREMENT);
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

    // ========= REINITIALIZE TESTS =========

    function test_reinitialize_success_singleFunction() public {
        // Deploy proxy with implementation
        MockInitializationCounterUpgradeable implementation = new MockInitializationCounterUpgradeable();
        bytes memory initData = "";
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        MockInitializationCounterUpgradeable proxied = MockInitializationCounterUpgradeable(address(proxy));

        // Setup reinitialize data
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector;

        bytes[] memory reinitData = new bytes[](1);
        reinitData[0] = abi.encodeWithSelector(
            MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector, 1
        );

        // Execute reinitialize
        proxied.reinitialize(selectors, reinitData);

        // Verify global counter was incremented
        assertEq(proxied.globalInitializationCounter(), 1);
    }

    function test_reinitialize_success_multipleFunctions() public {
        // Deploy proxy with implementation
        MockInitializationCounterUpgradeable implementation = new MockInitializationCounterUpgradeable();
        bytes memory initData = "";
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        MockInitializationCounterUpgradeable proxied = MockInitializationCounterUpgradeable(address(proxy));

        // Setup reinitialize data for 3 functions
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector;
        selectors[1] = MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector;
        selectors[2] = MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector;

        bytes[] memory reinitData = new bytes[](3);
        reinitData[0] = abi.encodeWithSelector(
            MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector, 1
        );
        reinitData[1] = abi.encodeWithSelector(
            MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector, 2
        );
        reinitData[2] = abi.encodeWithSelector(
            MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector, 3
        );

        // Execute reinitialize
        proxied.reinitialize(selectors, reinitData);

        // Verify global counter was incremented to 3
        assertEq(proxied.globalInitializationCounter(), 3);
    }

    function test_reinitialize_success_partialReinitialize() public {
        // Deploy proxy with implementation
        MockInitializationCounterUpgradeable implementation = new MockInitializationCounterUpgradeable();
        bytes memory initData = "";
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        MockInitializationCounterUpgradeable proxied = MockInitializationCounterUpgradeable(address(proxy));

        // First reinitialize: execute only first function with 1 selector
        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector;

        bytes[] memory reinitData1 = new bytes[](1);
        reinitData1[0] = abi.encodeWithSelector(
            MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector, 1
        );

        proxied.reinitialize(selectors1, reinitData1);
        assertEq(proxied.globalInitializationCounter(), 1);

        // Second reinitialize: extend selectors array and execute second function
        // Now we need to include both selectors (including the already executed one)
        bytes4[] memory selectors2 = new bytes4[](2);
        selectors2[0] = MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector;
        selectors2[1] = MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector;

        // Only provide data for the second selector (globalCounter=1, so expectedLen = 2-1 = 1)
        bytes[] memory reinitData2 = new bytes[](1);
        reinitData2[0] = abi.encodeWithSelector(
            MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector, 2
        );

        proxied.reinitialize(selectors2, reinitData2);
        assertEq(proxied.globalInitializationCounter(), 2);
    }

    function test_reinitialize_alreadyReinitialized_reverts() public {
        // Deploy proxy with implementation
        MockInitializationCounterUpgradeable implementation = new MockInitializationCounterUpgradeable();
        bytes memory initData = "";
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        MockInitializationCounterUpgradeable proxied = MockInitializationCounterUpgradeable(address(proxy));

        // Setup reinitialize data
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector;

        bytes[] memory reinitData = new bytes[](1);
        reinitData[0] = abi.encodeWithSelector(
            MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector, 1
        );

        // Execute reinitialize
        proxied.reinitialize(selectors, reinitData);

        // Try to reinitialize again with same selectors - should revert
        vm.expectRevert(InitializationCounterUpgradeable.AlreadyReinitialized.selector);
        proxied.reinitialize(selectors, reinitData);
    }

    function test_reinitialize_invalidDataLength_tooMany_reverts() public {
        // Deploy proxy with implementation
        MockInitializationCounterUpgradeable implementation = new MockInitializationCounterUpgradeable();
        bytes memory initData = "";
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        MockInitializationCounterUpgradeable proxied = MockInitializationCounterUpgradeable(address(proxy));

        // Setup selectors for 1 function but provide 2 data items
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector;

        bytes[] memory reinitData = new bytes[](2);
        reinitData[0] = abi.encodeWithSelector(
            MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector, 1
        );
        reinitData[1] = abi.encodeWithSelector(
            MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector, 2
        );

        // Should revert with InvalidReinitializeDataLength
        vm.expectRevert(
            abi.encodeWithSelector(
                InitializationCounterUpgradeable.InvalidReinitializeDataLength.selector,
                1, // expected
                2 // actual
            )
        );
        proxied.reinitialize(selectors, reinitData);
    }

    function test_reinitialize_invalidDataLength_tooFew_reverts() public {
        // Deploy proxy with implementation
        MockInitializationCounterUpgradeable implementation = new MockInitializationCounterUpgradeable();
        bytes memory initData = "";
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        MockInitializationCounterUpgradeable proxied = MockInitializationCounterUpgradeable(address(proxy));

        // Setup selectors for 2 functions but provide 1 data item
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector;
        selectors[1] = MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector;

        bytes[] memory reinitData = new bytes[](1);
        reinitData[0] = abi.encodeWithSelector(
            MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector, 1
        );

        // Should revert with InvalidReinitializeDataLength
        vm.expectRevert(
            abi.encodeWithSelector(
                InitializationCounterUpgradeable.InvalidReinitializeDataLength.selector,
                2, // expected
                1 // actual
            )
        );
        proxied.reinitialize(selectors, reinitData);
    }

    function test_reinitialize_eip1967NotDetected_reverts() public {
        // Call reinitialize on non-proxy contract (no EIP-1967 implementation slot)
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector;

        bytes[] memory reinitData = new bytes[](1);
        reinitData[0] = abi.encodeWithSelector(
            MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector, 1
        );

        // Should revert because initCounter is not behind a proxy
        vm.expectRevert(InitializationCounterUpgradeable.Eip1967NotDetected.selector);
        initCounter.reinitialize(selectors, reinitData);
    }

    function test_reinitialize_unknownSelector_reverts() public {
        // Deploy proxy with implementation
        MockInitializationCounterUpgradeable implementation = new MockInitializationCounterUpgradeable();
        bytes memory initData = "";
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        MockInitializationCounterUpgradeable proxied = MockInitializationCounterUpgradeable(address(proxy));

        // Setup selectors array but provide data with different selector
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockInitializationCounterUpgradeable.incrementGlobalInitializationCounter.selector;

        bytes[] memory reinitData = new bytes[](1);
        // Provide data with wrong selector (reinitializeRevert instead of incrementGlobalInitializationCounter)
        reinitData[0] = abi.encodeWithSelector(MockInitializationCounterUpgradeable.reinitializeRevert.selector);

        // Should revert with UnknownReinitializeSelector
        vm.expectRevert(
            abi.encodeWithSelector(
                InitializationCounterUpgradeable.UnknownReinitializeSelector.selector,
                MockInitializationCounterUpgradeable.reinitializeRevert.selector
            )
        );
        proxied.reinitialize(selectors, reinitData);
    }

    function test_reinitialize_delegatecallReverts_bubblesUpError() public {
        // Deploy proxy with implementation
        MockInitializationCounterUpgradeable implementation = new MockInitializationCounterUpgradeable();
        bytes memory initData = "";
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        MockInitializationCounterUpgradeable proxied = MockInitializationCounterUpgradeable(address(proxy));

        // Setup reinitialize data with function that reverts
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockInitializationCounterUpgradeable.reinitializeRevert.selector;

        bytes[] memory reinitData = new bytes[](1);
        reinitData[0] = abi.encodeWithSelector(MockInitializationCounterUpgradeable.reinitializeRevert.selector);

        // Should revert with the error from reinitializeRevert
        vm.expectRevert("Mock revert");
        proxied.reinitialize(selectors, reinitData);
    }

    function test_reinitialize_emptySelectors_assertFails() public {
        // Deploy proxy with implementation
        MockInitializationCounterUpgradeable implementation = new MockInitializationCounterUpgradeable();
        bytes memory initData = "";
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        MockInitializationCounterUpgradeable proxied = MockInitializationCounterUpgradeable(address(proxy));

        // Setup empty selectors array
        bytes4[] memory selectors = new bytes4[](0);
        bytes[] memory reinitData = new bytes[](0);

        // Should revert due to assert(reinitializeSelectors.length > 0)
        vm.expectRevert();
        proxied.reinitialize(selectors, reinitData);
    }
}
