// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.29;

// Main functionality.
import {ITransferFeeCalculator} from "../../ITransferFeeCalculator.sol";

// External contracts.
import {IUSDT} from "../../etc/IUSDT.sol";

// @todo Document.
contract USDTTransferFeeCalculator is ITransferFeeCalculator {
    /// @notice The USDT contract.
    IUSDT public immutable USDT;

    // Errors.
    error InvalidUsdt();

    constructor(address usdt) {
        // Check the input.
        require(usdt != address(0), InvalidUsdt());

        // Set the USDT contract.
        USDT = IUSDT(usdt);
    }

    // -----================= ::: TRANSFER FEE CALCULATOR ::: =================-----

    // @todo Review.
    // @todo Document.
    /// @inheritdoc ITransferFeeCalculator
    function assetsAfterTransferFee(uint256 assetsBeforeTransferFee_) external view override returns (uint256) {
        uint256 basisPointsRate = USDT.basisPointsRate();
        uint256 maximumFee = USDT.maximumFee();

        if (basisPointsRate == 0) {
            return assetsBeforeTransferFee_;
        }

        uint256 fee = (assetsBeforeTransferFee_ * basisPointsRate) / 10000;
        if (fee > maximumFee) {
            fee = maximumFee;
        }

        return assetsBeforeTransferFee_ - fee;
    }

    // @todo Review.
    // @todo Document.
    /// @inheritdoc ITransferFeeCalculator
    function assetsBeforeTransferFee(uint256 minimumAssetsAfterTransferFee_) external view override returns (uint256) {
        uint256 basisPointsRate = USDT.basisPointsRate();
        uint256 maximumFee = USDT.maximumFee();

        if (basisPointsRate == 0) {
            return minimumAssetsAfterTransferFee_;
        }

        uint256 denom = 10000 - basisPointsRate;
        uint256 candidate = (minimumAssetsAfterTransferFee_ * 10000 + (denom - 1)) / denom;

        uint256 feeCandidate = (candidate * basisPointsRate) / 10000;
        if (feeCandidate > maximumFee) {
            return minimumAssetsAfterTransferFee_ + maximumFee;
        }

        while (candidate > 0) {
            uint256 feeCandidateMinus1 = ((candidate - 1) * basisPointsRate) / 10000;
            if (feeCandidateMinus1 > maximumFee) {
                feeCandidateMinus1 = maximumFee;
            }

            uint256 afterFeeMinus1 = (candidate - 1) - feeCandidateMinus1;
            if (afterFeeMinus1 >= minimumAssetsAfterTransferFee_) {
                candidate--;
            } else {
                break;
            }
        }

        return candidate;
    }
}
