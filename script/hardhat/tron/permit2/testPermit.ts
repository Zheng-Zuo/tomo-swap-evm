import dotenv from "dotenv";
import yargs from "yargs/yargs";
const TronWeb = require("tronweb");
import Permit2Artifact from "./../../abis/Permit2.json";
import { getPermitSignature } from "./generateSig";

dotenv.config();

function getOptions() {
    const options = yargs(process.argv.slice(2)).option("dryRun", {
        type: "boolean",
        describe: "dry run",
        default: true,
    });
    return options.argv;
}

async function main() {
    let options: any = getOptions();
    const dryRun = options.dryRun;

    const tronWeb = new TronWeb({
        fullHost: "https://api.trongrid.io",
        headers: { "TRON-PRO-API-KEY": process.env.TRON_PRO_API_KEY! },
        privateKey: process.env.TRON_PRIVATE_KEY!,
    });

    const permit2Address = "TDJNTBi51CnnpCYYgi6GitoT4CJWrqim2G";
    const chainId = 728126428;
    const owner = tronWeb.address.fromPrivateKey(process.env.TRON_PRIVATE_KEY!);

    const permit2 = await tronWeb.contract(Permit2Artifact.abi, permit2Address);

    const permitSingle = {
        details: {
            token: "0xA614F803B6FD780986A42C78EC9C7F77E6DED13C", // TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t Usdt on tron
            amount: "1000",
            expiration: 0, // expire time for allowance, 0 means block.timestamp
            nonce: 0, // default is 0, will be changed later
        },
        spender: "0xBDE814EBD17A0B25C39EE16A8B2FF48D1628E503", // TTHLjdq1suzroV7AEAvLQYm1UNbTqvnuZY tomo protocol address
        sigDeadline: 6000000000,
    };

    const sig = await getPermitSignature(permitSingle, tronWeb, owner, permit2, chainId);

    const args = [
        owner,
        [
            [
                permitSingle.details.token,
                permitSingle.details.amount,
                permitSingle.details.expiration,
                permitSingle.details.nonce,
            ],
            permitSingle.spender,
            permitSingle.sigDeadline,
        ],
        sig,
    ];

    const abi = {
        inputs: [
            { type: "address", name: "owner" },
            {
                components: [
                    {
                        components: [
                            { type: "address", name: "token" },
                            { type: "uint160", name: "amount" },
                            { type: "uint48", name: "expiration" },
                            { type: "uint48", name: "nonce" },
                        ],
                        type: "tuple",
                        name: "details",
                    },
                    { type: "address", name: "spender" },
                    { type: "uint256", name: "sigDeadline" },
                ],
                type: "tuple",
                name: "permitSingle",
            },
            { type: "bytes", name: "signature" },
        ],
        name: "permit",
        type: "function",
    };

    const parameter = tronWeb.utils.abi.encodeParamsV2ByABI(abi, args);
    // console.log("parameter: ", parameter);

    const functionSelector = "permit(address,((address,uint160,uint48,uint48),address,uint256),bytes)";

    const estimateEnergy = await tronWeb.transactionBuilder.triggerConstantContract(
        permit2Address,
        functionSelector,
        {
            rawParameter: parameter,
        },
        []
    );

    const energyRequired = estimateEnergy["energy_used"];
    const sunRequired = energyRequired * 210;
    const accountBalance = await tronWeb.trx.getBalance(owner);
    console.log("estimateEnergy: ", energyRequired);
    console.log("sunRequired: ", sunRequired);
    console.log("trxRequired: ", sunRequired / 1e6);

    let feeLimit = Math.ceil(sunRequired * 1.5);

    if (accountBalance < feeLimit) {
        console.log("account does not have enough sun to send transaction, exiting...");
        return;
    }

    if (!dryRun) {
        try {
            const tx = await tronWeb.transactionBuilder.triggerSmartContract(
                permit2Address,
                functionSelector,
                {
                    feeLimit: feeLimit,
                    rawParameter: parameter,
                },
                []
            );

            const signedTx = await tronWeb.trx.sign(tx.transaction);
            const result = await tronWeb.trx.sendRawTransaction(signedTx);
            console.log(result);
        } catch (error) {
            console.error("Error sending transaction:", error);
        }
    } else {
        console.log("dry run, exiting...");
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

// ts-node script/hardhat/tron/permit2/testPermit.ts --dryRun false
// estimateEnergy:  13704
// sunRequired:  2877840
// trxRequired:  2.87784
// {
//     result: true,
//     txid: '4dee0883868cf842338344a6dc7f7f33077f6fc7d4085f0d2a550da98079c9b3',
//     transaction: {
//     visible: false,
//     txID: '4dee0883868cf842338344a6dc7f7f33077f6fc7d4085f0d2a550da98079c9b3',
//     raw_data: {
//         contract: [Array],
//         ref_block_bytes: 'ef63',
//         ref_block_hash: '716a4e25abc12990',
//         expiration: 1745338215000,
//         fee_limit: 4316760,
//         timestamp: 1745338156038
//     },
//     raw_data_hex: '0a02ef632208716a4e25abc1299040d8d48ef2e5325af003081f12eb030a31747970652e676f6f676c65617069732e636f6d2f70726f746f636f6c2e54726967676572536d617274436f6e747261637412b5030a1541f8a312988a0742b4c8de94f023fe15938b7cd11712154124882b624b3a72af211caefe3b83dc12165608cd2284032b67b570000000000000000000000000f8a312988a0742b4c8de94f023fe15938b7cd117000000000000000000000000a614f803b6fd780986a42c78ec9c7f77e6ded13c00000000000000000000000000000000000000000000000000000000000003e800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000bde814ebd17a0b25c39ee16a8b2ff48d1628e5030000000000000000000000000000000000000000000000000000000165a0bc0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000041156c6e3373259790d5ecc2762a65842b8a6b7ba09addf805a6f8bd44e4e3b2b73af953ba429668441a30b3de5e28de820ea60f4e534bfdc52216ba07312539011c000000000000000000000000000000000000000000000000000000000000007086888bf2e5329001d8bc8702',
//     signature: [
//         '629b88ad91acb258591852c71df6f6e1af04464657420915fc977d5a5f47b67d4cd5061f275016f8771ee2f8d98e1489d36c3350286f301c2d37f871af8cf7851B'
//     ]
//     }
// }
