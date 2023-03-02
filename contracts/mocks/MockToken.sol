// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IUniswapV2ERC20.sol";

contract MockToken is ERC20, IUniswapV2ERC20 {
    constructor() ERC20("Test", "TST") {
        _mint(msg.sender, 1e36);
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8   v,
        bytes32 r,
        bytes32 s
    ) external override {
        _approve(owner, spender, value);
    }
}