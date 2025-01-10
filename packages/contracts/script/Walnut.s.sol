// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Walnut} from "../src/Walnut.sol";

contract WalnutScript is Script {
    Walnut public walnut;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVKEY");

        vm.startBroadcast(deployerPrivateKey);
        walnut = new Walnut(2, suint256(0));
        vm.stopBroadcast();
    }
}
