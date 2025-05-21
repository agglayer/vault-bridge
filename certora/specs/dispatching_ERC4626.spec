methods {
    function _.name() external => DISPATCHER(true);
    function _.symbol() external => DISPATCHER(true);
    function _.decimals() external => DISPATCHER(true);
    function _.asset() external => DISPATCHER(true);

    function _.totalSupply() external => DISPATCHER(true);
    // function _.balanceOf(address) external => DISPATCHER(true);
    function _.nonces(address) external => DISPATCHER(true);
    function _.totalAssets() external => DISPATCHER(true);
    // function _.userAssets(address) external => DISPATCHER(true);
    function _.convertToShares(uint256) external => DISPATCHER(true);
    function _.convertToAssets(uint256) external => DISPATCHER(true);
    function _.previewDeposit(uint256) external => DISPATCHER(true);
    function _.previewMint(uint256) external => DISPATCHER(true);
    function _.previewWithdraw(uint256) external => DISPATCHER(true);
    function _.previewRedeem(uint256) external => DISPATCHER(true);
    function _.maxDeposit(address) external => DISPATCHER(true);
    function _.maxMint(address) external => DISPATCHER(true);
    function _.maxWithdraw(address) external => DISPATCHER(true);
    function _.maxRedeem(address) external => DISPATCHER(true);

    function _._callOptionalReturn(address token, bytes memory data) internal => NONDET;
    function _._callOptionalReturnBool(address token, bytes memory data) internal => NONDET;
}