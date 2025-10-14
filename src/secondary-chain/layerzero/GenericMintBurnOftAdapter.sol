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

// External contracts.
import {CustomTokenLayerZero} from "./CustomTokenLayerZero.sol";

contract GenericMintBurnOftAdapter is
    OFTCoreUpgradeable,
    ReentrancyGuardTransientUpgradeable,
    InitializationCounterUpgradeable
{
    /// @dev Storage of Generic Mint Burn OFT Adapter contract.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:agglayer.vault-bridge.GenericMintBurnOftAdapter.storage
    struct GenericMintBurnOftAdapterStorage {
        CustomTokenLayerZero _innerToken;
    }

    /// @dev The storage slot at which Generic Mint Burn OFT Adapter storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("agglayer.vault-bridge.GenericMintBurnOftAdapter.storage")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _GENERIC_MINT_BURN_OFT_ADAPTER_STORAGE =
        hex"6196a3c13e9cb943998087d4ad7ad8150a77d470cfbcc24d7e9aaef9ed589e00";

    // Errors.
    error InvalidToken();
    error InvalidOwner();

    // -----================= ::: SETUP ::: =================-----

    /**
     * @dev Constructor for the OFT contract.
     * @param _token The address of the underlying ERC20 token.
     * @param _lzEndpoint The LayerZero endpoint address.
     */
    constructor(address _token, address _lzEndpoint)
        OFTCoreUpgradeable(CustomTokenLayerZero(_token).decimals(), _lzEndpoint)
    {
        _disableInitializers();
    }

    function reinitialize1(address _token, address _owner, address _delegate)
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

        $._innerToken = CustomTokenLayerZero(_token);
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
        return address($._innerToken);
    }

    /**
     * @notice Indicates whether the OFT contract requires approval of the underlying token to send.
     *
     * @return requiresApproval True if approval is required, false otherwise.
     *
     * @dev In this MintBurnOFTAdapter, approval is NOT required because it uses mint and burn privileges.
     */
    function approvalRequired() external pure virtual returns (bool) {
        return false;
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
        // Burns tokens from the caller.
        $._innerToken.burn(_from, amountSentLD);
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
        $._innerToken.mint(_to, _amountLD);
        // In the case of NON-default OFTAdapter, the amountLD MIGHT not be equal to amountReceivedLD.
        return _amountLD;
    }
}
