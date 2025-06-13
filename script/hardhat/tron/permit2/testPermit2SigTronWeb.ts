import dotenv from "dotenv";
import yargs from "yargs/yargs";
import { ethers } from "ethers";
import Permit2Artifact from "../../abis/Permit2.json";
import TronWebWrapper from "../wrapper";
import { getPermitSignature } from "./generateSig";

dotenv.config();

function getOptions() {
    const options = yargs(process.argv.slice(2))
        .option("network", {
            type: "string",
            describe: "network",
            default: "nile",
        })
        .option("tokenAddress", {
            type: "string",
            describe: "token address",
            default: "TF17BgPaZYbz8oxbjhriubPDsA7ArKoLX3", // Jst
        });
    return options.argv;
}

async function main() {
    let options: any = getOptions();
    const network = options.network;
    const tokenAddress = options.tokenAddress;

    let tronWeb: any;
    let tronWebWrapper: any;
    let permit2Address: string;
    let chainId: number;
    if (network === "nile") {
        tronWebWrapper = new TronWebWrapper(
            "https://nile.trongrid.io",
            process.env.TRON_PRO_API_KEY,
            process.env.TRON_PRIVATE_KEY
        );
        tronWeb = tronWebWrapper.getTronWeb();
        permit2Address = "TMw3MtL3WJeVG9nbsXDDrukjTVryQrQu5F";
        chainId = 3448148188;
    } else if (network === "mainnet") {
        tronWebWrapper = new TronWebWrapper(
            "https://api.trongrid.io",
            process.env.TRON_PRO_API_KEY,
            process.env.TRON_PRIVATE_KEY
        );
        tronWeb = tronWebWrapper.getTronWeb();
        permit2Address = ""; // TODO:
        chainId = 728126428;
    } else {
        throw new Error("Invalid network");
    }

    const permit2 = await tronWeb.contract(Permit2Artifact.abi, permit2Address);

    const permitSingle = {
        details: {
            token: tokenAddress,
            amount: ethers.utils.parseEther("100").toString(),
            expiration: 4894652840, // expire time for allowance, 0 means block.timestamp
            nonce: 0, // default is 0, will be changed later
        },
        spender: "THQFCyBxk2sHtdddHBWsyK8wKqM9KMXD75", // router's address
        sigDeadline: 4894652840,
    };

    const sig = await getPermitSignature(
        permitSingle,
        tronWeb,
        tronWebWrapper.account,
        permit2,
        chainId
    );

    console.log("sig: ", sig);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
