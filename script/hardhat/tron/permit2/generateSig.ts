import { PermitSingle } from "@uniswap/permit2-sdk";

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
    tronWeb: any,
    chainId: number,
    verifyingContract: string
): Promise<string> {
    const eip712Domain = getEip712Domain(chainId, verifyingContract);

    const signature = await tronWeb.trx._signTypedData(eip712Domain, PERMIT2_PERMIT_TYPE, permit);

    return signature;
}

export async function getPermitSignature(
    permit: PermitSingle,
    tronWeb: any,
    signerAddress: string,
    permit2: any,
    chainId: number
): Promise<string> {
    // look up the correct nonce for this permit
    const nextNonce = (await permit2.allowance(signerAddress, permit.details.token, permit.spender).call()).nonce;
    permit.details.nonce = nextNonce;
    return await signPermit(permit, tronWeb, chainId, permit2.address);
}
