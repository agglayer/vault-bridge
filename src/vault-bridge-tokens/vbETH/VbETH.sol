// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.28;

import {VaultBridgeToken, NativeConverterInfo} from "../../VaultBridgeToken.sol";
import {IWETH9} from "../../etc/IWETH9.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IVersioned} from "../../etc/IVersioned.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Vault Bridge gas token
contract VbETH is VaultBridgeToken {
    using SafeERC20 for IWETH9;

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
        NativeConverterInfo[] calldata nativeConverters_,
        uint256 minimumYieldVaultDeposit_,
        address transferFeeUtil_,
        address initializer_
    ) external initializer {
        // Initialize the base implementation.
        __VaultBridgeToken_init(
            owner_,
            name_,
            symbol_,
            underlyingToken_,
            minimumReservePercentage_,
            yieldVault_,
            yieldRecipient_,
            lxlyBridge_,
            nativeConverters_,
            minimumYieldVaultDeposit_,
            transferFeeUtil_,
            initializer_
        );
    }

    /// @dev deposit ETH to get vbETH
    function depositGasToken(address receiver) external payable whenNotPaused nonReentrant returns (uint256 shares) {
        (shares,) = _deposit(msg.value, lxlyId(), receiver, false, 0);
    }

    /// @dev deposit ETH to get vbETH and bridge to an L2
    function depositGasTokenAndBridge(
        address destinationAddress,
        uint32 destinationNetworkId,
        bool forceUpdateGlobalExitRoot
    ) external payable whenNotPaused nonReentrant returns (uint256 shares) {
        (shares,) = _deposit(msg.value, destinationNetworkId, destinationAddress, forceUpdateGlobalExitRoot, 0);
    }

    function mintWithGasToken(uint256 shares, address receiver)
        external
        payable
        whenNotPaused
        nonReentrant
        returns (uint256 assets)
    {
        require(shares > 0, InvalidShares());
        // The receiver is checked in the `_deposit` function.

        // Mint vbToken to the receiver.
        uint256 mintedShares;
        (mintedShares, assets) =
        // msg.value is used as assets value, if it exceeds shares value, WETH will be refunded
         _deposit(msg.value, lxlyId(), receiver, false, shares);

        // Check the output.
        require(mintedShares == shares, IncorrectAmountOfSharesMinted(mintedShares, shares));
    }

    function _receiveUnderlyingToken(address, uint256 assets) internal override returns (uint256) {
        IWETH9 weth = IWETH9(address(underlyingToken()));

        if (msg.value > 0) {
            // deposit everything, excess funds will be refunded in WETH
            weth.deposit{value: msg.value}();
            return msg.value;
        } else {
            weth.safeTransferFrom(msg.sender, address(this), assets);
            return assets;
        }
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
            require(originAddress != address(0), Unauthorized());
            require(originAddress == nativeConverters(originNetwork), Unauthorized());

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
