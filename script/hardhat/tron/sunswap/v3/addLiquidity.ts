import dotenv from "dotenv";
import yargs from "yargs/yargs";
import { ethers } from "ethers";
import NonfungiblePositionManagerAbi from "../../../abis/NonfungiblePositionManagerAbi.json";
import SunswapV3PoolAbi from "../../../abis/SunswapV3PoolAbi.json";
import ERC20Artifact from "../../../abis/ERC20.json";
import TronWebWrapper from "../../wrapper";

dotenv.config();

function getOptions() {
    const options = yargs(process.argv.slice(2))
        .option("network", {
            type: "string",
            describe: "network",
            default: "nile",
        })
        .option("poolAddress", {
            type: "string",
            describe: "sunswap v3 pool address",
            default: "TSV7963LfHcEVfqT7mZ1wNepXVKTbqnJqT", // Jst - Usdt - 3000 nile
        })
        .option("token0Amount", {
            type: "number",
            describe: "amount of token0 to add",
            default: 500,
        })
        .option("token1Amount", {
            type: "number",
            describe: "amount of token1 to add",
            default: 500,
        });
    return options.argv;
}

async function main() {
    let options: any = getOptions();
    const network = options.network;
    const poolAddress = options.poolAddress;
    let token0Amount = ethers.BigNumber.from(options.token0Amount.toString());
    let token1Amount = ethers.BigNumber.from(options.token1Amount.toString());

    let tronWeb: any;
    let tronWebWrapper: any;
    let nonfungiblePositionManagerAddress: string;
    if (network === "nile") {
        tronWebWrapper = new TronWebWrapper(
            "https://nile.trongrid.io",
            process.env.TRON_PRO_API_KEY,
            process.env.TRON_PRIVATE_KEY
        );
        tronWeb = tronWebWrapper.getTronWeb();
        nonfungiblePositionManagerAddress = "TPQzqHbCzQfoVdAV6bLwGDos8Lk2UjXz2R";
    } else if (network === "mainnet") {
        tronWebWrapper = new TronWebWrapper(
            "https://api.trongrid.io",
            process.env.TRON_PRO_API_KEY,
            process.env.TRON_PRIVATE_KEY
        );
        tronWeb = tronWebWrapper.getTronWeb();
        nonfungiblePositionManagerAddress = ""; // TODO:
    } else {
        throw new Error("Invalid network");
    }

    const poolContract = await tronWeb.contract(SunswapV3PoolAbi, poolAddress);
    const token0Address = await poolContract.token0().call();
    const token1Address = await poolContract.token1().call();
    console.log("token0Address: ", tronWebWrapper.hexToTronAddress(token0Address));
    console.log("token1Address: ", tronWebWrapper.hexToTronAddress(token1Address));

    const token0Contract = await tronWeb.contract(ERC20Artifact.abi, token0Address);
    const token1Contract = await tronWeb.contract(ERC20Artifact.abi, token1Address);

    const token0Decimals = await token0Contract.decimals().call();
    const token1Decimals = await token1Contract.decimals().call();
    const token0DecimalMultiplier = ethers.BigNumber.from(10).pow(token0Decimals);
    const token1DecimalMultiplier = ethers.BigNumber.from(10).pow(token1Decimals);
    token0Amount = token0Amount.mul(token0DecimalMultiplier);
    token1Amount = token1Amount.mul(token1DecimalMultiplier);

    const token0Allowance = await token0Contract
        .allowance(tronWebWrapper.account, nonfungiblePositionManagerAddress)
        .call();
    const token1Allowance = await token1Contract
        .allowance(tronWebWrapper.account, nonfungiblePositionManagerAddress)
        .call();

    if (token0Allowance.lt(token0Amount)) {
        console.log("token0 allowance is not enough, approve token0 first...");
        let approvetoken0Tx = await token0Contract.approve(nonfungiblePositionManagerAddress, token0Amount).send();
        console.log("approvetoken0Tx: ", approvetoken0Tx);
    } else {
        console.log("token0 allowance is enough, skip approve token0");
    }

    if (token1Allowance.lt(token1Amount)) {
        console.log("token1 allowance is not enough, approve token1 first...");
        let approveToken1Tx = await token1Contract.approve(nonfungiblePositionManagerAddress, token1Amount).send();
        console.log("approveToken1Tx: ", approveToken1Tx);
    } else {
        console.log("token1 allowance is enough, skip approve token1");
    }

    let toAddress = nonfungiblePositionManagerAddress;
    // let functionSelector = "mint(tuple)";
    let functionSelector = "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))";
    let parameter = [
        token0Address,
        token1Address,
        3000,
        -829440,
        829440,
        token0Amount,
        token1Amount,
        0,
        0,
        nonfungiblePositionManagerAddress,
        1945826874,
    ];

    let mintIndex = -1;
    for (let i = 0; i < NonfungiblePositionManagerAbi.length; i++) {
        if (NonfungiblePositionManagerAbi[i].name === "mint") {
            mintIndex = i;
            console.log("Found mint function at index:", i);
            break;
        }
    }

    const tx = await tronWeb.transactionBuilder.triggerSmartContract(
        toAddress,
        functionSelector,
        { funcABIV2: NonfungiblePositionManagerAbi[mintIndex], parametersV2: [parameter], feeLimit: 1000000000 },
        []
    );

    const signedTx = await tronWeb.trx.sign(tx.transaction);
    const result = await tronWeb.trx.sendRawTransaction(signedTx);
    console.log(result);
    console.log(result.transaction.raw_data.contract[0].parameter.value);

    // let res = await tronWebWrapper.estimateEnergy(
    //     toAddress,
    //     functionSelector,
    //     {
    //         funcABIV2: NonfungiblePositionManagerAbi[mintIndex],
    //         parametersV2: [parameter],
    //     },
    //     []
    // );
    // console.log(res);

    // let feeLimit = Math.ceil(res.sunRequired * 1.1);

    // if (res.accountBalance < feeLimit) {
    //     console.log("account does not have enough sun to send transaction, exiting...");
    //     return;
    // } else {
    //     try {
    //         const tx = await tronWeb.transactionBuilder.triggerSmartContract(
    //             toAddress,
    //             functionSelector,
    //             { feeLimit: feeLimit },
    //             parameter
    //         );

    //         const signedTx = await tronWeb.trx.sign(tx.transaction);
    //         const result = await tronWeb.trx.sendRawTransaction(signedTx);
    //         console.log(result);
    //     } catch (error) {
    //         console.error("Error sending transaction:", error);
    //     }
    // }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
