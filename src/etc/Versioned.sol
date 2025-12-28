// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.1) (etc/Versioned.sol)

pragma solidity 0.8.29;

/// @author See https://github.com/agglayer/vault-bridge
abstract contract Versioned {
    /// @notice The version of the contract.
    function VAULT_BRIDGE_PROTOCOL() public pure returns (string memory) {
        return "1.1.1";
    }
}
