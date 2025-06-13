import dotenv from "dotenv";
import yargs from "yargs/yargs";
import { ethers } from "ethers";
const TronWeb = require("tronweb");
import SunswapV2FactoryArtifact from "../../../abis/SunswapV2Factory.json";
import TronWebWrapper from "../../wrapper";

dotenv.config();

function getOptions() {
    const options = yargs(process.argv.slice(2))
        .option("network", {
            type: "string",
            describe: "network",
            default: "nile",
        })
        .option("tokenA", {
            type: "string",
            describe: "tokenA address",
            default: "TF17BgPaZYbz8oxbjhriubPDsA7ArKoLX3", // Jst
        })
        .option("tokenB", {
            type: "string",
            describe: "tokenB address",
            default: "TXYZopYRdj2D9XRtbG411XZZ3kM5VkAeBf", // Usdt
        });
    return options.argv;
}

async function main() {
    let options: any = getOptions();
    const network = options.network;
    const tokenA = options.tokenA;
    const tokenB = options.tokenB;

    let tronWeb: any;
    let tronWebWrapper: any;
    let v2FactoryAddress: string;
    if (network === "nile") {
        tronWebWrapper = new TronWebWrapper(
            "https://nile.trongrid.io",
            process.env.TRON_PRO_API_KEY,
            process.env.TRON_PRIVATE_KEY
        );
        tronWeb = tronWebWrapper.getTronWeb();
        v2FactoryAddress = "TCfSVcHd8oYvjvbc4gNpH1PgVQr1cU9hAZ";
    } else if (network === "mainnet") {
        tronWebWrapper = new TronWebWrapper(
            "https://api.trongrid.io",
            process.env.TRON_PRO_API_KEY,
            process.env.TRON_PRIVATE_KEY
        );
        tronWeb = tronWebWrapper.getTronWeb();
        v2FactoryAddress = ""; // TODO:
    } else {
        throw new Error("Invalid network");
    }

    const v2FactoryContract = await tronWeb.contract(SunswapV2FactoryArtifact.abi, v2FactoryAddress);
    let res = await v2FactoryContract.getPair(tokenA, tokenB).call();
    const poolAddress = tronWebWrapper.tronAddressToHex(res);
    const poolAddressTron = tronWebWrapper.hexToTronAddress(poolAddress);

    if (poolAddress != ethers.constants.AddressZero) {
        console.log("pool already exists: ", poolAddressTron);
        return;
    }

    console.log("pool not found, creating new pool...");

    let toAddress = v2FactoryAddress;
    const functionSelector = "createPair(address,address)";
    const parameter = [
        { type: "address", value: tokenA },
        { type: "address", value: tokenB },
    ];

    res = await tronWebWrapper.estimateEnergy(toAddress, functionSelector, {}, parameter);
    console.log(res);

    let feeLimit = Math.ceil(res.sunRequired * 1.1);

    if (res.accountBalance < feeLimit) {
        console.log("account does not have enough sun to send transaction, exiting...");
        return;
    } else {
        try {
            const tx = await tronWeb.transactionBuilder.triggerSmartContract(
                toAddress,
                functionSelector,
                { feeLimit: feeLimit },
                parameter
            );

            const signedTx = await tronWeb.trx.sign(tx.transaction);
            const result = await tronWeb.trx.sendRawTransaction(signedTx);
            console.log(result);
        } catch (error) {
            console.error("Error sending transaction:", error);
        }
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

// pool not found, creating new pool...
// {
//     energyRequired: 1944228,
//     sunRequired: 408287880,
//     accountBalance: 3700000050
// }
// {
//     result: true,
//     txid: '4e3c5a7249a82b9c7df238ef9f1ddf239f566d9a69d095dceae74846de882be6',
//     transaction: {
//     visible: false,
//     txID: '4e3c5a7249a82b9c7df238ef9f1ddf239f566d9a69d095dceae74846de882be6',
//     raw_data: {
//         contract: [Array],
//         ref_block_bytes: 'da51',
//         ref_block_hash: 'feaa49decbe6ad83',
//         expiration: 1743957954000,
//         fee_limit: 449116669,
//         timestamp: 1743957895057
//     },
//     raw_data_hex: '0a02da512208feaa49decbe6ad8340d09bfadfe0325aae01081f12a9010a31747970652e676f6f676c65617069732e636f6d2f70726f746f636f6c2e54726967676572536d617274436f6e747261637412740a15416a2bd9e883b026014cac77bbd87d9dbc475bd7b51215411d8c271dc562a854e9dc55b77c9ad47d67274ad82244c9c6539600000000000000000000000037349aeb75a32f8c4c090daff376cf975f5d2eba000000000000000000000000eca9bc828a3005b9a3b909f2cc5c2a54794de05f7091cff6dfe0329001fdf393d601',
//     signature: [
//         '267a90470868125b080ecfdceb91999d3ce3362d2a1459c6bb9fdd90493a85a04fb1ceed496da022199e18126a158a7b0da4e9ec28a9adab36ff703e187cfa7d1B'
//     ]
//     }
// }
