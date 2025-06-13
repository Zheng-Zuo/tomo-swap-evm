import { ethers } from "ethers";
import TronWebWrapper from "../wrapper";
import TomoSwapRouterNileArtifact from "../../abis/TomoSwapRouterNile.json";
import TomoSwapRouterTronArtifact from "../../abis/TomoSwapRouterTron.json";
import dotenv from "dotenv";
import yargs from "yargs/yargs";

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
    let tronWebWrapper: any;
    let tomoSwapRouterArtifact: any;
    let routerParameters: any;
    if (network === "nile") {
        tronWebWrapper = new TronWebWrapper(
            "https://nile.trongrid.io",
            process.env.TRON_PRO_API_KEY,
            process.env.TRON_PRIVATE_KEY
        );
        tronWeb = tronWebWrapper.getTronWeb();
        tomoSwapRouterArtifact = TomoSwapRouterNileArtifact;
        routerParameters = {
            permit2: tronWebWrapper.tronAddressToHex("TMw3MtL3WJeVG9nbsXDDrukjTVryQrQu5F"),
            weth9: tronWebWrapper.tronAddressToHex("TYsbWxNnyTgsZaTFaue9hqpxkU3Fkco94a"),
            uniV2Factory: tronWebWrapper.tronAddressToHex("TCfSVcHd8oYvjvbc4gNpH1PgVQr1cU9hAZ"),
            uniV3Factory: tronWebWrapper.tronAddressToHex("TUTGcsGDRScK1gsDPMELV2QZxeESWb1Gac"),
            uniPairInitCodeHash: "0x87023e57a3ac097bce41497764d81c82e61c9104d55ce94ef37e7e8ecdea1bb0",
            uniPoolInitCodeHash: "0xbdafe9a36668104a2d371dedf31aac9583722f1b2c2fe98dde229f50a1e81689",
            cakeV2Factory: "0x0000000000000000000000000000000000000000",
            cakeV3Factory: "0x0000000000000000000000000000000000000000",
            cakeV3Deployer: "0x0000000000000000000000000000000000000000",
            cakePairInitCodeHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
            cakePoolInitCodeHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
            cakeStableFactory: "0x0000000000000000000000000000000000000000",
            cakeStableInfo: "0x0000000000000000000000000000000000000000",
            sushiV2Factory: "0x0000000000000000000000000000000000000000",
            sushiV3Factory: "0x0000000000000000000000000000000000000000",
            sushiPairInitCodeHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
            sushiPoolInitCodeHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
        };
    } else if (network === "mainnet") {
        tronWebWrapper = new TronWebWrapper(
            "https://api.trongrid.io",
            process.env.TRON_PRO_API_KEY,
            process.env.TRON_PRIVATE_KEY
        );
        tronWeb = tronWebWrapper.getTronWeb();
        tomoSwapRouterArtifact = TomoSwapRouterTronArtifact;
        routerParameters = {
            permit2: tronWebWrapper.tronAddressToHex("TDJNTBi51CnnpCYYgi6GitoT4CJWrqim2G"),
            weth9: tronWebWrapper.tronAddressToHex("TNUC9Qb1rRpS5CbWLmNMxXBjyFoydXjWFR"),
            uniV2Factory: tronWebWrapper.tronAddressToHex("TKWJdrQkqHisa1X8HUdHEfREvTzw4pMAaY"),
            uniV3Factory: tronWebWrapper.tronAddressToHex("TThJt8zaJzJMhCEScH7zWKnp5buVZqys9x"),
            uniPairInitCodeHash: "0x6d3f89421f83e4b62e628de8fc7ff2b014a79bf8fd8e8b0ea46e4a1d9409b67d",
            uniPoolInitCodeHash: "0xba928a717d71946d75999ef1adef801a79cd34a20efecea8b2876b85f5f49580",
            cakeV2Factory: "0x0000000000000000000000000000000000000000",
            cakeV3Factory: "0x0000000000000000000000000000000000000000",
            cakeV3Deployer: "0x0000000000000000000000000000000000000000",
            cakePairInitCodeHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
            cakePoolInitCodeHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
            cakeStableFactory: "0x0000000000000000000000000000000000000000",
            cakeStableInfo: "0x0000000000000000000000000000000000000000",
            sushiV2Factory: "0x0000000000000000000000000000000000000000",
            sushiV3Factory: "0x0000000000000000000000000000000000000000",
            sushiPairInitCodeHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
            sushiPoolInitCodeHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
        };
    } else {
        throw new Error("Invalid network");
    }

    let values = [
        routerParameters.permit2,
        routerParameters.weth9,
        routerParameters.uniV2Factory,
        routerParameters.uniV3Factory,
        routerParameters.uniPairInitCodeHash,
        routerParameters.uniPoolInitCodeHash,
        routerParameters.cakeV2Factory,
        routerParameters.cakeV3Factory,
        routerParameters.cakeV3Deployer,
        routerParameters.cakePairInitCodeHash,
        routerParameters.cakePoolInitCodeHash,
        routerParameters.cakeStableFactory,
        routerParameters.cakeStableInfo,
        routerParameters.sushiV2Factory,
        routerParameters.sushiV3Factory,
        routerParameters.sushiPairInitCodeHash,
        routerParameters.sushiPoolInitCodeHash,
    ];

    const tx = await tronWeb.transactionBuilder.createSmartContract(
        {
            abi: tomoSwapRouterArtifact.abi,
            bytecode: tomoSwapRouterArtifact.bytecode,
            funcABIV2: tomoSwapRouterArtifact.abi[0],
            parametersV2: [values],
            feeLimit: 20_00_000_000,
        },
        tronWebWrapper.account
    );

    const signedTx = await tronWeb.trx.sign(tx);
    const result = await tronWeb.trx.sendRawTransaction(signedTx);
    console.log(result);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

// nile: TNZndMV9cxz4vxvAmEsoi7JJXaqutoJwRi
// mainnet: TM9y9N5RoEkHFxAwkbzYu1Sz72DKeLYprS
