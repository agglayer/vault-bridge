// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.28;

// Main functionality.
import {YieldExposedToken} from "../../YieldExposedToken.sol";

// Other functionality.
import {IVersioned} from "../../etc/IVersioned.sol";

// External contracts.
import {IUSDT} from "../../etc/IUSDT.sol";

/// @title Yield Exposed USDT
contract YeUSDT is YieldExposedToken {
    /// @dev Storage of the Yield Exposed USDT contract.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:0xpolygon.storage.YeUSDT
    struct YeUSDTStorage {
        uint256 cachedBasisPointsRate;
        uint256 cachedMaximumFee;
    }

    /// @dev The storage slot at which Yield Exposed USDT storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("0xpolygon.storage.YeUSDT")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _YEUSDT_STORAGE = hex"8ee293a165ac3d78d3724b0faed67bcdb8e52fa45b6e98021a6acfdf2696c100";

    // Events.
    event USDTTransferFeeParametersRecached(uint256 cachedBasisPointsRate, uint256 cachedMaximumFee);

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

        // Cache the USDT transfer fee parameters.
        recacheUsdtTransferFeeParameters();
    }

    // -----================= ::: STORAGE ::: =================-----

    /// @notice The cached basis points rate.
    /// @dev USDT emits an event when the transfer fee changes. Make sure to recache the parameters when that happens.
    function cachedBasisPointsRate() public view returns (uint256) {
        YeUSDTStorage storage $ = _getYeUSDTStorage();
        return $.cachedBasisPointsRate;
    }

    /// @notice The cached maximum fee.
    /// @dev USDT emits an event when the transfer fee changes. Make sure to recache the parameters when that happens.
    function cachedMaximumFee() public view returns (uint256) {
        YeUSDTStorage storage $ = _getYeUSDTStorage();
        return $.cachedMaximumFee;
    }

    /// @dev Returns a pointer to the ERC-7201 storage namespace.
    function _getYeUSDTStorage() private pure returns (YeUSDTStorage storage $) {
        assembly {
            $.slot := _YEUSDT_STORAGE
        }
    }

    // -----================= ::: YEUSDT ::: =================-----

    /// @notice Recache the USDT transfer fee parameters.
    function recacheUsdtTransferFeeParameters() public whenNotPaused nonReentrant {
        YeUSDTStorage storage $ = _getYeUSDTStorage();

        // Recache the parameters on this contract.
        IUSDT usdt = IUSDT(asset());
        $.cachedBasisPointsRate = usdt.basisPointsRate();
        $.cachedMaximumFee = usdt.maximumFee();

        // Emit the event.
        emit USDTTransferFeeParametersRecached($.cachedBasisPointsRate, $.cachedMaximumFee);
    }

    // -----================= ::: INFO ::: =================-----

    /// @inheritdoc IVersioned
    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }

    // -----================= ::: DEVELOPER ::: =================-----

    // @note Review and document.
    /// @dev USDT has a transfer fee.
    function _assetsAfterTransferFee(uint256 assetsBeforeTransferFee)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        YeUSDTStorage storage $ = _getYeUSDTStorage();

        if ($.cachedBasisPointsRate == 0) {
            return assetsBeforeTransferFee;
        }

        uint256 fee = (assetsBeforeTransferFee * $.cachedBasisPointsRate) / 10000;
        if (fee > $.cachedMaximumFee) {
            fee = $.cachedMaximumFee;
        }

        return assetsBeforeTransferFee - fee;
    }

    // @note Review and document.
    /// @dev USDT has a transfer fee.
    function _assetsBeforeTransferFee(uint256 minimumAssetsAfterTransferFee)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        YeUSDTStorage storage $ = _getYeUSDTStorage();

        if ($.cachedBasisPointsRate == 0) {
            return minimumAssetsAfterTransferFee;
        }

        uint256 denom = 10000 - $.cachedBasisPointsRate;
        uint256 candidate = (minimumAssetsAfterTransferFee * 10000 + (denom - 1)) / denom;

        uint256 feeCandidate = (candidate * $.cachedBasisPointsRate) / 10000;
        if (feeCandidate > $.cachedMaximumFee) {
            return minimumAssetsAfterTransferFee + $.cachedMaximumFee;
        }

        while (candidate > 0) {
            uint256 feeCandidateMinus1 = ((candidate - 1) * $.cachedBasisPointsRate) / 10000;
            if (feeCandidateMinus1 > $.cachedMaximumFee) {
                feeCandidateMinus1 = $.cachedMaximumFee;
            }

            uint256 afterFeeMinus1 = (candidate - 1) - feeCandidateMinus1;
            if (afterFeeMinus1 >= minimumAssetsAfterTransferFee) {
                candidate--;
            } else {
                break;
            }
        }

        return candidate;
    }
}
