-include .env

.PHONY: all clean remove install build format anvil

all: clean build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install foundry-rs/forge-std@v1.9.4 --no-commit && forge install OpenZeppelin/openzeppelin-contracts@v5.1.0 --no-commit && forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v5.1.0 --no-commit && forge install Uniswap/v2-core@v1.0.1 --no-commit && forge install Uniswap/v2-periphery --no-commit && forge install Uniswap/v3-core --no-commit && forge install Uniswap/v3-periphery --no-commit && forge install Uniswap/permit2 --no-commit && forge install Uniswap/universal-router --no-commit && forge install Uniswap/solidity-lib@v2.1.0 --no-commit && forge install transmissions11/solmate --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit && forge install Cyfrin/foundry-devops@0.2.3 --no-commit && forge install safe-global/safe-smart-account@v1.4.1-3 --no-commit && forge install dmfxyz/murky --no-commit && forge install eth-infinitism/account-abstraction@v0.7.0 --no-commit && forge install aave-dao/aave-v3-origin@v3.1.0 --no-commit

build:; forge build

format :; forge fmt

anvil :; anvil --steps-tracing --block-time 1

deploy-router-bsc:; forge script script/deploy/DeployTomoSwapRouter.s.sol:DeployTomoSwapRouter --rpc-url ${BSC_RPC_URL} --broadcast --verify

cake-v2-multi-hop-swap-wrap:; forge script script/Interactions.s.sol:CakeV2MultiHopSwapWrap --rpc-url ${BSC_RPC_URL} --broadcast

cake-v2-multi-hop-swap-unwrap:; forge script script/Interactions.s.sol:CakeV2MultiHopSwapUnwrap --rpc-url ${BSC_RPC_URL} --broadcast

cake-v3-multi-hop-swap-wrap:; forge script script/Interactions.s.sol:CakeV3MultiHopSwapWrap --rpc-url ${BSC_RPC_URL} --broadcast

wrap:; forge script script/Interactions.s.sol:WrapEth --rpc-url ${BSC_RPC_URL} --broadcast

unwrap:; forge script script/Interactions.s.sol:UnwrapEth --rpc-url ${BSC_RPC_URL} --broadcast

deploy-cake-v3-helper-bsc:; forge script script/deploy/DeployCakeV3PoolQuoteHelper.s.sol:DeployCakeV3PoolQuoteHelper --rpc-url ${BSC_RPC_URL} --broadcast --verify

deploy-uni-v3-helper-bsc:; forge script script/deploy/DeployUniV3PoolQuoteHelper.s.sol:DeployUniV3PoolQuoteHelper --rpc-url ${BSC_RPC_URL} --broadcast --verify

sig:; forge script script/Interactions.s.sol:TestSignature --rpc-url ${BSC_RPC_URL}

sweep-erc20:; forge script script/Interactions.s.sol:SweepERC20 --rpc-url ${BSC_RPC_URL} --broadcast

cake-v3-multi-hop-swap-arb:; forge script script/Interactions.s.sol:CakeV3MultiHopSwapArb --rpc-url ${ARB_RPC_URL} --broadcast

deploy-cake-v3-helper-base:; forge script script/deploy/DeployCakeV3PoolQuoteHelper.s.sol:DeployCakeV3PoolQuoteHelper --rpc-url ${BASE_RPC_URL} --broadcast --verify --etherscan-api-key ${BASE_API_KEY}

deploy-cake-v3-helper-eth:; forge script script/deploy/DeployCakeV3PoolQuoteHelper.s.sol:DeployCakeV3PoolQuoteHelper --rpc-url ${ETH_RPC_URL} --broadcast --verify --etherscan-api-key ${ETH_API_KEY}

deploy-router-base:; forge script script/deploy/DeployTomoSwapRouter.s.sol:DeployTomoSwapRouter --rpc-url ${BASE_RPC_URL} --broadcast --verify --etherscan-api-key ${BASE_API_KEY}

deploy-router-eth:; forge script script/deploy/DeployTomoSwapRouter.s.sol:DeployTomoSwapRouter --rpc-url ${ETH_RPC_URL} --broadcast --verify --etherscan-api-key ${ETH_API_KEY}

#################################### arb ###########################################
deploy-cake-v3-helper-arb:; forge script script/deploy/DeployCakeV3PoolQuoteHelper.s.sol:DeployCakeV3PoolQuoteHelper --rpc-url ${ARB_RPC_URL} --broadcast --verify --etherscan-api-key ${ARB_API_KEY}

deploy-router-arb:; forge script script/deploy/DeployTomoSwapRouter.s.sol:DeployTomoSwapRouter --rpc-url ${ARB_RPC_URL} --broadcast --verify --etherscan-api-key ${ARB_API_KEY}

#################################### op ###########################################
deploy-cake-v3-helper-op:; forge script script/deploy/DeployCakeV3PoolQuoteHelper.s.sol:DeployCakeV3PoolQuoteHelper --rpc-url ${OP_RPC_URL} --broadcast --verify --etherscan-api-key ${OP_API_KEY}

