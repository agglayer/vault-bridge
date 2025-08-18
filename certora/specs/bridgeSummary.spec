methods {
    function _.bridgeAsset(uint32,address,uint256 assets ,address,bool,bytes) external => bridge_cvl(assets) expect void; // this is UNSAFE summary.

    function _.claimAsset(
        bytes32[32], bytes32[32], uint256, bytes32, bytes32, 
        uint32, address, uint32, address, uint256, bytes) external => emptyFunc() expect void; // this is UNSAFE summary.

    function _.bridgeMessage(uint32,address,bool,bytes) external => emptyFunc() expect void; // this is UNSAFE summary.

    //other unresolved calls:
    function _._permit(address, uint256, bytes calldata) internal => NONDET; // this is UNSAFE summary.

    unresolved external in _.claimAndRedeem(bytes32[32],bytes32[32],uint256,bytes32,bytes32,address,uint256,address,bytes) => DISPATCH [

    ] default NONDET;
}

ghost mathint totalBridged
{
    init_state axiom totalBridged == 0;
}

function bridge_cvl(uint assets)
{
    totalBridged = totalBridged + assets;
}

function emptyFunc()
{
}