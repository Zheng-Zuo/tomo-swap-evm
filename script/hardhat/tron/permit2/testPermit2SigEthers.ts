import { PermitSingle } from "@uniswap/permit2-sdk";
import { ethers } from "ethers";
import Permit2Artifact from "../../abis/Permit2.json";
import TronWebWrapper from "../wrapper";
import dotenv from "dotenv";
import yargs from "yargs/yargs";

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

export const PERMIT2_PERMIT_TYPE = {
    PermitDetails: [
        { name: "token", type: "address" },
        { name: "amount", type: "uint160" },
        { name: "expiration", type: "uint48" },
        { name: "nonce", type: "uint48" },
    ],
    PermitSingle: [
        { name: "details", type: "PermitDetails" },
        { name: "spender", type: "address" },
        { name: "sigDeadline", type: "uint256" },
    ],
};

export function getEip712Domain(chainId: number, verifyingContract: string) {
    return {
        name: "Permit2",
        chainId,
        verifyingContract,
    };
}

export async function signPermit(
    permit: PermitSingle,
    signer: ethers.Wallet,
    chainId: number,
    verifyingContract: string
): Promise<string> {
    const eip712Domain = getEip712Domain(chainId, verifyingContract);
    const signature = await signer._signTypedData(
        eip712Domain,
        PERMIT2_PERMIT_TYPE,
        permit
    );

    return signature;
}

export async function getPermitSignature(
    permit: PermitSingle,
    signer: ethers.Wallet,
    permit2: ethers.Contract,
    chainId: number,
    permit2Address: string
): Promise<string> {
    // look up the correct nonce for this permit
    // const nextNonce = (
    //     await permit2.allowance(signer.address, permit.details.token, permit.spender)
    // ).nonce;
    // permit.details.nonce = nextNonce;
    return await signPermit(permit, signer, chainId, permit2Address);
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
    const signer = new ethers.Wallet(process.env.TRON_PRIVATE_KEY!);

    const permit2Addr = "0x000000000022D473030F116dDEE9F6B43aC78BA3"; // permit2 contract address
    const permit2 = new ethers.Contract(permit2Addr, Permit2Artifact.abi, signer);

    const permitSingle = {
        details: {
            token: tronWebWrapper.tronAddressToHex(tokenAddress), //
            amount: ethers.utils.parseEther("100").toString(),
            expiration: 4894652840, // expire time for allowance, 0 means block.timestamp
            nonce: 0, // default is 0, will be changed later
        },
        spender: tronWebWrapper.tronAddressToHex("THQFCyBxk2sHtdddHBWsyK8wKqM9KMXD75"), // router's address
        // sigDeadline: Math.floor(Date.now() / 1000) + 60 * 100, // expire time for signature
        sigDeadline: 4894652840,
    };
    const sig = await getPermitSignature(
        permitSingle,
        signer,
        permit2,
        chainId,
        tronWebWrapper.tronAddressToHex(permit2Address)
    );
    // console.log(permitSingle);
    console.log(`Generated signature: ${sig}`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
