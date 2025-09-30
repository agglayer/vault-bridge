// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (script/polygon/DeployRevertingContract.s.sol)

pragma solidity ^0.8.29;

// @remind Document (the entire file).

import "forge-std/Script.sol";

contract DeployRevertingContract is Script {
    string public chainName;

    address public deployerAddress;

    bytes public constant REVERTING_CONTRACT_CREATION_CODE = hex"6005600c60003960056000f360006000fd";
    bytes public constant REVERTING_CONTRACT_RUNTIME_CODE = hex"60006000fd";

    /// @notice Setup.
    /// @dev You can customize the setup here.
    function setUp() public {
        chainName = "";
        deployerAddress = 0x0000000000000000000000000000000000000000;

        require(bytes(chainName).length != 0, "Aborted: `chainName` not set");
        require(deployerAddress != address(0), "Aborted: `deployerAddress` not set");
    }

    function run() public {
        console.log("Running `DeployRevertingContract` script...");

        _createSelectFork(chainName);

        _createRevertingContract();

        console.log("Finished running `DeployRevertingContract` script");
    }

    function _createRevertingContract() internal returns (address) {
        console.log("Creating Reverting Contract...");

        address revertingContract;

        bytes memory initCode = REVERTING_CONTRACT_CREATION_CODE;

        _startBroadcast();

        assembly {
            revertingContract := create(0, add(initCode, 0x20), mload(initCode))
        }

        _stopBroadcast();

        require(revertingContract != address(0), "Aborted: Failed to create Reverting Contract");

        assert(revertingContract.codehash == keccak256(REVERTING_CONTRACT_RUNTIME_CODE));

        console.log("Reverting contract created:", revertingContract);

        return revertingContract;
    }

    function _createSelectFork(string memory chainName_) internal {
        vm.createSelectFork(vm.rpcUrl(chainName_));
        console.log("Switched to", chainName_, "chain");
    }

    function _startBroadcast() internal {
        vm.startBroadcast(deployerAddress);
    }

    function _stopBroadcast() internal {
        vm.stopBroadcast();
    }
}
