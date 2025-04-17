import { CustomToken } from "src/CustomToken.sol";

contract CustomTokenMock is CustomToken {
    function version() external pure returns (string memory) {
        return "0";
    }
}