import { ethers } from "ethers";
import TronWebWrapper from "../wrapper";
import VaultNileArtifact from "../../abis/VaultNile.json";
import VaultTronArtifact from "../../abis/VaultTron.json";
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
    let vaultArtifact: any;

    if (network === "nile") {
        tronWebWrapper = new TronWebWrapper(
            "https://nile.trongrid.io",
            process.env.TRON_PRO_API_KEY,
            process.env.TRON_PRIVATE_KEY
        );
        tronWeb = tronWebWrapper.getTronWeb();
        vaultArtifact = VaultNileArtifact;
    } else if (network === "mainnet") {
        tronWebWrapper = new TronWebWrapper(
            "https://api.trongrid.io",
            process.env.TRON_PRO_API_KEY,
            process.env.TRON_PRIVATE_KEY
        );
        tronWeb = tronWebWrapper.getTronWeb();
        vaultArtifact = VaultTronArtifact;
    } else {
        throw new Error("Invalid network");
    }

    const contract = await tronWeb.contract().new({
        abi: vaultArtifact.abi,
        bytecode: vaultArtifact.bytecode,
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

// nile: TYKWemThDD4bbiVKyFNvphoA3ci2ZTqexc
// mainnet: TNmerLTvuZb2Ng7eEU6q6LBvZiUmjJqagX
