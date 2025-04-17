// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.29;

interface IUSDT {
    function basisPointsRate() external view returns (uint256);
    function maximumFee() external view returns (uint256);
}
