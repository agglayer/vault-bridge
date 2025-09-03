// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (secondary-chain/agglayer/vbETH/WethNativeConverterAgglayer.sol)

pragma solidity 0.8.29;

import {GenericNativeConverterAgglayer} from "../../GenericNativeConverterAgglayer.sol";
import {NativeConverterAgglayer} from "../../GenericNativeConverterAgglayer.sol";
import {IFiatTokenV2_2} from "../../../../etc/IFiatTokenV2_2.sol";

// Libraries.
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// @remind Improve documentation.
/// @title vbUSDC Native Converter (Agglayer + Bridged USDC Standard)
/// @author See https://github.com/agglayer/vault-bridge
/// @dev @note CAUTION! `nonMigratableBackingPercentage` must be set to `1e18` (100%) because `migrateBackingToPrimaryChain` is not supported yet.
/// @dev This contract can be upgraded to `GenericNativeConverterAgglayer` after Circle takes over the token.
contract VbUsdcNativeConverterAgglayerBridgedUsdcStandard is GenericNativeConverterAgglayer {
    // Libraries.
    using SafeERC20 for IFiatTokenV2_2;

    // -----================= ::: DEVELOPER ::: =================-----

    // @remind Document (the entire function).
    /// @inheritdoc NativeConverterAgglayer
    function _burnCustomToken(address account, uint256 value) internal virtual override {
        IFiatTokenV2_2 vbUsdc = IFiatTokenV2_2(address(customToken()));

        vbUsdc.safeTransferFrom(account, address(this), value);

        vbUsdc.burn(value);
    }
}
