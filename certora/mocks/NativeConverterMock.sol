import { NativeConverter } from "src/NativeConverter.sol";

contract NativeConverterMock is NativeConverter {
    function version() external pure returns (string memory) {
        return "0";
    }
}