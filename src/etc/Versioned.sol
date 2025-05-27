// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v0.6.0) (etc/Versioned.sol)

pragma solidity 0.8.29;

/// @author See https://github.com/agglayer/vault-bridge
abstract contract Versioned {
    /// @notice The version of the contract.
    function version() external pure returns (string memory) {
        return "0.6.0";
    }
}
