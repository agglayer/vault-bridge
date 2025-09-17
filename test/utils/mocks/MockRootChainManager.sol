// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Mock Root Chain Manager
/// @notice Simulates the Polygon PoS RootChainManager for testing
contract MockRootChainManager {
    mapping(address => address) public rootToChildToken;
    mapping(address => bool) public isTokenMapped;

    event TokensMapped(address indexed rootToken, address indexed childToken, bytes32 indexed tokenType);

    function mapToken(address rootToken, address childToken, bytes32 tokenType) external {
        rootToChildToken[rootToken] = childToken;
        isTokenMapped[rootToken] = true;
        emit TokensMapped(rootToken, childToken, tokenType);
    }

    function depositFor(address, /* user */ address rootToken, bytes calldata depositData) external {
        require(isTokenMapped[rootToken], "Token not mapped");

        uint256 amount = abi.decode(depositData, (uint256));

        // Transfer tokens from user to this contract (simulate locking)
        IERC20(rootToken).transferFrom(msg.sender, address(this), amount);
    }

    function exit(address user, address rootToken, uint256 amount) external {
        // Simulate exit functionality - transfer tokens back to user
        // In real implementation this would verify merkle proofs
        IERC20(rootToken).transfer(user, amount);
    }
}
