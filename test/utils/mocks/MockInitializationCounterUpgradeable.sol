// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity 0.8.29;

import {InitializationCounterUpgradeable} from "src/etc/InitializationCounterUpgradeable.sol";

/// @title Mock InitializationCounterUpgradeable
/// @notice An implementation of InitializationCounterUpgradeable for testing purposes
/// @dev This contract exposes internal functionality of InitializationCounterUpgradeable for testing
contract MockInitializationCounterUpgradeable is InitializationCounterUpgradeable {
    /// @notice Funciton to simulate reinitialize1
    function reinitialize1() external locked {
        _incrementGlobalInitializationCounter(1);
    }

    // @notice Function to simulate reinitialize2
    function reinitialize2() external locked {
        _incrementGlobalInitializationCounter(2);
    }

    /// @notice Expose the private _localInitializationCounter for testing
    function localInitializationCounter() external view returns (uint64) {
        InitializationCounterUpgradeableStorage storage $;
        assembly {
            $.slot := 0x8d679e361eeeac0b879fa197c8b3bda76a3db4f57c9f89335c04a065390bbb00
        }
        return $._localInitializationCounter;
    }

    /// @notice Expose the private _extensionInitializationCounter
    function extensionInitializationCounter() external view returns (uint64) {
        InitializationCounterUpgradeableStorage storage $;
        assembly {
            $.slot := 0x8d679e361eeeac0b879fa197c8b3bda76a3db4f57c9f89335c04a065390bbb00
        }
        return $._extensionInitializationCounter[Extension.WETH];
    }

    /// @notice Public wrapper for _incrementGlobalInitializationCounter
    function incrementGlobalInitializationCounter(uint64 expectedNewValue) external returns (uint64) {
        return _incrementGlobalInitializationCounter(expectedNewValue);
    }

    /// @notice Function that uses incrementsLocalInitializationCounter modifier
    function incrementLocalInitializationCounterWithModifier(uint64 expectedNewValue)
        external
        incrementsLocalInitializationCounter(expectedNewValue)
    {
        // Function body can be empty, the modifier does the work
    }

    /// @notice Function that uses incrementsExtensionInitializationCounter modifier
    function incrementExtensionInitializationCounterWithModifier(
        uint64 requiredLocalValue,
        uint64 expectedNewExtensionValue
    )
        external
        incrementsExtensionInitializationCounter(requiredLocalValue, Extension.WETH, expectedNewExtensionValue)
    {
        // Function body can be empty, the modifier does the work
    }

    /// @notice Helper function to get storage slot for testing
    function getStorageSlot() external pure returns (bytes32) {
        return 0x8d679e361eeeac0b879fa197c8b3bda76a3db4f57c9f89335c04a065390bbb00;
    }

    /// @notice Public wrapper for _reinitialize to test reinitialization logic
    function reinitialize(bytes4[] memory reinitializeSelectors, bytes[] calldata reinitializeData) external {
        _reinitialize(reinitializeSelectors, reinitializeData);
    }

    /// @notice Mock reinitialize function that reverts
    function reinitializeRevert() external pure {
        revert("Mock revert");
    }
}
