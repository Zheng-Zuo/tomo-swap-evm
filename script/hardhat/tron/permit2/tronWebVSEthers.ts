const TronWeb = require("tronweb");
import { ethers } from "ethers";

const PERMIT2_PERMIT_TYPE = {
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

const eip712Domain = {
    name: "Permit2",
    chainId: 728126428,
    verifyingContract: "0x24882B624B3A72AF211CAEFE3B83DC12165608CD", // TDJNTBi51CnnpCYYgi6GitoT4CJWrqim2G permit2 on tron
};

const permitSingle = {
    details: {
        token: "0xA614F803B6FD780986A42C78EC9C7F77E6DED13C", // TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t Usdt on tron
        amount: "1000",
        expiration: 0,
        nonce: 0,
    },
    spender: "0xBDE814EBD17A0B25C39EE16A8B2FF48D1628E503", // TTHLjdq1suzroV7AEAvLQYm1UNbTqvnuZY tomo protocol address
    sigDeadline: 6000000000,
};

async function main() {
    const testPrivateKey = "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"; // private key for test

    // generate signature with tronWeb
    const tronWeb = new TronWeb({
        fullHost: "https://api.trongrid.io",
        headers: { "TRON-PRO-API-KEY": "" },
        privateKey: testPrivateKey,
    });
    const tronWebSig = await tronWeb.trx._signTypedData(eip712Domain, PERMIT2_PERMIT_TYPE, permitSingle);
    console.log("\ntronWeb signature: \n", tronWebSig);

    // generate signature with ethers
    const ethersSigner = new ethers.Wallet(testPrivateKey);
    const ethersSig = await ethersSigner._signTypedData(eip712Domain, PERMIT2_PERMIT_TYPE, permitSingle);
    console.log("\nethers signature: \n", ethersSig);

    // compare the signatures
    if (tronWebSig === ethersSig) {
        console.log("\nThe signatures are the same");
    } else {
        console.log("\nThe signatures are different");
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

// ╰─ ts-node script/hardhat/tron/permit2/tronWebVSEthers.ts

// tronWeb signature:
//     0x7cc55f569ea2b4589bb3fecf12b3496d95c4b7fd70548f9df8465238e2f4810e28f4b85184550b740a1ead88a339b71292649bab9deeb1c1c21ca27b6ece478f1b

// ethers signature:
//     0x7cc55f569ea2b4589bb3fecf12b3496d95c4b7fd70548f9df8465238e2f4810e28f4b85184550b740a1ead88a339b71292649bab9deeb1c1c21ca27b6ece478f1b

// The signatures are the same
