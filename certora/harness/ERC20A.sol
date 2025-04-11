// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.0;
import {ERC20} from "@openzeppelin-contracts/token/ERC20/ERC20.sol";

contract ERC20A is ERC20 {
    constructor() ERC20("Token A", "TOKA") {
    }


    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    function mint(address _to, uint256 _amount) external returns (bool) {
        _mint(_to, _amount);
        return true;
    }

    function DOMAIN_SEPARATOR() external pure returns (bytes32) {
        return keccak256("ERC20A");
    }
}
