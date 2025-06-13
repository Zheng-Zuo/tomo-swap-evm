// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {HelperConfig, RouterParameters} from "./HelperConfig.s.sol";
import {TomoSwapRouter} from "src/TomoSwapRouter.sol";

contract DeployTomoSwapRouter is Script {
    function run() external returns (TomoSwapRouter, HelperConfig) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        HelperConfig helperConfig = new HelperConfig();
        RouterParameters memory config = helperConfig.getConfig();

        vm.startBroadcast(deployerPrivateKey);
        TomoSwapRouter tomoSwapRouter = new TomoSwapRouter(config);
        vm.stopBroadcast();

        return (tomoSwapRouter, helperConfig);
    }
}
