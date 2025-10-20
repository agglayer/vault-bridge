// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

/// @dev Mock NativeConverter for testing
contract MockNativeConverter {
    uint256 public removeMigrationInProgressAmount;

    function removeMigrationInProgress(uint256 amount) external {
        removeMigrationInProgressAmount = amount;
    }
}
