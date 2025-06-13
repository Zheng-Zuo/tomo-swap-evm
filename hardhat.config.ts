import "@nomicfoundation/hardhat-foundry";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-deploy";
import "@layerzerolabs/hardhat-tron";
import "@openzeppelin/hardhat-upgrades";
import { ProxyAgent, setGlobalDispatcher } from "undici";
import "dotenv/config";

// const proxyAgent: ProxyAgent = new ProxyAgent("http://127.0.0.1:7890");
// setGlobalDispatcher(proxyAgent);

const REPORT_GAS = process.env.REPORT_GAS || false;

const config: HardhatUserConfig = {
    solidity: {
        compilers: [
            {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                        details: {
                            yul: true,
                            yulDetails: {
                                stackAllocation: true,
                                optimizerSteps: "u",
                            },
                        },
                    },
                    viaIR: true,
                },
            },
            {
                version: "0.8.20",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                        details: {
                            yul: true,
                            yulDetails: {
                                stackAllocation: true,
                                optimizerSteps: "u",
                            },
                        },
                    },
                    viaIR: true,
                },
            },
        ],
    },

    tronSolc: {
        enable: true,
        filter: [],
        compilers: [
            {
                version: "0.8.20",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                        details: {
                            yul: true,
                            yulDetails: {
                                stackAllocation: true,
                                optimizerSteps: "u",
                            },
                        },
                    },
                },
            },
        ],
        // Optional: Define version remappings for compiler versions
        versionRemapping: [["0.8.28", "0.8.20"]],
    },

    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            chainId: 31337,
            blockGasLimit: 30_000_000,
            throwOnCallFailures: false,
            allowUnlimitedContractSize: false,
        },

        localhost: {
            chainId: 31337,
        },

        // Mainnet
        mainnet: {
            chainId: 1,
            url: `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
            accounts: { mnemonic: process.env.MNEMONIC! },
        },

        arbitrum: {
            chainId: 42161,
            url: `https://arb-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
            accounts: { mnemonic: process.env.MNEMONIC! },
        },

        alienx: {
            chainId: 10241024,
            url: "https://alienx.calderachain.xyz/http",
            accounts: { mnemonic: process.env.MNEMONIC! },
        },

        bsc: {
            chainId: 56,
            url: `https://bnb-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
            accounts: { mnemonic: process.env.MNEMONIC! },
        },

        // Testnet
        sepolia: {
            chainId: 11155111,
            url: `https://eth-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
            accounts: { mnemonic: process.env.MNEMONIC! },
        },

        arbitrumSepolia: {
            chainId: 421614,
            url: `https://arb-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
            accounts: { mnemonic: process.env.MNEMONIC! },
        },

        hal: {
            chainId: 10241025,
            url: "https://hal.rpc.caldera.xyz/http",
            accounts: { mnemonic: process.env.MNEMONIC! },
        },

        shasta: {
            chainId: 2494104990,
            url: "https://api.shasta.trongrid.io/jsonrpc",
            accounts: [process.env.PRIVATE_KEY!],
            httpHeaders: { "TRON-PRO-API-KEY": process.env.TRON_PRO_API_KEY! },
            tron: true,
        }, // explorer: https://shasta.tronscan.io/

        nile: {
            chainId: 3448148188,
            url: "https://nile.trongrid.io/jsonrpc",
            accounts: [process.env.TRON_PRIVATE_KEY!],
            httpHeaders: { "TRON-PRO-API-KEY": process.env.TRON_PRO_API_KEY! },
            tron: true,
        }, // explorer: https://nile.tronscan.org/
    },

    etherscan: {
        apiKey: {
            // Mainnet
            mainnet: process.env.ETHERSCAN_API_KEY!,
            arbitrum: process.env.ARBSCAN_API_KEY!,
            alienx: "NO_KEY_NEEDED",
            // Testnet
            sepolia: process.env.ETHERSCAN_API_KEY!,
            arbitrumSepolia: process.env.ARBSCAN_API_KEY!,
            hal: "NO_KEY_NEEDED",
            nile: "NO_KEY_NEEDED",
        },
        customChains: [
            // Mainnet
            {
                network: "arbitrum",
                chainId: 42161,
                urls: {
                    apiURL: "https://api.arbiscan.io/api",
                    browserURL: "https://arbiscan.io",
                },
            },
            {
                network: "alienx",
                chainId: 10241024,
                urls: {
                    apiURL: "https://alienx.calderaexplorer.xyz/api",
                    browserURL: "https://alienx.calderaexplorer.xyz/", // https://explorer.alienxchain.io/
                },
            },
            // Testnet
            {
                network: "arbitrumSepolia",
                chainId: 421614,
                urls: {
                    apiURL: "https://api-sepolia.arbiscan.io/api",
                    browserURL: "https://sepolia.arbiscan.io/",
                },
            },
            {
                network: "hal",
                chainId: 10241025,
                urls: {
                    apiURL: "https://hal.explorer.caldera.xyz/api",
                    browserURL: "https://hal-explorer.alienxchain.io/", // "https://hal.explorer.caldera.xyz/"
                },
            },
        ],
    },

    gasReporter: {
        enabled: REPORT_GAS as boolean,
        currency: "USD",
        outputFile: "gas-report.txt",
        // coinmarketcap: process.env.COINMARKETCAP_API_KEY,
        excludeContracts: ["contracts/mocks/"],
        noColors: true,
    },

    namedAccounts: {
        deployer: {
            default: 0,
        },
    },
};

export default config;
