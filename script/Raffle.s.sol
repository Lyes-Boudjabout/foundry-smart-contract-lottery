// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.8; 

import { Script } from "forge-std/Script.sol";
import { Raffle } from "../src/Raffle.sol";

contract RaffleScript is Script {

    function run() external {
        vm.startBroadcast();
        vm.stopBroadcast();
    }
}