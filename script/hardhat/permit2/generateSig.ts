import { PermitSingle } from "@uniswap/permit2-sdk";
import { ethers } from "ethers";
import permit2Abi from "../abis/permit2.json";
import hre from "hardhat";

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
    const signature = await signer._signTypedData(eip712Domain, PERMIT2_PERMIT_TYPE, permit);

    return signature;
}

export async function getPermitSignature(
    permit: PermitSingle,
    signer: ethers.Wallet,
    permit2: ethers.Contract,
    chainId: number
): Promise<string> {
    // look up the correct nonce for this permit
    const nextNonce = (await permit2.allowance(signer.address, permit.details.token, permit.spender)).nonce;
    permit.details.nonce = nextNonce;
    return await signPermit(permit, signer, chainId, permit2.address);
}

async function main() {
    const chainId = hre.network.config.chainId ? hre.network.config.chainId : 1;
    const signer = new ethers.Wallet(process.env.PRIVATE_KEY!, hre.ethers.provider);

    const permit2Addr = "0x000000000022D473030F116dDEE9F6B43aC78BA3"; // permit2 contract address
    const permit2 = new ethers.Contract(permit2Addr, permit2Abi, signer);

    const permitSingle = {
        details: {
            token: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c", // WBNB
            amount: ethers.utils.parseEther("0.001"),
            expiration: 0, // expire time for allowance, 0 means block.timestamp
            nonce: 0, // default is 0, will be changed later
        },
        spender: "0x1628d966d33b32f9a97ef7bB773546e363C19b26", // router's address
        // sigDeadline: Math.floor(Date.now() / 1000) + 60 * 100, // expire time for signature
        sigDeadline: 4894652840,
    };
    const sig = await getPermitSignature(permitSingle, signer, permit2, chainId);
    console.log(permitSingle);
    console.log(`Generated signature: ${sig}`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

// npx hardhat run script/hardhat/permit2/generateSig.ts --network bsc

// Generated sig by public test account
// {
//     details: {
//       token: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
//       amount: BigNumber { value: "1000000000000000" },
//       expiration: 0,
//       nonce: 0
//     },
//     spender: '0x1628d966d33b32f9a97ef7bB773546e363C19b26',
//     sigDeadline: 4894652840
//   }
//   Generated signature: 0x1a9f40382b1b74eeb9c2653f7dd5adc13acb70795c93c63b6ddc7a66cb68d1f234605a9e73b7510d55076d09e504cc517d7485a0e536ac0c22d033c1039380401c
