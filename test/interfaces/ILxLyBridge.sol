// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.29;

import {ILxLyBridge as _ILxLyBridge} from "../../src/etc/ILxLyBridge.sol";

interface ILxLyBridge is _ILxLyBridge {
    function depositCount() external view returns (uint32);
    function precalculatedWrapperAddress(
        uint32 originNetwork,
        address originTokenAddress,
        string calldata name,
        string calldata symbol,
        uint8 decimals
    ) external view returns (address);
    function getLeafValue(
        uint8 leafType,
        uint32 originNetwork,
        address originAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        bytes32 metadataHash
    ) external pure returns (bytes32);
    function verifyMerkleProof(bytes32 leafHash, bytes32[32] calldata smtProof, uint32 index, bytes32 root)
        external
        pure
        returns (bool);
}
