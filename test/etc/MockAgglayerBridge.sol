// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title MockAgglayerBridge
 * @dev A mock implementation of the Agglayer Bridge for testing without fork dependency
 */
contract MockAgglayerBridge {
    uint32 public depositCount; // Make public for getter
    uint32 private constant NETWORK_ID = 0; // Mock network ID for primary chain

    event BridgeEvent(
        uint8 leafType,
        uint32 originNetwork,
        address originAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        bytes metadata,
        uint32 depositCount
    );

    function bridgeAsset(
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        address token,
        bool, /* forceUpdateGlobalExitRoot */
        bytes calldata /* permitData */
    ) external payable {
        // Transfer tokens to this bridge contract (like the real bridge does)
        IERC20Metadata erc20 = IERC20Metadata(token);
        require(erc20.transferFrom(msg.sender, address(this), amount), "MockAgglayerBridge: transfer failed");

        // Read token metadata
        string memory name = erc20.name();
        string memory symbol = erc20.symbol();
        uint8 decimals = erc20.decimals();

        // Encode metadata the same way the real bridge does
        bytes memory metadata = abi.encode(name, symbol, decimals);

        // Emit BridgeEvent with the current depositCount (before incrementing)
        emit BridgeEvent(
            0, // leafType: LEAF_TYPE_ASSET
            NETWORK_ID, // originNetwork
            token, // originAddress
            destinationNetwork,
            destinationAddress,
            amount,
            metadata,
            depositCount
        );

        depositCount++;
    }

    function setDepositCount(uint32 _depositCount) external {
        depositCount = _depositCount;
    }

    function networkID() external pure returns (uint32) {
        return NETWORK_ID;
    }
}
