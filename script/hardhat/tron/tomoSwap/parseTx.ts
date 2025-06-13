import dotenv from "dotenv";
import yargs from "yargs/yargs";
import { ethers } from "ethers";
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
    const options = yargs(process.argv.slice(2)).option("network", {
        type: "string",
        describe: "network",
        default: "mainnet",
    });
    return options.argv;
}

async function main() {
    let options: any = getOptions();
    const network = options.network;

    console.log(`running with network="${network}"...`);

    const { tronWeb, tronWebWrapper, permit2Address, tomoSwapRouterAddress, tomoProtocolAddress, chainId } =
        await setUpTronWeb(network, process.env.TRON_PRO_API_KEY!, process.env.TRON_PRIVATE_KEY!);

    const res = await tronWeb.trx.getConfirmedTransaction(
        "00e5a88580141825e44b8ae0ea180ce4d00ed62d1dd42e381d48d0161295c1e5"
    );
    console.log(res);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
