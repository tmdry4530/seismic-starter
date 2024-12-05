/*
 * SPDX-License-Identifier: MIT License
 *
 * You have a walnut with a secret number inside. Every time you shake the
 * walnut, this number increments. Every time you hit the walnut, the shell
 * gets closer to cracking. You can only look at the number once the shell is
 * cracked.
 *
 */
pragma solidity ^0.8.13;

contract Walnut {
    uint256 shell;
    suint256 number;

    constructor(uint256 _shell, suint256 _number) {
        shell = _shell;
        number = _number;
    }

    function hit() public {
        if (shell > 0) shell--;
    }

    function shake() public {
        number++;
    }

    function look() public view requireCracked returns (uint256) {
        return uint256(number);
    }

    modifier requireCracked() {
        if (shell > 0) revert("SHELL_INTACT");
        _;
    }
}
