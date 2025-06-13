// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

struct RouterParameters {
    address permit2;
    address weth9;
    address uniV2Factory;
    address uniV3Factory;
    bytes32 uniPairInitCodeHash;
    bytes32 uniPoolInitCodeHash;
    address cakeV2Factory;
    address cakeV3Factory;
    address cakeV3Deployer;
    bytes32 cakePairInitCodeHash;
    bytes32 cakePoolInitCodeHash;
    address cakeStableFactory;
    address cakeStableInfo;
    address sushiV2Factory;
    address sushiV3Factory;
    bytes32 sushiPairInitCodeHash;
    bytes32 sushiPoolInitCodeHash;
}
