import { TestVault } from "./TestVault.sol";

// extend TestVault with some IERC4626 snippets
contract VaultMock is TestVault {
    constructor(address _asset) TestVault(_asset) {}
    function maxRedeem(address owner) external view returns (uint256 maxShares) {
        return 42;
    }
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        return shares;
    }
}
