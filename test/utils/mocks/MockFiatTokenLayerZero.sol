// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import {GenericCustomTokenLayerZero} from "src/secondary-chain/layerzero/GenericCustomTokenLayerZero.sol";
import {IFiatTokenV2_2} from "src/etc/IFiatTokenV2_2.sol";

/// @title Mock Fiat Token LayerZero
/// @notice A mock implementation that combines CustomTokenLayerZero with IFiatTokenV2_2 interface
contract MockFiatTokenLayerZero is GenericCustomTokenLayerZero, IFiatTokenV2_2 {
    /// @notice Burn tokens from the caller's address (IFiatTokenV2_2 interface)
    /// @param _amount The amount of tokens to burn
    function burn(uint256 _amount) external override(IFiatTokenV2_2) whenNotPaused onlyOftAdapter nonReentrant {
        _burn(_msgSender(), _amount);
    }
}
