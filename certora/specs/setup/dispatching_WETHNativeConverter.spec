methods {
    // TODO: not sure which implementation to use here
    //unresolved external in WETHNativeConverter.convertWithPermit(uint256,address,bytes) => DISPATCH [
    //    _.permit(address,address,uint256,uint256,uint8,bytes32,bytes32),
    //    _.permit(address,address,uint256,uint256,bool,uint8,bytes32,bytes32),
    //] default HAVOC_ECF;

    // dispatch to ILxLyBridge
    function _.networkID() external => DISPATCHER(true);
    function _.bridgeAsset(
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        address token,
        bool forceUpdateGlobalExitRoot,
        bytes permitData
    ) external => DISPATCHER(true);
    function _.claimAsset(
        bytes32[32] smtProofLocalExitRoot,
        bytes32[32] smtProofRollupExitRoot,
        uint256 globalIndex,
        bytes32 mainnetExitRoot,
        bytes32 rollupExitRoot,
        uint32 originNetwork,
        address originTokenAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        bytes metadata
    ) external => DISPATCHER(true);
    function _.claimMessage(
        bytes32[32] smtProofLocalExitRoot,
        bytes32[32] smtProofRollupExitRoot,
        uint256 globalIndex,
        bytes32 mainnetExitRoot,
        bytes32 rollupExitRoot,
        uint32 originNetwork,
        address originAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        bytes metadata
    ) external => DISPATCHER(true);
    function _.bridgeMessage(
        uint32 destinationNetwork,
        address destinationAddress,
        bool forceUpdateGlobalExitRoot,
        bytes metadata
    ) external => DISPATCHER(true);
    function _.wrappedAddressIsNotMintable(address wrappedAddress) external => DISPATCHER(true);
}
