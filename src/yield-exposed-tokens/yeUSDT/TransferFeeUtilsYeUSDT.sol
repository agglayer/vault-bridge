// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.28;

// Main functionality.
import {TransferFeeUtils} from "../../TransferFeeUtils.sol";

// External contracts.
import {IUSDT} from "../../etc/IUSDT.sol";

contract TransferFeeUtilsYeUSDT is TransferFeeUtils {
    // Storage.
    uint256 public cachedBasisPointsRate;
    uint256 public cachedMaximumFee;
    address public asset;

    // Errors.
    error InvalidAsset();

    // Events.
    event USDTTransferFeeParametersRecached(uint256 cachedBasisPointsRate, uint256 cachedMaximumFee);

    constructor(address owner_, address asset_) TransferFeeUtils(owner_) {
        require(owner_ != address(0), OwnableInvalidOwner(owner_));
        require(asset_ != address(0), InvalidAsset());

        // Set the asset.
        asset = asset_;

        // Recache the parameters on this contract.
        _recacheUsdtTransferFeeParameters();
    }

    // -----================= ::: ADMIN ::: =================-----

    /// @notice Recache the USDT transfer fee parameters.
    function recacheUsdtTransferFeeParameters() public onlyOwner {
        _recacheUsdtTransferFeeParameters();
    }

    // -----================= ::: TRANSFER FEE UTILS ::: =================-----

    // @todo Review and document.
    /// @inheritdoc TransferFeeUtils
    function assetsAfterTransferFee(uint256 assetsBeforeTransferFee_) external view override returns (uint256) {
        if (cachedBasisPointsRate == 0) {
            return assetsBeforeTransferFee_;
        }

        uint256 fee = (assetsBeforeTransferFee_ * cachedBasisPointsRate) / 10000;
        if (fee > cachedMaximumFee) {
            fee = cachedMaximumFee;
        }

        return assetsBeforeTransferFee_ - fee;
    }

    // @todo Review and document.
    /// @inheritdoc TransferFeeUtils
    function assetsBeforeTransferFee(uint256 minimumAssetsAfterTransferFee_) external view override returns (uint256) {
        if (cachedBasisPointsRate == 0) {
            return minimumAssetsAfterTransferFee_;
        }

        uint256 denom = 10000 - cachedBasisPointsRate;
        uint256 candidate = (minimumAssetsAfterTransferFee_ * 10000 + (denom - 1)) / denom;

        uint256 feeCandidate = (candidate * cachedBasisPointsRate) / 10000;
        if (feeCandidate > cachedMaximumFee) {
            return minimumAssetsAfterTransferFee_ + cachedMaximumFee;
        }

        while (candidate > 0) {
            uint256 feeCandidateMinus1 = ((candidate - 1) * cachedBasisPointsRate) / 10000;
            if (feeCandidateMinus1 > cachedMaximumFee) {
                feeCandidateMinus1 = cachedMaximumFee;
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

    /// @notice Recache the USDT transfer fee parameters.
    function _recacheUsdtTransferFeeParameters() internal {
        // Recache the parameters on this contract.
        IUSDT usdt = IUSDT(asset);
        cachedBasisPointsRate = usdt.basisPointsRate();
        cachedMaximumFee = usdt.maximumFee();

        // Emit the event.
        emit USDTTransferFeeParametersRecached(cachedBasisPointsRate, cachedMaximumFee);
    }
}
