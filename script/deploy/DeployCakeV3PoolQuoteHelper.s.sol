// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {CakeV3PoolQuoteHelper} from "src/tools/CakeV3PoolQuoteHelper.sol";

contract DeployCakeV3PoolQuoteHelper is Script {
    bytes32 constant SALT = bytes32(uint256(1));

    function run() external returns (CakeV3PoolQuoteHelper) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        CakeV3PoolQuoteHelper cakeV3PoolQuoteHelper = new CakeV3PoolQuoteHelper{salt: SALT}();
        vm.stopBroadcast();

        return (cakeV3PoolQuoteHelper);
    }
}
