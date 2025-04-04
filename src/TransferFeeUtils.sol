// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";

/// @title Transfer Fee Utils
/// @dev This contract provides the generic transfer fee utilities.
abstract contract TransferFeeUtils is Ownable {
    /// @notice The constructor.
    /// @param owner_ The owner.
    constructor(address owner_) Ownable(owner_) {}

    /// @notice The transfer fee percentage.
    /// @param assetsBeforeTransferFee_ The assets before the transfer fee.
    /// @return The asset after the transfer fee.
    /// @dev This provides a generic implementation for the transfer fee.
    function assetsAfterTransferFee(uint256 assetsBeforeTransferFee_) external view virtual returns (uint256) {
        return assetsBeforeTransferFee_;
    }

    /// @notice The transfer fee percentage.
    /// @param minimumAssetsAfterTransferFee_ The minimum assets after the transfer fee.
    /// @return The asset before the transfer fee.
    /// @dev This provides a generic implementation for the transfer fee.
    function assetsBeforeTransferFee(uint256 minimumAssetsAfterTransferFee_) external view virtual returns (uint256) {
        return minimumAssetsAfterTransferFee_;
    }
}
