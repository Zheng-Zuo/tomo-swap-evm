const TronWeb = require("tronweb");
import cakeV3PoolQuoteHelperV2Artifact from "../../abis/CakeV3PoolQuoteHelperV2.json";
import dotenv from "dotenv";
import yargs from "yargs/yargs";

dotenv.config();

function getOptions() {
    const options = yargs(process.argv.slice(2)).option("network", {
        type: "string",
        describe: "network",
        default: "nile",
    });

    return options.argv;
}

async function main() {
    let options: any = getOptions();
    const network = options.network;

    let tronWeb: any;
    if (network === "nile") {
        tronWeb = new TronWeb({
            fullHost: "https://nile.trongrid.io",
            headers: { "TRON-PRO-API-KEY": process.env.TRON_PRO_API_KEY },
            privateKey: process.env.TRON_PRIVATE_KEY,
        });
    } else if (network === "mainnet") {
        tronWeb = new TronWeb({
            fullHost: "https://api.trongrid.io",
            headers: { "TRON-PRO-API-KEY": process.env.TRON_PRO_API_KEY },
            privateKey: process.env.TRON_PRIVATE_KEY,
        });
    } else {
        throw new Error("Invalid network");
    }

    const contract = await tronWeb.contract().new({
        abi: cakeV3PoolQuoteHelperV2Artifact.abi,
        bytecode: cakeV3PoolQuoteHelperV2Artifact.bytecode,
        feeLimit: 1_000_000_000,
        callValue: 0,
        userFeePercentage: 100,
        originEnergyLimit: 10_000_000,
        parameters: [],
    });

    const hexAddress = contract.address;
    const base58Address = tronWeb.address.fromHex(hexAddress);
    console.log(`Contract deployed at address: ${base58Address}`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

// ts-node script/hardhat/tron/cakeV3PoolQuoteHelper/deployCakeV3PoolQuoteHelperV2.ts --network mainnet

// nile: TV5941XvWWJjaTYssj5bEPx24ZnZzji1yd
// mainnet: TPkHdsvp2Av8QcX3mhJ3YeMfULPDkyxWiW
