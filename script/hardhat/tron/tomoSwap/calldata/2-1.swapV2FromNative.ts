import dotenv from "dotenv";
import yargs from "yargs/yargs";
import { ethers } from "ethers";
import ERC20Artifact from "../../../abis/ERC20.json";
import Permit2Artifact from "../../../abis/Permit2.json";
import TronWebWrapper from "../../wrapper";
import { getPermitSignature } from "../../permit2/generateSig";
import {
    RoutePlanner,
    CommandType,
    DEADLINE,
    CONTRACT_BALANCE,
    ZERO_ADDRESS,
    ONE_PERCENT_BIPS,
    MSG_SENDER,
    ADDRESS_THIS,
    SOURCE_MSG_SENDER,
    SOURCE_ROUTER,
    setUpTronWeb,
    encodePath,
} from "../utils";

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
        })
        .option("feeRecipient", {
            type: "string",
            describe: "fee recipient",
            default: "TKebAEBb6oqAgVh6n6NsxeE7sM1Ftebn4r",
        });
    return options.argv;
}

async function main() {
    let options: any = getOptions();
    const network = options.network;
    const dryRun = options.dryRun;
    const feeRecipient = options.feeRecipient;

    console.log(`running with network="${network}", dryRun="${dryRun}"...`);

    const { tronWeb, tronWebWrapper, permit2Address, tomoSwapRouterAddress, tomoProtocolAddress, chainId } =
        await setUpTronWeb(network, process.env.TRON_PRO_API_KEY!, process.env.TRON_PRIVATE_KEY!);

    const planner = new RoutePlanner();

    const nativeAmount = ethers.utils.parseUnits("1", 6).toString(); // 1 TRX
    const feeAmount = ethers.utils.parseUnits("0.01", 6).toString(); // 0.01 TRX
    const wrapNativeAmount = ethers.BigNumber.from(nativeAmount).sub(ethers.BigNumber.from(feeAmount)).toString(); // after fee

    const pathV2 = [
        tronWebWrapper.tronAddressToHex("TNUC9Qb1rRpS5CbWLmNMxXBjyFoydXjWFR"), // Wtrx on mainnet
        tronWebWrapper.tronAddressToHex("TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"), // Usdt on mainnet
        // tronWebWrapper.tronAddressToHex("TYsbWxNnyTgsZaTFaue9hqpxkU3Fkco94a"), // Wtrx on nile
        // tronWebWrapper.tronAddressToHex("TXYZopYRdj2D9XRtbG411XZZ3kM5VkAeBf"), // Usdt on nile
    ];

    planner.addCommand(CommandType.TRANSFER, [ZERO_ADDRESS, tronWebWrapper.tronAddressToHex(feeRecipient), feeAmount]);
    planner.addCommand(CommandType.WRAP_ETH, [ADDRESS_THIS, CONTRACT_BALANCE]);
    planner.addCommand(CommandType.UNI_V2_SWAP_EXACT_IN, [
        tronWebWrapper.tronAddressToHex("TYdsw7qGFJzh7vwwgU9xmAtj31bSzMQvpv"), // to token receiver is user
        CONTRACT_BALANCE,
        1,
        pathV2,
        SOURCE_ROUTER,
    ]);

    const { commands, inputs } = planner;
    console.log("commands: ", commands);
    console.log("inputs: ", inputs);

    let toAddress = tomoProtocolAddress;
    let functionSelector = "execute(bytes,bytes[],uint256)";
    let parameter = [
        { type: "bytes", value: commands },
        { type: "bytes[]", value: inputs },
        { type: "uint256", value: DEADLINE },
    ];
    let txStruct = {
        toAddress: toAddress,
        functionSelector: functionSelector,
        options: { callValue: nativeAmount },
        parameter: parameter,
    };

    let res = await tronWebWrapper.estimateEnergy(...Object.values(txStruct));
    console.log("estimateEnergy: ", res);

    const callValue = (txStruct.options as any)?.callValue ?? 0;
    let feeLimit = Math.ceil(res.sunRequired * 1.5);

    if (res.accountBalance < feeLimit + Number(callValue)) {
        console.log("account does not have enough sun to send transaction, exiting...");
        return;
    }

    if (!dryRun) {
        try {
            const tx = await tronWeb.transactionBuilder.triggerSmartContract(
                txStruct.toAddress,
                txStruct.functionSelector,
                {
                    feeLimit: feeLimit,
                    callValue: callValue,
                },
                txStruct.parameter
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

// ts-node script/hardhat/tron/tomoSwap/calldata/2-1.swapV2FromNative.ts --network mainnet
// running with network="mainnet", dryRun="true"...
// commands:  0x050b08
// inputs:  [
//     '0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000006a2bd9e883b026014cac77bbd87d9dbc475bd7b50000000000000000000000000000000000000000000000000000000000002710',
//     '0x00000000000000000000000000000000000000000000000000000000000000028000000000000000000000000000000000000000000000000000000000000000',
//     '0x000000000000000000000000f8a312988a0742b4c8de94f023fe15938b7cd1178000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000891cdb91d149f23b1a45d9c5ca78a88d0cb44c18000000000000000000000000a614f803b6fd780986a42c78ec9c7f77e6ded13c'
// ]
// estimateEnergy:  {
//     energyRequired: 225062,
//     sunRequired: 47263020,
//     accountBalance: 53160072
// }
// account does not have enough sun to send transaction, exiting...
