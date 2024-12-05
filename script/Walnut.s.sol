// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Walnut} from "../src/Walnut.sol";

contract WalnutScript is Script {
    Walnut public walnut;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        walnut = new Walnut(3, 0);
        vm.stopBroadcast();
    }
}
