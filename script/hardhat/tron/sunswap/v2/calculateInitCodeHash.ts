import { ethers } from "ethers";
import SunswapV2PairArtifact from "../../../abis/SunswapV2Pair.json";

async function main() {
    const bytecode = SunswapV2PairArtifact.bytecode;
    const initCodeHash = ethers.utils.keccak256(bytecode);
    console.log("SunswapV2Pair initCodeHash: ", initCodeHash);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
