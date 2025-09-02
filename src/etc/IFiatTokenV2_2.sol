// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (etc/IFiatTokenV2_2.sol)

pragma solidity 0.8.29;

// Main functionality.
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Bridged USDC Standard Interface
/// @author See https://github.com/agglayer/vault-bridge
interface IFiatTokenV2_2 is IERC20 {
    function burn(uint256 _amount) external;
}
