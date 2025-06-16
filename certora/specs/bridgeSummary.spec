methods {
    function _.bridgeAsset(uint32,address,uint256,address,bool,bytes) external => emptyFunc() expect void; // this is UNSAFE summary.

    function _.claimAsset(
        bytes32[32], bytes32[32], uint256, bytes32, bytes32, 
        uint32, address, uint32, address, uint256, bytes) external => emptyFunc() expect void; // this is UNSAFE summary.

    //other unresolved calls:
    function _._permit(address, uint256, bytes calldata) internal => NONDET; // this is UNSAFE summary.

    unresolved external in _.claimAndRedeem(bytes32[32],bytes32[32],uint256,bytes32,bytes32,address,uint256,address,bytes) => DISPATCH [
        //TokenMock.permit(address,address,uint256,uint256,uint8,bytes32,bytes32),
    ] default NONDET;

}

function emptyFunc()
{
}