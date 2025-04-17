// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.29;

// @todo Document.
interface ITransferFeeCalculator {
    // @todo Redocument.
    /// @notice Accounts for the transfer fee of the underlying token.
    /// @dev You must implement the same behavior as that of the underlying token for calculating the transfer fee.
    /// @dev If the underlying token does not have a transfer fee, the output must equal the input.
    /// @dev This function is used for estimation purposes only.
    /// @dev Example:
    /// @dev Fee: 2% flat
    /// @dev Input: `100`
    /// @dev Output: `98`
    function assetsAfterTransferFee(uint256 assetsBeforeTransferFee) external view returns (uint256);

    // @todo Redocument.
    /// @notice Accounts for the transfer fee of the underlying token.
    /// @dev You must implement the same behavior as that of the underlying token for calculating the transfer fee.
    /// @dev If the underlying token does not have a transfer fee, the output must equal the input.
    /// @dev This function is used for estimation purposes only.
    /// @dev Example:
    /// @dev Fee: 2% flat
    /// @dev Input:  `98`
    /// @dev Output: `100`
    /// @param minimumAssetsAfterTransferFee It may not always be mathematically possible to calculate the assets before a transfer fee (because of fee tiers, etc). In those cases, the output should be the closest higher amount.
    function assetsBeforeTransferFee(uint256 minimumAssetsAfterTransferFee) external view returns (uint256);
}
