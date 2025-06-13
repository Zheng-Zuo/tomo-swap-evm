import { ethers } from "ethers";
import TronWebWrapper from "../wrapper";
import TomoProtocolArtifact from "../../abis/TomoProtocol.json";
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
    let tronWebWrapper: any;
    let routerParameters: any;
    if (network === "nile") {
        tronWebWrapper = new TronWebWrapper(
            "https://nile.trongrid.io",
            process.env.TRON_PRO_API_KEY,
            process.env.TRON_PRIVATE_KEY
        );
        tronWeb = tronWebWrapper.getTronWeb();

        routerParameters = {
            tomoSwapRouterAddress: tronWebWrapper.tronAddressToHex("TNZndMV9cxz4vxvAmEsoi7JJXaqutoJwRi"),
            permit2Address: tronWebWrapper.tronAddressToHex("TMw3MtL3WJeVG9nbsXDDrukjTVryQrQu5F"),
        };
    } else if (network === "mainnet") {
        tronWebWrapper = new TronWebWrapper(
            "https://api.trongrid.io",
            process.env.TRON_PRO_API_KEY,
            process.env.TRON_PRIVATE_KEY
        );
        tronWeb = tronWebWrapper.getTronWeb();

        routerParameters = {
            tomoSwapRouterAddress: tronWebWrapper.tronAddressToHex("TM9y9N5RoEkHFxAwkbzYu1Sz72DKeLYprS"),
            permit2Address: tronWebWrapper.tronAddressToHex("TDJNTBi51CnnpCYYgi6GitoT4CJWrqim2G"),
        };
    } else {
        throw new Error("Invalid network");
    }

    const tx = await tronWeb.transactionBuilder.createSmartContract(
        {
            abi: TomoProtocolArtifact.abi,
            bytecode: TomoProtocolArtifact.bytecode,
            funcABIV2: TomoProtocolArtifact.abi[0],
            parametersV2: [routerParameters.tomoSwapRouterAddress, routerParameters.permit2Address],
            feeLimit: 20_00_000_000,
        },
        tronWebWrapper.account
    );

    const signedTx = await tronWeb.trx.sign(tx);
    const result = await tronWeb.trx.sendRawTransaction(signedTx);
    console.log(result);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

// nile: TGgoD3xzR6kPTdRUbXTwUPdtZ9VmSGt4WU
// mainnet: TTHLjdq1suzroV7AEAvLQYm1UNbTqvnuZY
