// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.28;

interface IVersioned {
    /// @notice The version of the contract.
    function version() external pure returns (string memory);
}
