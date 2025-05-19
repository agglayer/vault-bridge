//
pragma solidity 0.8.29;

import {VaultBridgeToken, ILxLyBridge} from "../../VaultBridgeToken.sol";
import {IWETH9} from "../../etc/IWETH9.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IVersioned} from "../../etc/IVersioned.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Vault Bridge gas token
/// @dev CAUTION! As-is, this contract MUST NOT be used on a network if the gas token is not ETH.
contract VbETH is VaultBridgeToken {
    using SafeERC20 for IWETH9;

    error ContractNotSupportedOnThisNetwork();
    error IncorrectMsgValue(uint256 msgValue, uint256 requestedAssets);

    constructor() {
        _disableInitializers();
    }

    function initialize(address initializer_, VaultBridgeToken.InitializationParameters calldata initParams)
        external
        initializer
    {
        require(
            ILxLyBridge(initParams.lxlyBridge).gasTokenAddress() == address(0)
                && ILxLyBridge(initParams.lxlyBridge).gasTokenNetwork() == 0,
            ContractNotSupportedOnThisNetwork()
        );

        // Initialize the base implementation.
        __VaultBridgeToken_init(initializer_, initParams);
    }

    /// @dev deposit ETH to get vbETH
    function depositGasToken(address receiver) external payable whenNotPaused nonReentrant returns (uint256 shares) {
        (shares,) = _depositUsingCustomReceivingFunction(
            _receiveUnderlyingTokenViaMsgValue, msg.value, lxlyId(), receiver, false, 0
        );
    }

    /// @dev deposit ETH to get vbETH and bridge to an L2
    function depositGasTokenAndBridge(
        address destinationAddress,
        uint32 destinationNetworkId,
        bool forceUpdateGlobalExitRoot
    ) external payable whenNotPaused nonReentrant returns (uint256 shares) {
        (shares,) = _depositUsingCustomReceivingFunction(
            _receiveUnderlyingTokenViaMsgValue,
            msg.value,
            destinationNetworkId,
            destinationAddress,
            forceUpdateGlobalExitRoot,
            0
        );
    }

    function mintWithGasToken(uint256 shares, address receiver)
        external
        payable
        whenNotPaused
        nonReentrant
        returns (uint256 assets)
    {
        require(shares > 0, InvalidShares());
        // The receiver is checked in the `_depositUsingCustomReceivingFunction` function.

        // Mint vbToken to the receiver.
        uint256 mintedShares;
        (mintedShares, assets) =
        // msg.value is used as assets value, if it exceeds shares value, WETH will be refunded
        _depositUsingCustomReceivingFunction(
            _receiveUnderlyingTokenViaMsgValue, msg.value, lxlyId(), receiver, false, shares
        );

        // Check the output.
        require(mintedShares == shares, IncorrectAmountOfSharesMinted(mintedShares, shares));
    }

    function _receiveUnderlyingTokenViaMsgValue(address from, uint256 assets) internal {
        assert(from == msg.sender);

        require(msg.value == assets, IncorrectMsgValue(msg.value, assets));

        IWETH9 weth = IWETH9(address(underlyingToken()));

        uint256 balanceBefore = weth.balanceOf(address(this));

        // deposit everything, excess funds will be refunded in WETH
        weth.deposit{value: msg.value}();

        uint256 balanceAfter = weth.balanceOf(address(this));

        uint256 receivedAssets = balanceAfter - balanceBefore;

        require(receivedAssets == assets, InsufficientUnderlyingTokenReceived(receivedAssets, assets));
    }

    /// @inheritdoc IVersioned
    function version() external pure override returns (string memory) {
        return "1.0.0";
    }
}
