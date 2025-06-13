import dotenv from "dotenv";
import yargs from "yargs/yargs";
import { ethers } from "ethers";
import ERC20Artifact from "./../../abis/ERC20.json";
import Permit2Artifact from "./../../abis/Permit2.json";
import TronWebWrapper from "./../wrapper";
import { getPermitSignature } from "./../permit2/generateSig";
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
} from "./utils";

dotenv.config();

function getOptions() {
    const options = yargs(process.argv.slice(2))
        .option("network", {
            type: "string",
            describe: "network",
            default: "nile",
        })
        .option("calldata", {
            type: "string",
            describe: "calldata",
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

    const res = await tronWeb.transactionBuilder.triggerConstantContract(
        tomoProtocolAddress,
        "",
        {
            callValue: "10000000",
            input: "3593564c000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000165a0bc0000000000000000000000000000000000000000000000000000000000000000010b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000040000000000000000000000000f8a312988a0742b4c8de94f023fe15938b7cd1170000000000000000000000000000000000000000000000000000000000989680",
        },
        []
    );

    console.log(res);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
