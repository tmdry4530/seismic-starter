import {
    createShieldedWalletClient,
    type ShieldedContract,
    type ShieldedWalletClient,
} from "seismic-viem";
import { Chain, http } from "viem";

import {
    getShieldedContractWithCheck,
    readContractAddress,
    readContractABI,
} from "../lib/utils";

interface AppConfig {
    wallet: {
        chain: Chain;
        rpcUrl: string;
        privateKey: string;
    };
    contract: {
        abiFile: string;
        broadcastFile: string;
    };
}

export class App { 
    private config: AppConfig;
    
    private contract!: ShieldedContract;
    private walletClient!: ShieldedWalletClient;

    constructor(config: AppConfig) {
        this.config = config;
    }

    async init() {
        this.walletClient = await createShieldedWalletClient({
            chain: this.config.wallet.chain,
            transport: http(this.config.wallet.rpcUrl),
            privateKey: this.config.wallet.privateKey as `0x${string}`,
        });

        this.contract = await getShieldedContractWithCheck(
            this.walletClient,
            readContractABI(this.config.contract.abiFile),
            readContractAddress(this.config.contract.broadcastFile),
        );
    }

    async reset() {
        console.log("- Writing reset()");
        await this.walletClient.waitForTransactionReceipt({
            hash: await this.contract.write.reset(),
        });
    }

    async shake() {
        console.log("- Writing shake()");
        await this.walletClient.waitForTransactionReceipt({
            hash: await this.contract.write.shake(),
        });
    }

    async hit() {
        console.log("- Writing hit()");
        await this.walletClient.waitForTransactionReceipt({
            hash: await this.contract.write.hit(),
        });
    }

    async look() {
        const res = await this.contract.read.look();
        console.log("- Reading look():", res);
    }
}
