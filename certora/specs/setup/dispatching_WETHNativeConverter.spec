methods {
    function _.decimals() external => DISPATCHER(true);
    function _.burn(address,uint256) external => DISPATCHER(true);
    function _.transfer(address,uint256) external => DISPATCHER(true);
    function _.transferFrom(address,address,uint256) external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);
    function _.mint(address,uint256) external => DISPATCHER(true);
    function _.approve(address,uint256) external => DISPATCHER(true);
    function _.totalSupply() external => DISPATCHER(true);
    
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
