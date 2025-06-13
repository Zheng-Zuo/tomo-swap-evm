// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {UniV3PoolQuoteHelper} from "src/tools/UniV3PoolQuoteHelper.sol";

contract DeployUniV3PoolQuoteHelper is Script {
    bytes32 constant SALT = bytes32(uint256(1));

    function run() external returns (UniV3PoolQuoteHelper) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        UniV3PoolQuoteHelper uniV3PoolQuoteHelper = new UniV3PoolQuoteHelper{salt: SALT}();
        vm.stopBroadcast();

        return (uniV3PoolQuoteHelper);
    }
}
