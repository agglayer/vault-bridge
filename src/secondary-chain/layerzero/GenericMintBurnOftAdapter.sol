// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.0) (secondary-chain/layerzero/GenericMintBurnOftAdapter.sol)

pragma solidity 0.8.29;

// @remind Document (the entire file).

// Main functionality.
import {OFTCoreUpgradeable} from "@layerzerolabs-oft-evm-upgradeable/contracts/oft/OFTCoreUpgradeable.sol";

// Other functionality.
import {ReentrancyGuardTransientUpgradeable} from
    "@openzeppelin-contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
import {InitializationCounterUpgradeable} from "../../etc/InitializationCounterUpgradeable.sol";

// Libraries.
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// External contracts.
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {CustomTokenLayerZero} from "./CustomTokenLayerZero.sol";
import {IFiatTokenV2_2} from "../../etc/IFiatTokenV2_2.sol";

contract GenericMintBurnOftAdapter is
    OFTCoreUpgradeable,
    ReentrancyGuardTransientUpgradeable,
    InitializationCounterUpgradeable
{
    // Libraries.
    using SafeERC20 for IERC20;

    /// @dev Storage of Generic Mint Burn OFT Adapter contract.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:agglayer.vault-bridge.GenericMintBurnOftAdapter.storage
    struct GenericMintBurnOftAdapterStorage {
        IERC20 token;
        bool approvalRequired;
        uint256 secondaryChainBalance;
    }

    /// @dev The storage slot at which Generic Mint Burn OFT Adapter storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("agglayer.vault-bridge.GenericMintBurnOftAdapter.storage")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _GENERIC_MINT_BURN_OFT_ADAPTER_STORAGE =
        hex"6196a3c13e9cb943998087d4ad7ad8150a77d470cfbcc24d7e9aaef9ed589e00";

    // Errors.
    error InvalidToken();
    error InvalidOwner();
    error InsufficientTokenReceived(uint256 receivedValue, uint256 requestedValue);

    // -----================= ::: SETUP ::: =================-----

    /**
     * @dev Constructor for the OFT contract.
     * @param _token The address of the underlying ERC20 token.
     * @param _lzEndpoint The LayerZero endpoint address.
     */
    constructor(address _token, address _lzEndpoint)
        OFTCoreUpgradeable(IERC20Metadata(_token).decimals(), _lzEndpoint)
    {
        _disableInitializers();
    }

    function reinitialize1(address _token, bool _approvalRequired, address _owner, address _delegate)
        external
        reinitializer(_incrementGlobalInitializationCounter(1))
        nonReentrant
    {
        GenericMintBurnOftAdapterStorage storage $ = _getGenericMintBurnOftAdapterStorage();

        // Check the inputs.
        require(_token != address(0), InvalidToken());
        require(_owner != address(0), InvalidOwner());
        require(_delegate != address(0), InvalidDelegate());

        __Ownable_init(_owner);
        __OFTCore_init(_delegate);
        __ReentrancyGuardTransient_init();

        $.token = IERC20(_token);
        $.approvalRequired = _approvalRequired;
    }

    /*
    /// @dev How to add a new reinitializer:
    function reinitialize2()
        external
        reinitializer(_incrementGlobalInitializationCounter(2))
        nonReentrant
    {}
    */

    // @remind Document (the entire function).
    function reinitialize(bytes[] calldata reinitializeData) external {
        bytes4[] memory reinitializeSelectors = new bytes4[](1);

        reinitializeSelectors[0] = this.reinitialize1.selector;

        _reinitialize(reinitializeSelectors, reinitializeData);
    }

    // -----================= ::: STORAGE ::: =================-----

    /// @dev Returns a pointer to the ERC-7201 storage namespace.
    function _getGenericMintBurnOftAdapterStorage() private pure returns (GenericMintBurnOftAdapterStorage storage $) {
        assembly {
            $.slot := _GENERIC_MINT_BURN_OFT_ADAPTER_STORAGE
        }
    }

    // -----================= ::: OFT ADAPTER ::: =================-----

    /**
     * @notice Retrieves the address of the underlying ERC20 token.
     *
     * @return The address of the adapted ERC20 token.
     *
     * @dev In the case of MintBurnOFTAdapter, address(this) and erc20 are NOT the same contract.
     */
    function token() public view returns (address) {
        GenericMintBurnOftAdapterStorage storage $ = _getGenericMintBurnOftAdapterStorage();
        return address($.token);
    }

    /**
     * @notice Indicates whether the OFT contract requires approval of the underlying token to send.
     *
     * @return requiresApproval True if approval is required, false otherwise.
     *
     * @dev In this MintBurnOFTAdapter, approval is NOT required because it uses mint and burn privileges.
     */
    function approvalRequired() external view virtual returns (bool) {
        GenericMintBurnOftAdapterStorage storage $ = _getGenericMintBurnOftAdapterStorage();
        return $.approvalRequired;
    }

    function secondaryChainBalance() external view returns (uint256) {
        GenericMintBurnOftAdapterStorage storage $ = _getGenericMintBurnOftAdapterStorage();
        return $.secondaryChainBalance;
    }

    /**
     * @notice Burns tokens from the sender's balance to prepare for sending.
     *
     * @param _from The address to debit the tokens from.
     * @param _amountLD The amount of tokens to send in local decimals.
     * @param _minAmountLD The minimum amount to send in local decimals.
     * @param _dstEid The destination chain ID.
     *
     * @return amountSentLD The amount sent in local decimals.
     * @return amountReceivedLD The amount received in local decimals on the remote.
     *
     * @dev WARNING: The default OFTAdapter implementation assumes LOSSLESS transfers, i.e., 1 token in, 1 token out.
     *      If the 'innerToken' applies something like a transfer fee, the default will NOT work.
     *      A pre/post balance check will need to be done to calculate the amountReceivedLD.
     */
    function _debit(address _from, uint256 _amountLD, uint256 _minAmountLD, uint32 _dstEid)
        internal
        virtual
        override
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        GenericMintBurnOftAdapterStorage storage $ = _getGenericMintBurnOftAdapterStorage();
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);
        $.secondaryChainBalance -= amountSentLD;
        // Burns tokens from the caller.
        if ($.approvalRequired) {
            _receiveToken(_from, amountSentLD);
            IFiatTokenV2_2(address($.token)).burn(amountSentLD);
        } else {
            CustomTokenLayerZero(address($.token)).burn(_from, amountSentLD);
        }
    }

    /**
     * @notice Mints tokens to the specified address upon receiving them.
     *
     * @param _to The address to credit the tokens to.
     * @param _amountLD The amount of tokens to credit in local decimals.
     *
     * @return amountReceivedLD The amount of tokens actually received in local decimals.
     *
     * @dev WARNING: The default OFTAdapter implementation assumes LOSSLESS transfers, i.e., 1 token in, 1 token out.
     *      If the 'innerToken' applies something like a transfer fee, the default will NOT work.
     *      A pre/post balance check will need to be done to calculate the amountReceivedLD.
     */
    function _credit(address _to, uint256 _amountLD, uint32 /* _srcEid */ )
        internal
        virtual
        override
        returns (uint256 amountReceivedLD)
    {
        GenericMintBurnOftAdapterStorage storage $ = _getGenericMintBurnOftAdapterStorage();
        if (_to == address(0x0)) _to = address(0xdead); // _mint(...) does not support address(0x0)
        // Mints the tokens and transfers to the recipient.
        CustomTokenLayerZero(address($.token)).mint(_to, _amountLD);
        $.secondaryChainBalance += _amountLD;
        // In the case of NON-default OFTAdapter, the amountLD MIGHT not be equal to amountReceivedLD.
        return _amountLD;
    }

    function setTokenAndApprovalRequired(address _token, bool _approvalRequired) external onlyOwner {
        GenericMintBurnOftAdapterStorage storage $ = _getGenericMintBurnOftAdapterStorage();

        // Check the input.
        require(_token != address(0), InvalidToken());
        require(IERC20Metadata(_token).decimals() == IERC20Metadata(address($.token)).decimals(), InvalidToken());

        $.token = IERC20(_token);
        $.approvalRequired = _approvalRequired;
    }

    // -----================= ::: TOKEN ::: =================-----

    /// @notice Transfers the token from an external account to self.
    /// @dev @note CAUTION! This function MUST NOT introduce reentrancy/crossentrancy vulnerabilities.
    function _receiveToken(address from, uint256 value) internal {
        GenericMintBurnOftAdapterStorage storage $ = _getGenericMintBurnOftAdapterStorage();

        // Cache the balance.
        uint256 balanceBefore = $.token.balanceOf(address(this));

        // Transfer.
        // @note IMPORTANT: Make sure the token you are integrating does not enable reentrancy on `transferFrom`.
        $.token.safeTransferFrom(from, address(this), value);

        // Calculate the received amount.
        uint256 receivedValue = $.token.balanceOf(address(this)) - balanceBefore;

        // Check the output.
        require(receivedValue == value, InsufficientTokenReceived(receivedValue, value));
    }
}
