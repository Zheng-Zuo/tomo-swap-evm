// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {RouterParameters} from "src/base/RouterImmutables.sol";

abstract contract CodeConstants {
    uint256 public constant ETH_CHAIN_ID = 1;
    uint256 public constant BNB_CHAIN_ID = 56;
    uint256 public constant BASE_CHAIN_ID = 8453;
    uint256 public constant ARB_CHAIN_ID = 42161;
    uint256 public constant OP_CHAIN_ID = 10;
    uint256 public constant POLYGON_CHAIN_ID = 137;
    uint256 public constant AVAX_CHAIN_ID = 43114;
    uint256 public constant CELO_CHAIN_ID = 42220;
    uint256 public constant BLAST_CHAIN_ID = 81457;
    uint256 public constant ZKSYNC_CHAIN_ID = 324;
    uint256 public constant ZORA_CHAIN_ID = 7777777;
    uint256 public constant WC_CHAIN_ID = 480;
    uint256 public constant BERACHAIN_CHAIN_ID = 80094;
    uint256 public constant DOGE_OS_TESTNET_CHAIN_ID = 221122420;
}

contract HelperConfig is CodeConstants, Script {
    error HelperConfigInvalidChainId();
    mapping(uint256 chainId => RouterParameters) public networkConfigs;

    constructor() {
        networkConfigs[ETH_CHAIN_ID] = getEthConfig();
        networkConfigs[BNB_CHAIN_ID] = getBnbConfig();
        networkConfigs[BASE_CHAIN_ID] = getBaseConfig();
        networkConfigs[ARB_CHAIN_ID] = getArbConfig();
        networkConfigs[OP_CHAIN_ID] = getOpConfig();
        networkConfigs[POLYGON_CHAIN_ID] = getPolygonConfig();
        networkConfigs[AVAX_CHAIN_ID] = getAvaxConfig();
        networkConfigs[CELO_CHAIN_ID] = getCeloConfig();
        networkConfigs[BLAST_CHAIN_ID] = getBlastConfig();
        networkConfigs[ZKSYNC_CHAIN_ID] = getZkSyncConfig();
        networkConfigs[ZORA_CHAIN_ID] = getZoraConfig();
        networkConfigs[WC_CHAIN_ID] = getWorldChainConfig();
        networkConfigs[BERACHAIN_CHAIN_ID] = getBeraChainConfig();
        networkConfigs[DOGE_OS_TESTNET_CHAIN_ID] = getDogeOsTestnetConfig();
    }

    function getConfig() public view returns (RouterParameters memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public view returns (RouterParameters memory) {
        return networkConfigs[chainId];
    }

    function getBnbConfig() public pure returns (RouterParameters memory bnbNetworkConfig) {
        bnbNetworkConfig = RouterParameters({
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            weth9: 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c, // WBNB
            uniV2Factory: 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6,
            uniV3Factory: 0xdB1d10011AD0Ff90774D0C6Bb92e5C5c8b4461F7,
            uniPairInitCodeHash: 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f,
            uniPoolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54,
            cakeV2Factory: 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73,
            cakeV3Factory: 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865,
            cakeV3Deployer: 0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9,
            cakePairInitCodeHash: 0x00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5, // https://bscscan.deth.net/address/0x13f4EA83D0bd40E75C8222255bc855a974568Dd4#code
            cakePoolInitCodeHash: 0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2, // https://bscscan.deth.net/address/0x13f4EA83D0bd40E75C8222255bc855a974568Dd4#code
            cakeStableFactory: 0x25a55f9f2279A54951133D503490342b50E5cd15, // https://bscscan.com/address/0x1a0a18ac4becddbd6389559687d1a73d8927e416#readContract
            cakeStableInfo: 0xf3A6938945E68193271Cad8d6f79B1f878b16Eb1, // https://bscscan.com/address/0x1a0a18ac4becddbd6389559687d1a73d8927e416#readContract
            sushiV2Factory: 0xc35DADB65012eC5796536bD9864eD8773aBc74C4, // https://github.com/sushiswap/v2-core/blob/master/deployments/bsc/UniswapV2Factory.json
            sushiV3Factory: 0x126555dd55a39328F69400d6aE4F782Bd4C34ABb, // https://github.com/sushiswap/v3-core/blob/master/deployments/bsc/UniswapV3Factory.json
            sushiPairInitCodeHash: 0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303, // https://bscscan.deth.net/address/0x1b02da8cb0d097eb8d57a175b88c7d8b47997506#code
            sushiPoolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54 // https://bscscan.deth.net/address/0x909662a99605382db1e8d69cc1f182bb577d9038#code
        });
    }

    function getEthConfig() public pure returns (RouterParameters memory ethNetworkConfig) {
        ethNetworkConfig = RouterParameters({
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            weth9: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // WETH
            uniV2Factory: 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f, // https://docs.uniswap.org/contracts/v2/reference/smart-contracts/v2-deployments
            uniV3Factory: 0x1F98431c8aD98523631AE4a59f267346ea31F984, // https://docs.uniswap.org/contracts/v3/reference/deployments/ethereum-deployments
            uniPairInitCodeHash: 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f,
            uniPoolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54,
            cakeV2Factory: 0x1097053Fd2ea711dad45caCcc45EfF7548fCB362,
            cakeV3Factory: 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865,
            cakeV3Deployer: 0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9,
            cakePairInitCodeHash: 0x57224589c67f3f30a6b0d7a1b54cf3153ab84563bc609ef41dfb34f8b2974d2d, // https://etherscan.deth.net/address/0x13f4ea83d0bd40e75c8222255bc855a974568dd4#code
            cakePoolInitCodeHash: 0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2, // https://etherscan.deth.net/address/0x13f4ea83d0bd40e75c8222255bc855a974568dd4#code
            cakeStableFactory: address(0), // only on BSC
            cakeStableInfo: address(0), // only on BSC
            sushiV2Factory: 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac, // https://github.com/sushiswap/v2-core/blob/master/deployments/ethereum/UniswapV2Factory.json
            sushiV3Factory: 0xbACEB8eC6b9355Dfc0269C18bac9d6E2Bdc29C4F, // https://github.com/sushiswap/v3-core/blob/master/deployments/ethereum/UniswapV3Factory.json
            sushiPairInitCodeHash: 0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303, // https://etherscan.deth.net/address/0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F
            sushiPoolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54 // https://etherscan.deth.net/address/0x2E6cd2d30aa43f40aa81619ff4b6E0a41479B13F 
        });
    }

    function getBaseConfig() public pure returns (RouterParameters memory baseNetworkConfig) {
        baseNetworkConfig = RouterParameters({
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            weth9: 0x4200000000000000000000000000000000000006, // WETH
            uniV2Factory: 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6, // https://docs.uniswap.org/contracts/v2/reference/smart-contracts/v2-deployments
            uniV3Factory: 0x33128a8fC17869897dcE68Ed026d694621f6FDfD, // https://docs.uniswap.org/contracts/v3/reference/deployments/ethereum-deployments
            uniPairInitCodeHash: 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f, // https://basescan.deth.net/address/0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24#code
            uniPoolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54,
            cakeV2Factory: 0x02a84c1b3BBD7401a5f7fa98a384EBC70bB5749E, // https://developer.pancakeswap.finance/contracts/v2/factory-v2
            cakeV3Factory: 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865, // https://developer.pancakeswap.finance/contracts/v3/addresses
            cakeV3Deployer: 0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9, // https://developer.pancakeswap.finance/contracts/v3/addresses
            cakePairInitCodeHash: 0x57224589c67f3f30a6b0d7a1b54cf3153ab84563bc609ef41dfb34f8b2974d2d, // https://basescan.deth.net/address/0x8cFe327CEc66d1C090Dd72bd0FF11d690C33a2Eb
            cakePoolInitCodeHash: 0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2, // 
            cakeStableFactory: address(0), // only on BSC
            cakeStableInfo: address(0), // only on BSC
            sushiV2Factory: 0x71524B4f93c58fcbF659783284E38825f0622859, // https://github.com/sushiswap/v2-core/blob/master/deployments/base/UniswapV2Factory.json
            sushiV3Factory: 0xc35DADB65012eC5796536bD9864eD8773aBc74C4, // https://github.com/sushiswap/v3-core/blob/master/deployments/base/UniswapV3Factory.json
            sushiPairInitCodeHash: 0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303, // https://basescan.deth.net/address/0x6BDED42c6DA8FBf0d2bA55B2fa120C5e0c8D7891#code
            sushiPoolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54 // https://basescan.deth.net/address/0xFB7eF66a7e61224DD6FcD0D7d9C3be5C8B049b9f
        });
    }

    function getArbConfig() public pure returns (RouterParameters memory arbNetworkConfig) {
        arbNetworkConfig = RouterParameters({
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            weth9: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, // WETH
            uniV2Factory: 0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9, // https://docs.uniswap.org/contracts/v2/reference/smart-contracts/v2-deployments
            uniV3Factory: 0x1F98431c8aD98523631AE4a59f267346ea31F984, // https://docs.uniswap.org/contracts/v3/reference/deployments/arbitrum-deployments
            uniPairInitCodeHash: 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f, // https://arbiscan.deth.net/address/0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24#code
            uniPoolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54, // https://arbiscan.deth.net/address/0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45#code
            cakeV2Factory: 0x02a84c1b3BBD7401a5f7fa98a384EBC70bB5749E, // https://developer.pancakeswap.finance/contracts/v2/factory-v2
            cakeV3Factory: 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865, // https://developer.pancakeswap.finance/contracts/v3/addresses
            cakeV3Deployer: 0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9, // https://developer.pancakeswap.finance/contracts/v3/addresses
            cakePairInitCodeHash: 0x57224589c67f3f30a6b0d7a1b54cf3153ab84563bc609ef41dfb34f8b2974d2d, // https://arbiscan.deth.net/address/0x8cFe327CEc66d1C090Dd72bd0FF11d690C33a2Eb#code
            cakePoolInitCodeHash: 0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2, // https://arbiscan.deth.net/address/0x1b81D678ffb9C0263b24A97847620C99d213eB14#code
            cakeStableFactory: address(0), // only on BSC
            cakeStableInfo: address(0), // only on BSC
            sushiV2Factory: 0xc35DADB65012eC5796536bD9864eD8773aBc74C4, // https://github.com/sushiswap/v2-core/blob/master/deployments/arbitrum/UniswapV2Factory.json
            sushiV3Factory: 0x1af415a1EbA07a4986a52B6f2e7dE7003D82231e, // https://github.com/sushiswap/v3-core/blob/master/deployments/arbitrum/UniswapV3Factory.json
            sushiPairInitCodeHash: 0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303, // https://arbiscan.deth.net/address/0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506#code
            sushiPoolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54 // https://arbiscan.deth.net/address/0x8A21F6768C1f8075791D08546Dadf6daA0bE820c#code
        });
    }

    function getOpConfig() public pure returns (RouterParameters memory opNetworkConfig) {
        opNetworkConfig = RouterParameters({
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            weth9: 0x4200000000000000000000000000000000000006, // WETH
            uniV2Factory: 0x0c3c1c532F1e39EdF36BE9Fe0bE1410313E074Bf, // https://docs.uniswap.org/contracts/v2/reference/smart-contracts/v2-deployments
            uniV3Factory: 0x1F98431c8aD98523631AE4a59f267346ea31F984, // https://docs.uniswap.org/contracts/v3/reference/deployments/optimism-deployments
            uniPairInitCodeHash: 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f, // https://optimistic.etherscan.deth.net/address/0x4A7b5Da61326A6379179b40d00F57E5bbDC962c2#code
            uniPoolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54, // https://optimistic.etherscan.deth.net/address/0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45#code
            cakeV2Factory: address(0), // 
            cakeV3Factory: address(0), // 
            cakeV3Deployer: address(0), // 
            cakePairInitCodeHash: bytes32(0), // 
            cakePoolInitCodeHash: bytes32(0), // 
            cakeStableFactory: address(0), // only on BSC
            cakeStableInfo: address(0), // only on BSC
            sushiV2Factory: 0xFbc12984689e5f15626Bad03Ad60160Fe98B303C, // https://github.com/sushiswap/v2-core/blob/master/deployments/optimism/UniswapV2Factory.json
            sushiV3Factory: 0x9c6522117e2ed1fE5bdb72bb0eD5E3f2bdE7DBe0, // https://github.com/sushiswap/v3-core/blob/master/deployments/optimism/UniswapV3Factory.json
            sushiPairInitCodeHash: 0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303, // https://optimistic.etherscan.deth.net/address/0x2ABf469074dc0b54d793850807E6eb5Faf2625b1
            sushiPoolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54 // https://optimistic.etherscan.deth.net/address/0x8c32Fd078B89Eccb06B40289A539D84A4aA9FDA6#code
        });
    }

    function getPolygonConfig() public pure returns (RouterParameters memory polygonNetworkConfig) {
        polygonNetworkConfig = RouterParameters({
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            weth9: 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270, // WMATIC
            uniV2Factory: 0x9e5A52f57b3038F1B8EeE45F28b3C1967e22799C, // https://docs.uniswap.org/contracts/v2/reference/smart-contracts/v2-deployments
            uniV3Factory: 0x1F98431c8aD98523631AE4a59f267346ea31F984, // https://docs.uniswap.org/contracts/v3/reference/deployments/polygon-deployments
            uniPairInitCodeHash: 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f, // https://polygonscan.deth.net/address/0xedf6066a2b290C185783862C7F4776A2C8077AD1#code
            uniPoolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54, // https://polygonscan.deth.net/address/0xE592427A0AEce92De3Edee1F18E0157C05861564#code
            cakeV2Factory: address(0), // 
            cakeV3Factory: address(0), // 
            cakeV3Deployer: address(0), // 
            cakePairInitCodeHash: bytes32(0), // 
            cakePoolInitCodeHash: bytes32(0), // 
            cakeStableFactory: address(0), // only on BSC
            cakeStableInfo: address(0), // only on BSC
            sushiV2Factory: address(0), // 
            sushiV3Factory: address(0), // 
            sushiPairInitCodeHash: bytes32(0), // 
            sushiPoolInitCodeHash: bytes32(0) // 
        });
    }

    function getAvaxConfig() public pure returns (RouterParameters memory avaxNetworkConfig) {
        avaxNetworkConfig = RouterParameters({
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            weth9: 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7, // WAVAX
            uniV2Factory: 0x9e5A52f57b3038F1B8EeE45F28b3C1967e22799C, // https://docs.uniswap.org/contracts/v2/reference/smart-contracts/v2-deployments
            uniV3Factory: 0x740b1c1de25031C31FF4fC9A62f554A55cdC1baD, // https://docs.uniswap.org/contracts/v3/reference/deployments/avax-deployments
            uniPairInitCodeHash: 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f, // https://avascan.info/blockchain/all/address/0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24/contract
            uniPoolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54, // https://avascan.info/blockchain/all/address/0xbb00FF08d01D300023C629E8fFfFcb65A5a578cE/contract
            cakeV2Factory: address(0), // 
            cakeV3Factory: address(0), // 
            cakeV3Deployer: address(0), // 
            cakePairInitCodeHash: bytes32(0), // 
            cakePoolInitCodeHash: bytes32(0), // 
            cakeStableFactory: address(0), // only on BSC
            cakeStableInfo: address(0), // only on BSC
            sushiV2Factory: 0xc35DADB65012eC5796536bD9864eD8773aBc74C4, // https://github.com/sushiswap/v2-core/blob/master/deployments/avalanche/UniswapV2Factory.json
            sushiV3Factory: 0x3e603C14aF37EBdaD31709C4f848Fc6aD5BEc715, // https://github.com/sushiswap/v3-core/blob/master/deployments/avalanche/UniswapV3Factory.json
            sushiPairInitCodeHash: 0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303, // https://avascan.info/blockchain/all/address/0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506/contract
            sushiPoolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54 // https://avascan.info/blockchain/all/address/0x8E4638eefee96732C56291fBF48bBB98725c6b31/contract
        });
    }

    function getCeloConfig() public pure returns (RouterParameters memory celoNetworkConfig) {
        celoNetworkConfig = RouterParameters({
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            weth9: address(0), // 
            uniV2Factory: 0x79a530c8e2fA8748B7B40dd3629C0520c2cCf03f, // 
            uniV3Factory: 0xAfE208a311B21f13EF87E33A90049fC17A7acDEc, // https://docs.uniswap.org/contracts/v3/reference/deployments/celo-deployments
            uniPairInitCodeHash: 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f, // 
            uniPoolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54, // 
            cakeV2Factory: address(0), // 
            cakeV3Factory: address(0), // 
            cakeV3Deployer: address(0), // 
            cakePairInitCodeHash: bytes32(0), // 
            cakePoolInitCodeHash: bytes32(0), // 
            cakeStableFactory: address(0), // only on BSC
            cakeStableInfo: address(0), // only on BSC
            sushiV2Factory: 0xc35DADB65012eC5796536bD9864eD8773aBc74C4, // https://github.com/sushiswap/v2-core/blob/master/deployments/celo/UniswapV2Factory.json
            sushiV3Factory: 0x93395129bd3fcf49d95730D3C2737c17990fF328, // https://github.com/sushiswap/v3-core/blob/master/deployments/celo/UniswapV3Factory.json
            sushiPairInitCodeHash: 0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303, // 
            sushiPoolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54 // 
        });
    }

    function getBlastConfig() public pure returns (RouterParameters memory blastNetworkConfig) {
        blastNetworkConfig = RouterParameters({
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            weth9: 0x4300000000000000000000000000000000000004, // 
            uniV2Factory: 0x5C346464d33F90bABaf70dB6388507CC889C1070, // 
            uniV3Factory: 0x792edAdE80af5fC680d96a2eD80A44247D2Cf6Fd, // 
            uniPairInitCodeHash: 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f, // 
            uniPoolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54, // 
            cakeV2Factory: address(0), // 
            cakeV3Factory: address(0), // 
            cakeV3Deployer: address(0), // 
            cakePairInitCodeHash: bytes32(0), // 
            cakePoolInitCodeHash: bytes32(0), // 
            cakeStableFactory: address(0), // only on BSC
            cakeStableInfo: address(0), // only on BSC
            sushiV2Factory: 0x42Fa929fc636e657AC568C0b5Cf38E203b67aC2b, // 
            sushiV3Factory: 0x7680D4B43f3d1d54d6cfEeB2169463bFa7a6cf0d, // 
            sushiPairInitCodeHash: 0x0871b2842bc5ad89183710ec5587b7e7e285f1212e8960a4941335bab95cf6af, // 
            sushiPoolInitCodeHash: 0x8e13daee7f5a62e37e71bf852bcd44e7d16b90617ed2b17c24c2ee62411c5bae // 
        });
    }

    function getZkSyncConfig() public pure returns (RouterParameters memory zkSyncNetworkConfig) {
        zkSyncNetworkConfig = RouterParameters({
            permit2: 0x0000000000225e31D15943971F47aD3022F714Fa,
            weth9: 0x5AEa5775959fBC2557Cc8789bC1bf90A239D9a91, // 
            uniV2Factory: address(0), // 
            uniV3Factory: 0x8FdA5a7a8dCA67BBcDd10F02Fa0649A937215422, // 
            uniPairInitCodeHash: bytes32(0), // 
            uniPoolInitCodeHash: 0x010013f177ea1fcbc4520f9a3ca7cd2d1d77959e05aa66484027cb38e712aeed, // 
            cakeV2Factory: 0xd03D8D566183F0086d8D09A84E1e30b58Dd5619d, // 
            cakeV3Factory: 0x1BB72E0CbbEA93c08f535fc7856E0338D7F7a8aB, // 
            cakeV3Deployer: 0x7f71382044A6a62595D5D357fE75CA8199123aD6, // 
            cakePairInitCodeHash: 0x0100045707a42494392b3558029b9869f865ff9df8f375dc1bf20b0555093f43, // 
            cakePoolInitCodeHash: 0x01001487a7c45b21c52a0bc0558bf48d897d14792f1d0cc82733c8271d069178, // 
            cakeStableFactory: address(0), // only on BSC
            cakeStableInfo: address(0), // only on BSC
            sushiV2Factory: address(0), // 
            sushiV3Factory: address(0), // 
            sushiPairInitCodeHash: bytes32(0), // 
            sushiPoolInitCodeHash: bytes32(0) // 
        });
    }

    function getZoraConfig() public pure returns (RouterParameters memory zoraNetworkConfig) {
        zoraNetworkConfig = RouterParameters({
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            weth9: 0x4200000000000000000000000000000000000006, // 
            uniV2Factory: 0x0F797dC7efaEA995bB916f268D919d0a1950eE3C, // 
            uniV3Factory: 0x7145F8aeef1f6510E92164038E1B6F8cB2c42Cbb, // 
            uniPairInitCodeHash: 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f, // 
            uniPoolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54, // 
            cakeV2Factory: address(0), // 
            cakeV3Factory: address(0), // 
            cakeV3Deployer: address(0), // 
            cakePairInitCodeHash: bytes32(0), // 
            cakePoolInitCodeHash: bytes32(0), // 
            cakeStableFactory: address(0), // only on BSC
            cakeStableInfo: address(0), // only on BSC
            sushiV2Factory: address(0), // 
            sushiV3Factory: address(0), // 
            sushiPairInitCodeHash: bytes32(0), // 
            sushiPoolInitCodeHash: bytes32(0) // 
        });
    }

    function getWorldChainConfig() public pure returns (RouterParameters memory worldChainNetworkConfig) {
        worldChainNetworkConfig = RouterParameters({
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            weth9: 0x4200000000000000000000000000000000000006, // 
            uniV2Factory: 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f, // 
            uniV3Factory: 0x7a5028BDa40e7B173C278C5342087826455ea25a, // 
            uniPairInitCodeHash: 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f, // 
            uniPoolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54, // 
            cakeV2Factory: address(0), // 
            cakeV3Factory: address(0), // 
            cakeV3Deployer: address(0), // 
            cakePairInitCodeHash: bytes32(0), // 
            cakePoolInitCodeHash: bytes32(0), // 
            cakeStableFactory: address(0), // only on BSC
            cakeStableInfo: address(0), // only on BSC
            sushiV2Factory: address(0), // 
            sushiV3Factory: address(0), // 
            sushiPairInitCodeHash: bytes32(0), // 
            sushiPoolInitCodeHash: bytes32(0) // 
        });
    }

    function getBeraChainConfig() public pure returns (RouterParameters memory beraChainNetworkConfig) {
        beraChainNetworkConfig = RouterParameters({
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            weth9: 0x6969696969696969696969696969696969696969, // 
            uniV2Factory: 0x5e705e184D233FF2A7cb1553793464a9d0C3028F, // 
            uniV3Factory: 0xD84CBf0B02636E7f53dB9E5e45A616E05d710990, // 
            uniPairInitCodeHash: 0x190cc7bdd70507a793b76d7bc2bf03e1866989ca7881812e0e1947b23e099534, // 
            uniPoolInitCodeHash: 0xd8e2091bc519b509176fc39aeb148cc8444418d3ce260820edc44e806c2c2339, // 
            cakeV2Factory: address(0), // 
            cakeV3Factory: address(0), // 
            cakeV3Deployer: address(0), // 
            cakePairInitCodeHash: bytes32(0), // 
            cakePoolInitCodeHash: bytes32(0), // 
            cakeStableFactory: address(0), // only on BSC
            cakeStableInfo: address(0), // only on BSC
            sushiV2Factory: address(0), // 
            sushiV3Factory: address(0), // 
            sushiPairInitCodeHash: bytes32(0), // 
            sushiPoolInitCodeHash: bytes32(0) // 
        });
    }

    function getDogeOsTestnetConfig() public pure returns (RouterParameters memory dogeOsTestnetConfig) {
        dogeOsTestnetConfig = RouterParameters({
            permit2: 0x5d47029371233B4925824fA0EeF8F3B4195bbac4,
            weth9: 0xcc8269b15fB01Fe88B8728708A0e3dAe75f7338a, // 
            uniV2Factory: address(0), // 
            uniV3Factory: 0xb7C0817Dd23DE89E4204502dd2C2EF7F57d3A3B8, // 
            uniPairInitCodeHash: bytes32(0), // 
            uniPoolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54, // 
            cakeV2Factory: address(0), // 
            cakeV3Factory: address(0), // 
            cakeV3Deployer: address(0), // 
            cakePairInitCodeHash: bytes32(0), // 
            cakePoolInitCodeHash: bytes32(0), // 
            cakeStableFactory: address(0), // only on BSC
            cakeStableInfo: address(0), // only on BSC
            sushiV2Factory: address(0), // 
            sushiV3Factory: address(0), // 
            sushiPairInitCodeHash: bytes32(0), // 
            sushiPoolInitCodeHash: bytes32(0) // 
        });
    }
}
