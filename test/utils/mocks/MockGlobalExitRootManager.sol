// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

/// @dev A mock GlobalExitRootManager for testing without fork dependency
contract MockGlobalExitRootManager {
    /// @dev Mock function to simulate updating the exit root
    function updateExitRoot(bytes32 newRoot) public pure {
        (newRoot);
    }
}