deploy-router-op:; forge script script/deploy/DeployTomoSwapRouter.s.sol:DeployTomoSwapRouter --rpc-url ${OP_RPC_URL} --broadcast --verify --etherscan-api-key ${OP_API_KEY}

#################################### polygon #########################################
deploy-cake-v3-helper-polygon:; forge script script/deploy/DeployCakeV3PoolQuoteHelper.s.sol:DeployCakeV3PoolQuoteHelper --rpc-url ${POL_RPC_URL} --broadcast --verify --etherscan-api-key ${POL_API_KEY}

deploy-router-polygon:; forge script script/deploy/DeployTomoSwapRouter.s.sol:DeployTomoSwapRouter --rpc-url ${POL_RPC_URL} --broadcast --verify --etherscan-api-key ${POL_API_KEY}

#################################### avalanche #########################################
deploy-cake-v3-helper-avax:; forge script script/deploy/DeployCakeV3PoolQuoteHelper.s.sol:DeployCakeV3PoolQuoteHelper --rpc-url ${AVAX_RPC_URL} --broadcast --verify

deploy-router-avax:; forge script script/deploy/DeployTomoSwapRouter.s.sol:DeployTomoSwapRouter --rpc-url ${AVAX_RPC_URL} --broadcast --verify

#################################### zora #########################################
deploy-cake-v3-helper-zora:; forge script script/deploy/DeployCakeV3PoolQuoteHelper.s.sol:DeployCakeV3PoolQuoteHelper --rpc-url ${ZORA_RPC_URL} --broadcast --verify

deploy-router-zora:; forge script script/deploy/DeployTomoSwapRouter.s.sol:DeployTomoSwapRouter --rpc-url ${ZORA_RPC_URL} --broadcast --verify

#################################### wc #########################################
deploy-cake-v3-helper-wc:; forge script script/deploy/DeployCakeV3PoolQuoteHelper.s.sol:DeployCakeV3PoolQuoteHelper --rpc-url ${WC_RPC_URL} --broadcast --verify --etherscan-api-key ${WC_API_KEY}

deploy-router-wc:; forge script script/deploy/DeployTomoSwapRouter.s.sol:DeployTomoSwapRouter --rpc-url ${WC_RPC_URL} --broadcast --verify --etherscan-api-key ${WC_API_KEY}

#################################### zksync #########################################
deploy-cake-v3-helper-zksync:; forge script script/deploy/DeployCakeV3PoolQuoteHelper.s.sol:DeployCakeV3PoolQuoteHelper --rpc-url ${ZKSYNC_RPC_URL} --zksync --broadcast --verify --etherscan-api-key ${ZKSYNC_API_KEY}

deploy-router-zksync:; forge script script/deploy/DeployTomoSwapRouter.s.sol:DeployTomoSwapRouter --rpc-url ${ZKSYNC_RPC_URL}  --broadcast --verify --etherscan-api-key ${ZKSYNC_API_KEY}

#################################### berachain #########################################
deploy-cake-v3-helper-berachain:; forge script script/deploy/DeployCakeV3PoolQuoteHelper.s.sol:DeployCakeV3PoolQuoteHelper --rpc-url ${BERACHAIN_RPC_URL} --broadcast --verify --etherscan-api-key ${BERACHAIN_API_KEY}

deploy-router-berachain:; forge script script/deploy/DeployTomoSwapRouter.s.sol:DeployTomoSwapRouter --rpc-url ${BERACHAIN_RPC_URL} --broadcast --verify --etherscan-api-key ${BERACHAIN_API_KEY} --resume

#################################### doge os testnet #########################################
deploy-cake-v3-helper-doge-os-testnet:; forge script script/deploy/DeployCakeV3PoolQuoteHelper.s.sol:DeployCakeV3PoolQuoteHelper --rpc-url ${DOGE_OS_TESTNET_RPC_URL} --broadcast  --verifier-url https://blockscout-api.dogeos.doge.xyz/api --verify

deploy-router-doge-os-testnet:; forge script script/deploy/DeployTomoSwapRouter.s.sol:DeployTomoSwapRouter --rpc-url ${DOGE_OS_TESTNET_RPC_URL} --broadcast --verifier-url https://blockscout-api.dogeos.doge.xyz/api --verify

doge-os-testnet-swap:; forge script script/Interactions.s.sol:UniV3SwapDogeTestnet --rpc-url ${DOGE_OS_TESTNET_RPC_URL} --broadcast

#################################### sonic #########################################
deploy-cake-v3-helper-sonic:; forge script script/deploy/DeployCakeV3PoolQuoteHelper.s.sol:DeployCakeV3PoolQuoteHelper --rpc-url ${SONIC_RPC_URL} --broadcast --verify --etherscan-api-key ${SONIC_API_KEY}

