// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
pragma solidity 0.8.29;

/// @author See https://github.com/agglayer/vault-bridge
interface IVersioned {
    /// @notice The version of the contract.
    function version() external pure returns (string memory);
}
