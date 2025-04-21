// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.29;

interface IBridgeL2SovereignChain {
    error InvalidZeroAddress();
    error OriginNetworkInvalid();
    error OnlyBridgeManager();
    error TokenNotMapped();
    error TokenAlreadyUpdated();
    error InvalidSovereignWETHAddressParams();
    error InvalidInitializeFunction();
    error InputArraysLengthMismatch();
    error TokenAlreadyMapped();
    error TokenNotRemapped();
    error WETHRemappingNotSupportedOnGasTokenNetworks();
    error ClaimNotSet();
    error EmergencyStateNotAllowed();

    error DestinationNetworkInvalid();
    error AmountDoesNotMatchMsgValue();
    error MsgValueNotZero();
    error EtherTransferFailed();
    error MessageFailed();
    error GlobalExitRootInvalid();
    error InvalidSmtProof();
    error AlreadyClaimed();
    error NotValidOwner();
    error NotValidSpender();
    error NotValidAmount();
    error NotValidSignature();
    error OnlyRollupManager();
    error NativeTokenIsEther();
    error NoValueInMessagesOnGasTokenNetworks();
    error GasTokenNetworkMustBeZeroOnEther();
    error FailedTokenWrappedDeployment();

    function setMultipleSovereignTokenAddress(
        uint32[] memory originNetworks,
        address[] memory originTokenAddresses,
        address[] memory sovereignTokenAddresses,
        bool[] memory isNotMintable
    ) external;
}
