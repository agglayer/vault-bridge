// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
pragma solidity 0.8.29;

interface IPolygonZkEVMGlobalExitRoot {
    error OnlyAllowedContracts();
    error GlobalExitRootAlreadySet();
    error OnlyGlobalExitRootUpdater();

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
