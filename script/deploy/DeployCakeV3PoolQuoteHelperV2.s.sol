// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {CakeV3PoolQuoteHelperV2} from "src/tools/CakeV3PoolQuoteHelperV2.sol";

contract DeployCakeV3PoolQuoteHelperV2 is Script {
    bytes32 constant SALT = bytes32(uint256(1));

    function run() external returns (CakeV3PoolQuoteHelperV2) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        CakeV3PoolQuoteHelperV2 cakeV3PoolQuoteHelperV2 = new CakeV3PoolQuoteHelperV2{salt: SALT}();
        vm.stopBroadcast();

        return (cakeV3PoolQuoteHelperV2);
    }
}
