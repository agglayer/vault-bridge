// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.28;

interface ITransferFeeUtils {
    /// @notice The transfer fee percentage.
    /// @param assetsBeforeTransferFee_ The assets before the transfer fee.
    /// @return The asset after the transfer fee.
    /// @dev This provides a generic implementation for the transfer fee.
    function assetsAfterTransferFee(uint256 assetsBeforeTransferFee_) external view returns (uint256);

    /// @notice The transfer fee percentage.
    /// @param minimumAssetsAfterTransferFee_ The minimum assets after the transfer fee.
    /// @return The asset before the transfer fee.
    /// @dev This provides a generic implementation for the transfer fee.
    function assetsBeforeTransferFee(uint256 minimumAssetsAfterTransferFee_) external view returns (uint256);
}
