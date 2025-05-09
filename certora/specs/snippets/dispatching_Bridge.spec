methods {
    function _.bridgeAsset(uint32,address,uint256,address,bool,bytes) external => DISPATCHER(true);
    function _.bridgeMessage(uint32,address,bool,bytes) external => DISPATCHER(true);
    function _.claimAsset(bytes32[32],bytes32[32],uint256,bytes32,bytes32,uint32,address,uint32,address,uint256,bytes) external => DISPATCHER(true);
    function _.networkID() external => DISPATCHER(true);
    function _.updateExitRoot(bytes32) external => DISPATCHER(true);
}