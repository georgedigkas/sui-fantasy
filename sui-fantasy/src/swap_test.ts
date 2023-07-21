import {
  Connection,
  Ed25519Keypair,
  JsonRpcProvider,
  RawSigner,
  TransactionBlock,
} from "@mysten/sui.js";
import * as dotenv from "dotenv";

dotenv.config({ path: "../.env" });

const phrase = process.env.ADMIN_PHRASE;
const fullnode = process.env.FULLNODE!;
const keypair = Ed25519Keypair.deriveKeypair(phrase!);
const adminAddress = keypair.getPublicKey().toSuiAddress();
const provider = new JsonRpcProvider(
  new Connection({
    fullnode: fullnode,
  })
);
const signer = new RawSigner(keypair, provider);
const moduleName = "fantasy_wallet";
const packageId = process.env.PACKAGE_ID;

let transactionBlock = new TransactionBlock();

transactionBlock.moveCall({
  target: `${packageId}::${moduleName}::swap_test`,
  arguments: [
    transactionBlock.object(
      "0xcbcc46eba87aa6fc02f9155cfc1b59167d94826200076de2ecaf87dda6e71602"
    ),
    transactionBlock.pure("sui"),
    transactionBlock.pure("eth"),
    transactionBlock.pure(1000),
  ],
});

transactionBlock.setGasBudget(10000000);
signer
  .signAndExecuteTransactionBlock({
    transactionBlock,
    requestType: "WaitForLocalExecution",
    options: {
      showObjectChanges: true,
      showEffects: true,
    },
  })
  .then((result) => {
    console.log(result);
  });
