// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.0) (secondary-chain/layerzero/CustomTokenOftExtension.sol)

pragma solidity 0.8.29;

// @remind Document (the entire file).

// Main functionality.
import {CustomToken} from "../CustomToken.sol";
import {OFTCoreUpgradeable} from "@layerzerolabs-oft-evm-upgradeable/contracts/oft/OFTCoreUpgradeable.sol";

abstract contract CustomTokenOftExtension is CustomToken, OFTCoreUpgradeable {
    // Custom role.
    bytes32 public constant OFT_OWNER_ROLE = keccak256("OFT_OWNER_ROLE");

    // Error.
    error OwnableDisabled();

    // -----================= ::: SETUP ::: =================-----

    /**
     * @dev Constructor for the OFT contract.
     * @param _lzEndpoint The LayerZero endpoint address.
     */
    constructor(address _lzEndpoint) OFTCoreUpgradeable(decimals(), _lzEndpoint) {}

    /**
     * @dev Initializes the OFT with the provided delegate.
     * @param _delegate The delegate capable of making OApp configurations inside of the endpoint.
     *
     * @dev The delegate typically should be set as the owner of the contract.
     */
    function __CustomTokenOftExtension_init2_ext1(address _owner, address _delegate)
        internal
        onlyInitializing
        incrementsExtensionInitializationCounter(2, Extension.OFT, 1)
    {
        __OFTCore_init(_delegate);

        _grantRole(OFT_OWNER_ROLE, _owner);
    }

    /*
    /// @dev How to add a new ext step:
    function __CustomTokenOftExtension_initX_ext2()
        internal
        onlyInitializing
        incrementsExtensionInitializationCounter(X, Extension.OFT, 2)
    {}
    */

    function _CUSTOM_TOKEN_OFT_EXTENSION_INIT_2_EXT_1_COMPATIBLE() internal pure virtual;

    // -----================= ::: OFT ::: =================-----

    /**
     * @dev Retrieves the address of the underlying ERC20 implementation.
     * @return The address of the OFT token.
     *
     * @dev In the case of OFT, address(this) and erc20 are the same contract.
     */
    function token() public view returns (address) {
        return address(this);
    }

    /**
     * @notice Indicates whether the OFT contract requires approval of the 'token()' to send.
     * @return requiresApproval Needs approval of the underlying token implementation.
     *
     * @dev In the case of OFT where the contract IS the token, approval is NOT required.
     */
    function approvalRequired() external pure virtual returns (bool) {
        return false;
    }

    /**
     * @dev Burns tokens from the sender's specified balance.
     * @param _from The address to debit the tokens from.
     * @param _amountLD The amount of tokens to send in local decimals.
     * @param _minAmountLD The minimum amount to send in local decimals.
     * @param _dstEid The destination chain ID.
     * @return amountSentLD The amount sent in local decimals.
     * @return amountReceivedLD The amount received in local decimals on the remote.
     */
    function _debit(address _from, uint256 _amountLD, uint256 _minAmountLD, uint32 _dstEid)
        internal
        virtual
        override
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);

        // @dev In NON-default OFT, amountSentLD could be 100, with a 10% fee, the amountReceivedLD amount is 90,
        // therefore amountSentLD CAN differ from amountReceivedLD.

        // @dev Default OFT burns on src.
        _burn(_from, amountSentLD);
    }

    /**
     * @dev Credits tokens to the specified address.
     * @param _to The address to credit the tokens to.
     * @param _amountLD The amount of tokens to credit in local decimals.
     * @dev _srcEid The source chain ID.
     * @return amountReceivedLD The amount of tokens ACTUALLY received in local decimals.
     */
    function _credit(address _to, uint256 _amountLD, uint32 /*_srcEid*/ )
        internal
        virtual
        override
        returns (uint256 amountReceivedLD)
    {
        if (_to == address(0x0)) _to = address(0xdead); // _mint(...) does not support address(0x0)
        // @dev Default OFT mints on dst.
        _mint(_to, _amountLD);
        // @dev In the case of NON-default OFT, the _amountLD MIGHT not be == amountReceivedLD.
        return _amountLD;
    }

    // -----================= ::: OWNABLE ::: =================-----

    function owner() public pure override returns (address) {
        return address(0);
    }

    function _checkOwner() internal view override {
        _checkRole(OFT_OWNER_ROLE);
    }

    function renounceOwnership() public pure override {
        revert OwnableDisabled();
    }

    function transferOwnership(address) public pure override {
        revert OwnableDisabled();
    }

    function _transferOwnership(address) internal pure override {
        revert OwnableDisabled();
    }
}
