import dotenv from "dotenv";
import { ethers } from "ethers";
import yargs from "yargs/yargs";
const TronWeb = require("tronweb");
import Permit2Artifact from "./../../abis/Permit2.json";
import { getPermitSignature } from "./generateSig";

dotenv.config();

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

async function main() {
    const signature =
        "0x3722b319e70f3411d29f7cd55972161a762ef497e6c944856d6d93b8933848242d9ae63623223832afc97674ab45c4ab0c2b404d6725a2a3e5916ec29fddefac1b";

    const chainId = 728126428;

    const permitSingle = {
        details: {
            token: "0xa614f803B6FD780986A42c78Ec9c7f77e6DeD13C",
            amount: "300000",
            expiration: "0",
            nonce: "0",
        },
        spender: "0xBDE814EBd17a0B25C39Ee16a8b2Ff48d1628E503",
        sigDeadline: "1751017760",
    };

    const domain = {
        name: "Permit2",
        chainId: chainId,
        verifyingContract: "0x24882B624B3A72AF211CAEFE3B83DC12165608CD",
    };

    const recoveredAddress = ethers.utils.verifyTypedData(domain, PERMIT2_PERMIT_TYPE, permitSingle, signature);

    console.log(recoveredAddress);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
