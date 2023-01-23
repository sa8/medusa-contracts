// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/dOnlyFans.sol";
import {BaseScript} from "./BaseScript.s.sol";
import {BN254EncryptionOracle as Oracle} from "../src/BN254EncryptionOracle.sol";

contract DeployDOnlyFans is BaseScript {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        new dOnlyFans(Oracle(getOracleInstanceAddress()));
        vm.stopBroadcast();
    }
}
