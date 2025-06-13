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
        });
    return options.argv;
}

async function main() {
    let options: any = getOptions();
    const network = options.network;
    const dryRun = options.dryRun;

    console.log(`running with network="${network}", dryRun="${dryRun}"...`);

    const { tronWeb, tronWebWrapper, permit2Address, tomoSwapRouterAddress, tomoProtocolAddress, chainId } =
        await setUpTronWeb(network, process.env.TRON_PRO_API_KEY!, process.env.TRON_PRIVATE_KEY!);

    const planner = new RoutePlanner();

    const wrapNativeAmount = ethers.utils.parseUnits("10", 6).toString(); // 10 TRX
    planner.addCommand(CommandType.WRAP_ETH, [
        tronWebWrapper.tronAddressToHex(tronWebWrapper.account),
        wrapNativeAmount,
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
        options: {
            callValue: wrapNativeAmount,
        },
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

// ts-node script/hardhat/tron/tomoSwap/calldata/0.wrapTrx.ts --network mainnet --dryRun true
// running with network="mainnet", dryRun="true"...
// commands:  0x0b
// inputs:  [
//     '0x000000000000000000000000f8a312988a0742b4c8de94f023fe15938b7cd1170000000000000000000000000000000000000000000000000000000000989680'
// ]
// estimateEnergy:  {
//     energyRequired: 84245,
//     sunRequired: 17691450,
//     accountBalance: 76835572
// }
// dry run, exiting...
