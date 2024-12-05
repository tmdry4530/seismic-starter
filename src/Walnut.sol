// SPDX-License-Identifier: MIT License
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
