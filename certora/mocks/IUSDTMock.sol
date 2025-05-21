import { IUSDT } from "src/etc/IUSDT.sol";

contract IUSDTMock is IUSDT {
    function basisPointsRate() external view returns (uint256) {
        return 1;
    }
    function maximumFee() external view returns (uint256) {
        return 1e18;
    }
}