// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.28;

interface IPolygonZkEVMGlobalExitRoot {
    error OnlyAllowedContracts();

    function getLastGlobalExitRoot() external view returns (bytes32);
    function getRoot() external view returns (bytes32);
    function globalExitRootMap(bytes32 globalExitRootNum) external returns (uint256);
    function lastMainnetExitRoot() external view returns (bytes32);
    function lastRollupExitRoot() external view returns (bytes32);
    function l1InfoRootMap(uint32 depositCount) external view returns (bytes32);
    function updateExitRoot(bytes32 newRollupExitRoot) external;
    // sovereign bridge functions
    function insertGlobalExitRoot(bytes32 globalExitRoot) external;
}
