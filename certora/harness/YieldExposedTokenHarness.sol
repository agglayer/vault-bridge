import {YieldExposedToken} from "src/YieldExposedToken.sol";
import {IERC20Plus} from "src/interfaces/IERC20Plus.sol";
import {IERC4626} from "@openzeppelin-contracts/interfaces/IERC4626.sol";


contract YieldExposedTokenHarness is YieldExposedToken {
    IERC20Plus _ierc20Token;
    IERC4626 _vault;

    function token() override public view returns (IERC20Plus) {
        return _ierc20Token;
    }
    function yieldGeneratingVault() override public view returns (IERC4626) {
        return _vault;
    }
}
