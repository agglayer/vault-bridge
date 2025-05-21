contract PermitMock {
    // ERC-2612 permit
    function permit(address,address,uint256,uint256,uint8,bytes32,bytes32) public returns (bool) {
        return true;
    }
    // DAI permit
    function permit(address,address,uint256,uint256,bool,uint8,bytes32,bytes32) public returns (bool) {
        return true;
    }
}