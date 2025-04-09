import { IERC1822Proxiable } from "@openzeppelin-contracts/interfaces/draft-IERC1822.sol";

contract IERC1822ProxiableMock is IERC1822Proxiable {
    bytes32 public constant PROXIABLE_UUID = keccak256("some-random-string");

    function proxiableUUID() external view override returns (bytes32) {
        return PROXIABLE_UUID;
    }
}
