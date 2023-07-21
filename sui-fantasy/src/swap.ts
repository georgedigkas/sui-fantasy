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
const oracleId = process.env.ORACLE_ID!;

let transactionBlock = new TransactionBlock();

transactionBlock.moveCall({
  target: `${packageId}::${moduleName}::swap`,
  arguments: [
    transactionBlock.object(
      "0x4994b9282d45ea1df47a6b94755682bafdb7c333b2e63b147dddeb3db9a59726"
    ),
    transactionBlock.object(oracleId),
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
