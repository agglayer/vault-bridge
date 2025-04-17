import { VaultBridgeToken } from "src/VaultBridgeToken.sol";

contract VaultBridgeTokenMock is VaultBridgeToken {
    function version() external pure returns (string memory) {
        return "0";
    }
    function _assetsAfterTransferFee(uint256 assetsBeforeTransferFee) override internal view returns (uint256) {
        return assetsBeforeTransferFee;
    }
    function _assetsBeforeTransferFee(uint256 minimumAssetsAfterTransferFee) override internal view returns (uint256) {
        return minimumAssetsAfterTransferFee;
    }
}