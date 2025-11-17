// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Mock Vault Bridge Token for Migration Manager Testing
/// @notice A mock implementation of VaultBridgeToken for testing MigrationManager
contract MockVbToken {
    IERC20 public underlyingToken;

    function setUnderlyingToken(address _underlyingToken) external {
        underlyingToken = IERC20(_underlyingToken);
    }

    function completeMigration(uint32 originNetwork, uint256 shares, uint256 assets) external {}
}
