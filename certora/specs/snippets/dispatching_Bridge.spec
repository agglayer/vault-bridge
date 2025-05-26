methods {
    // to bridge
    function _.networkID() external => NONDET;
    function _.gasTokenAddress() external => NONDET;
    function _.gasTokenNetwork() external => NONDET;
    function _.bridgeAsset(uint32,address,uint256,address,bool,bytes) external => NONDET;
    function _.claimAsset(bytes32[32],bytes32[32],uint256,bytes32,bytes32,uint32,address,uint32,address,uint256,bytes) external => NONDET;
    function _.claimMessage(bytes32[32],bytes32[32],uint256,bytes32,bytes32,uint32,address,uint32,address,uint256,bytes) external => NONDET;
    function _.bridgeMessage(uint32,address,bool,bytes) external => NONDET;

    // from bridge
    function _.onMessageReceived(address,uint32,bytes) external => DISPATCHER(true);
    function _.globalExitRootMap(bytes32) external => NONDET;
}