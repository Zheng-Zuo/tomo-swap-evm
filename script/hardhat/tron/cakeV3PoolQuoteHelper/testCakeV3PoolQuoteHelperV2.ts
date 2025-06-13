const TronWeb = require("tronweb");
import { ethers } from "ethers";
import dotenv from "dotenv";
import yargs from "yargs/yargs";
import cakeV3PoolQuoteHelperV2Artifact from "../../abis/CakeV3PoolQuoteHelperV2.json";
import sunswapV3PoolAbi from "../../abis/SunswapV3PoolAbi.json";

dotenv.config();

function getOptions() {
    const options = yargs(process.argv.slice(2)).option("network", {
        type: "string",
        describe: "network",
        default: "nile",
    });

    return options.argv;
}

async function main() {
    let options: any = getOptions();
    const network = options.network;

    let tronWeb: any;
    let poolAddress: string;
    let cakeV3PoolQuoteHelperV2Address: string;

    if (network === "nile") {
        tronWeb = new TronWeb({
            fullHost: "https://nile.trongrid.io",
            headers: { "TRON-PRO-API-KEY": process.env.TRON_PRO_API_KEY },
            privateKey: process.env.TRON_PRIVATE_KEY,
        });
        // poolAddress = "TE6MBGu85TcLvDpxMM9PjVobWi1kxDkjcW";
        poolAddress = "TSV7963LfHcEVfqT7mZ1wNepXVKTbqnJqT";
        cakeV3PoolQuoteHelperV2Address = "TV5941XvWWJjaTYssj5bEPx24ZnZzji1yd";
    } else if (network === "mainnet") {
        tronWeb = new TronWeb({
            fullHost: "https://api.trongrid.io",
            headers: { "TRON-PRO-API-KEY": process.env.TRON_PRO_API_KEY },
            privateKey: process.env.TRON_PRIVATE_KEY,
        });
        // poolAddress = "TC9QmgR8MUwRCYe3kCLwH8MW2WtxiLd6AV"; // wtrx-usdt-3000
        poolAddress = "TY9cRnranaVLaqVM3s24Km9oJTRUUkyXvB"; // ethb-usdt-500
        cakeV3PoolQuoteHelperV2Address = "TPkHdsvp2Av8QcX3mhJ3YeMfULPDkyxWiW";
    } else {
        throw new Error("Invalid network");
    }

    const quoteHelperV2Contract = await tronWeb.contract(
        cakeV3PoolQuoteHelperV2Artifact.abi,
        cakeV3PoolQuoteHelperV2Address
    );
    let res = await quoteHelperV2Contract.getPoolState(poolAddress).call();
    const poolState = res[0];
    const quotedSqrtPriceX96 = poolState[0].toString();
    const quotedTick = poolState[1].toString();
    const quotedLiquidity = poolState[2].toString();
    console.log("quotedSqrtPriceX96: ", quotedSqrtPriceX96);
    console.log("quotedTick: ", quotedTick);
    console.log("quotedLiquidity: ", quotedLiquidity);

    console.log("\n--------------------------------\n");

    console.log("data retrieved from v3 pool contract");
    const v3PoolContract = await tronWeb.contract(sunswapV3PoolAbi, poolAddress);
    const slot0 = await v3PoolContract.slot0().call();
    const sqrtPriceX96 = slot0[0].toString();
    const tick = slot0[1].toString();
    const liquidity = await v3PoolContract.liquidity().call();
    console.log("sqrtPriceX96: ", sqrtPriceX96);
    console.log("tick: ", tick);
    console.log("liquidity: ", liquidity.toString());

    console.log("\n--------------------------------\n");

    console.log("ticks data");
    res = await quoteHelperV2Contract.getTicks(poolAddress, quotedTick, -887272, true, 50).call();
    const ticks = res[0];
    console.log("number of available ticks: ", ticks.length);
    console.log("first five ticks: ", ticks.slice(0, 5));
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
