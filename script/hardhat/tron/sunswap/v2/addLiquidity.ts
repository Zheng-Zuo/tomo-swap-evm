import dotenv from "dotenv";
import yargs from "yargs/yargs";
import { ethers } from "ethers";
import SunswapV2PairArtifact from "../../../abis/SunswapV2Pair.json";
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
        .option("pairAddress", {
            type: "string",
            describe: "sunswap v2 pair address",
            default: "TT8poFYLxgs8YzThaxYnBx9SEXSgafe5YQ", // Jst - Usdt
        })
        .option("token0Amount", {
            type: "number",
            describe: "amount of token0 to add",
            default: 1000,
        })
        .option("token1Amount", {
            type: "number",
            describe: "amount of token1 to add",
            default: 1000,
        });
    return options.argv;
}

async function main() {
    let options: any = getOptions();
    const network = options.network;
    const pairAddress = options.pairAddress;
    let token0Amount = ethers.BigNumber.from(options.token0Amount.toString());
    let token1Amount = ethers.BigNumber.from(options.token1Amount.toString());

    let tronWeb: any;
    let tronWebWrapper: any;
    let v2Router02Address: string;
    if (network === "nile") {
        tronWebWrapper = new TronWebWrapper(
            "https://nile.trongrid.io",
            process.env.TRON_PRO_API_KEY,
            process.env.TRON_PRIVATE_KEY
        );
        tronWeb = tronWebWrapper.getTronWeb();
        v2Router02Address = "TLk41GLBJWkFzfCDE1bintfCJkHwiZGgJB";
    } else if (network === "mainnet") {
        tronWebWrapper = new TronWebWrapper(
            "https://api.trongrid.io",
            process.env.TRON_PRO_API_KEY,
            process.env.TRON_PRIVATE_KEY
        );
        tronWeb = tronWebWrapper.getTronWeb();
        v2Router02Address = ""; // TODO:
    } else {
        throw new Error("Invalid network");
    }

    const pairContract = await tronWeb.contract(SunswapV2PairArtifact.abi, pairAddress);
    const token0Address = await pairContract.token0().call();
    const token1Address = await pairContract.token1().call();
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

    const token0Allowance = await token0Contract.allowance(tronWebWrapper.account, v2Router02Address).call();
    const token1Allowance = await token1Contract.allowance(tronWebWrapper.account, v2Router02Address).call();

    if (token0Allowance.lt(token0Amount)) {
        console.log("token0 allowance is not enough, approve token0 first...");
        let approvetoken0Tx = await token0Contract.approve(v2Router02Address, token0Amount).send();
        console.log("approvetoken0Tx: ", approvetoken0Tx);
    } else {
        console.log("token0 allowance is enough, skip approve token0");
    }

    if (token1Allowance.lt(token1Amount)) {
        console.log("token1 allowance is not enough, approve token1 first...");
        let approveToken1Tx = await token1Contract.approve(v2Router02Address, token1Amount).send();
        console.log("approveToken1Tx: ", approveToken1Tx);
    } else {
        console.log("token1 allowance is enough, skip approve token1");
    }

    let toAddress = v2Router02Address;
    let functionSelector = "addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)";
    let parameter = [
        { type: "address", value: token0Address },
        { type: "address", value: token1Address },
        { type: "uint256", value: token0Amount },
        { type: "uint256", value: token1Amount },
        { type: "uint256", value: 0 },
        { type: "uint256", value: 0 },
        { type: "address", value: tronWebWrapper.account },
        { type: "uint256", value: 1806738457 },
    ];

    let res = await tronWebWrapper.estimateEnergy(toAddress, functionSelector, {}, parameter);
    console.log(res);

    let feeLimit = Math.ceil(res.sunRequired * 1.1);

    if (res.accountBalance < feeLimit) {
        console.log("account does not have enough sun to send transaction, exiting...");
        return;
    } else {
        try {
            const tx = await tronWeb.transactionBuilder.triggerSmartContract(
                toAddress,
                functionSelector,
                { feeLimit: feeLimit },
                parameter
            );

            const signedTx = await tronWeb.trx.sign(tx.transaction);
            const result = await tronWeb.trx.sendRawTransaction(signedTx);
            console.log(result);
        } catch (error) {
            console.error("Error sending transaction:", error);
        }
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
