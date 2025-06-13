const TronWeb = require("tronweb");

class TronWebWrapper {
    private fullHost: string;
    private apiKey: string;
    private privateKey: string;
    private tronWeb: any;
    public energyPrice: number;
    public account: string;

    constructor(fullHost: string = "https://api.trongrid.io", apiKey: string = "", privateKey: string = "") {
        this.fullHost = fullHost;
        this.apiKey = apiKey;
        this.privateKey = privateKey;
        this.tronWeb = new TronWeb({
            fullHost: this.fullHost,
            headers: { "TRON-PRO-API-KEY": this.apiKey },
            privateKey: this.privateKey,
        });
        this.energyPrice = 0.00021 * 1e6;
        this.account = this.tronWeb.address.fromPrivateKey(this.privateKey);
    }

    public getTronWeb(): any {
        return this.tronWeb;
    }

    public tronAddressToHex(tronAddress: string) {
        try {
            const hexAddress = this.tronWeb.address.toHex(tronAddress);
            return "0x" + hexAddress.slice(2);
        } catch (error) {
            console.error("Error converting TRON address:", error);
            return null;
        }
    }

    public hexToTronAddress(hexAddress: string) {
        try {
            const address = "41" + hexAddress.slice(2);
            return this.tronWeb.address.fromHex(address);
        } catch (error) {
            console.error("Error converting hex address:", error);
            return null;
        }
    }

    public async estimateEnergy(
        toAddress: string,
        functionSelector: string,
        options: any = {},
        parameter: any = [],
        senderAddress: string = this.account
    ) {
        try {
            // const estimateEnergy = await this.tronWeb.transactionBuilder.estimateEnergy(
            //     toAddress,
            //     functionSelector,
            //     options,
            //     parameter
            // );

            // tron mainnet does not support estimateEnergy, use triggerConstantContract instead,
            // but the result is less than the actual energy required, so fee limit is set to 2 times the estimated fee amount
            const estimateEnergyV2 = await this.tronWeb.transactionBuilder.triggerConstantContract(
                toAddress,
                functionSelector,
                options,
                parameter
            );

            console.log("raw data hex: ", estimateEnergyV2.transaction.raw_data_hex);

            const energyRequired = estimateEnergyV2["energy_used"];
            const sunRequired = this.energyPrice * energyRequired;
            const accountBalance = await this.tronWeb.trx.getBalance(senderAddress);

            return {
                energyRequired,
                sunRequired,
                accountBalance,
            };
        } catch (error) {
            console.error("Error estimating energy:", error);
            // console.log("use default gas limit");
            // const energyRequired = -1;
            // const sunRequired = 150 * 1e6;
            // const accountBalance = await this.tronWeb.trx.getBalance(senderAddress);

            // return {
            //     energyRequired,
            //     sunRequired,
            //     accountBalance,
            // };
            return null;
        }
    }
}

export default TronWebWrapper;
