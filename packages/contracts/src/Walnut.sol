// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.13;

contract Walnut {
    uint256 startShell;
    uint256 shell;
    uint256 round;

    suint256 startNumber;
    suint256 number;

    mapping(uint256 => mapping (address => uint256)) hitsPerRound;

    
    event Hit(uint256 indexed round, address indexed hitter, uint256 remaining);
    event Shake(uint256 indexed round, address indexed shaker);
    event Reset(uint256 indexed newRound, uint256 remaining);

    constructor(uint256 _shell, suint256 _number) {
        startShell = _shell;
        shell = _shell;

        startNumber = _number;
        number = _number;

        round = 1;
    }

    function getShell() public view returns (uint256) {
        return shell;
    }

    function hit() public {
        require(shell > 0, "SHELL_ALREADY_CRACKED");
        shell--;
        hitsPerRound[round][msg.sender]++;
        emit Hit(round, msg.sender, shell);
    }

    function shake(suint256 _numShakes) public {
        number+= _numShakes;
        emit Shake(round, msg.sender);
    }

    function reset() public {
        shell = startShell;
        number = startNumber;
        round++; // Move to the next round
        emit Reset(round, shell);
    }


     function look() public view requireCracked onlyContributor returns (uint256) {
        return uint256(number);
    }


    function set_number(suint _number) public {
        number = _number;
    }

    modifier requireCracked() {
        if (shell > 0) revert("SHELL_INTACT");
        _;
    }

    modifier onlyContributor() {
        require(hitsPerRound[round][msg.sender] > 0, "NOT_A_CONTRIBUTOR");
        _;
    }
}
