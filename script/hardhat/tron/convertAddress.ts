import dotenv from "dotenv";
import yargs from "yargs/yargs";
import { ethers } from "ethers";
import TronWebWrapper from "./wrapper";

dotenv.config();

function getOptions() {
    const options = yargs(process.argv.slice(2))
        .option("network", {
            type: "string",
            describe: "network",
            default: "nile",
        })
        .option("dryRun", {
            type: "boolean",
            describe: "dry run",
            default: true,
        });
    return options.argv;
}

async function main() {
    let options: any = getOptions();
    const network = options.network;
    const dryRun = options.dryRun;

    const tronWebWrapper = new TronWebWrapper();
    const tronAddress = tronWebWrapper.hexToTronAddress("0xa614f803B6FD780986A42c78Ec9c7f77e6DeD13C");
    console.log(`tronAddress ${tronAddress}`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
