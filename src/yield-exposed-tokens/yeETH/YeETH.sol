// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.28;

import {YieldExposedToken} from "../../YieldExposedToken.sol";
import {IWETH9} from "../../etc/IWETH9.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IVersioned} from "../../etc/IVersioned.sol";

/// @title Yield Exposed gas token
contract YeETH is YieldExposedToken {
    enum CustomCrossNetworkInstruction {
        WRAP_COIN_AND_COMPLETE_MIGRATION
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        string calldata name_,
        string calldata symbol_,
        address underlyingToken_,
        uint256 minimumReservePercentage_,
        address yieldVault_,
        address yieldRecipient_,
        address lxlyBridge_,
        address nativeConverter_
    ) external initializer {
        // Initialize the base implementation.
        __YieldExposedToken_init(
            owner_,
            name_,
            symbol_,
            underlyingToken_,
            minimumReservePercentage_,
            yieldVault_,
            yieldRecipient_,
            lxlyBridge_,
            nativeConverter_
        );
    }

    /// @dev deposit ETH to get yeETH
    function depositGasToken(address receiver) external payable whenNotPaused returns (uint256 shares) {
        (shares,) = _deposit(msg.value, lxlyId(), receiver, false, 0);
    }

    /// @dev deposit ETH to get yeETH and bridge to an L2
    function depositGasTokenAndBridge(
        address destinationAddress,
        uint32 destinationNetworkId,
        bool forceUpdateGlobalExitRoot
    ) external payable whenNotPaused returns (uint256 shares) {
        (shares,) = _deposit(msg.value, destinationNetworkId, destinationAddress, forceUpdateGlobalExitRoot, 0);
    }

    function mintWithGasToken(uint256 shares, address receiver)
        external
        payable
        whenNotPaused
        returns (uint256 assets)
    {
        require(shares > 0, InvalidShares());
        // The receiver is checked in the `_deposit` function.

        // Mint yeToken to the receiver.
        uint256 mintedShares;
        (mintedShares, assets) =
        // msg.value is used as assets value, if it exceeds shares value, WETH will be refunded
         _deposit(msg.value, lxlyId(), receiver, false, shares);

        // Check the output.
        require(mintedShares == shares, IncorrectAmountOfSharesMinted(mintedShares, shares));
    }

    function _receiveUnderlyingToken(address, uint256 assets) internal override returns (uint256) {
        IWETH9 weth = IWETH9(address(underlyingToken()));

        if (msg.value >= assets) {
            // deposit everything, excess funds will be refunded in WETH
            weth.deposit{value: msg.value}();
        } else {
            weth.transferFrom(msg.sender, address(this), assets);
        }
        return assets;
    }

    function _dispatchCustomCrossNetworkInstruction(
        address originAddress,
        uint32 originNetwork,
        bytes memory customData
    ) internal override {
        IWETH9 weth = IWETH9(address(underlyingToken()));

        (CustomCrossNetworkInstruction instruction, bytes memory instructionData) =
            abi.decode(customData, (CustomCrossNetworkInstruction, bytes));

        if (instruction == CustomCrossNetworkInstruction.WRAP_COIN_AND_COMPLETE_MIGRATION) {
            require(originAddress == nativeConverter(), Unauthorized());

            (uint256 shares, uint256 assets) = abi.decode(instructionData, (uint256, uint256));

            // deposit ETH assets into WETH
            weth.deposit{value: assets}();

            _completeMigration(originNetwork, shares, assets);
        }
    }

    /// @dev WETH does not have a transfer fee.
    function _assetsAfterTransferFee(uint256 assetsBeforeTransferFee) internal pure override returns (uint256) {
        return assetsBeforeTransferFee;
    }

    /// @dev WETH does not have a transfer fee.
    function _assetsBeforeTransferFee(uint256 minimumAssetsAfterTransferFee) internal pure override returns (uint256) {
        return minimumAssetsAfterTransferFee;
    }

    /// @inheritdoc IVersioned
    function version() external pure override returns (string memory) {
        return "1.0.0";
    }
}
