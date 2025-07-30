// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v0.5.0) (etc/IWETH9.sol)

pragma solidity 0.8.29;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Interface for WETH9
/// @author See https://github.com/agglayer/vault-bridge
interface IWETH9 is IERC20 {
    /// @notice Deposit ether to get wrapped ether
    function deposit() external payable;

    /// @notice Withdraw wrapped ether to get ether
    function withdraw(uint256) external;
}
