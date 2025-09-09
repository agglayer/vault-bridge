// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title MockAgglayerBridge
 * @dev A mock implementation of the Agglayer Bridge for testing without fork dependency
 */
contract MockAgglayerBridge {
    uint32 public depositCount;
    uint32 public networkID;

    // Gas token properties for VbETH testing
    address public gasTokenAddress;
    uint32 public gasTokenNetwork;

    address public globalExitRootManager;

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
        bytes memory metadata;

        if (token == address(0)) {
            require(msg.value == amount, "MockAgglayerBridge: ETH amount mismatch");
            metadata = "";
        } else {
            // Transfer tokens to this bridge contract (like the real bridge does)
            IERC20Metadata erc20 = IERC20Metadata(token);
            require(erc20.transferFrom(msg.sender, address(this), amount), "MockAgglayerBridge: transfer failed");

            // Read token metadata
            string memory name = erc20.name();
            string memory symbol = erc20.symbol();
            uint8 decimals = erc20.decimals();

            // Encode metadata the same way the real bridge does
            metadata = abi.encode(name, symbol, decimals);
        }

        // Determine origin network based on token type
        uint32 originNetwork;
        if (token == address(0)) {
            // For ETH (gas token), the origin is always the primary chain (network 0)
            originNetwork = 0;
        } else {
            // For other tokens, use the current network
            originNetwork = networkID;
        }

        // Emit BridgeEvent with the current depositCount (before incrementing)
        emit BridgeEvent(
            0, // leafType: LEAF_TYPE_ASSET
            originNetwork,
            token, // originAddress
            destinationNetwork,
            destinationAddress,
            amount,
            metadata,
            depositCount
        );

        depositCount++;
    }

    function bridgeMessage(
        uint32 destinationNetwork,
        address destinationAddress,
        bool, /* forceUpdateGlobalExitRoot */
        bytes calldata message
    ) external payable {
        emit BridgeEvent(
            1, // leafType: LEAF_TYPE_MESSAGE
            networkID, // originNetwork
            msg.sender, // originAddress
            destinationNetwork,
            destinationAddress,
            0, // amount
            message,
            depositCount
        );

        depositCount++;
    }

    /// @dev Set the Global Exit Root Manager address
    function setGlobalExitRootManager(address _globalExitRootManager) external {
        globalExitRootManager = _globalExitRootManager;
    }

    /// @dev Set network id for testing different networks
    function setNetworkId(uint32 _networkID) external {
        networkID = _networkID;
    }

    /// @dev Set deposit count for testing
    function setDepositCount(uint32 _depositCount) external {
        depositCount = _depositCount;
    }

    /// @dev Set gas token address for VbETH testing
    function setGasTokenAddress(address _gasTokenAddress) external {
        gasTokenAddress = _gasTokenAddress;
    }

    /// @dev Set gas token network for VbETH testing
    function setGasTokenNetwork(uint32 _gasTokenNetwork) external {
        gasTokenNetwork = _gasTokenNetwork;
    }

    /// @dev For testing, assume all wrapped addresses are not mintable
    function wrappedAddressIsNotMintable(address wrappedAddress) external pure returns (bool isNotMintable) {
        (wrappedAddress);
        return true;
    }
}
