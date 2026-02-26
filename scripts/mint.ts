import { ethers } from "hardhat";

const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS ?? "";
const WM_ID = Number(process.env.WM_ID ?? "1");
const TOKEN_URI = process.env.TOKEN_URI ?? "ipfs://test-metadata";
const IS_SUSPICIOUS = (process.env.IS_SUSPICIOUS ?? "true").toLowerCase() === "true";
const FILE_HASH_SEED = process.env.FILE_HASH_SEED ?? `test-file-${WM_ID}`;

async function main() {
  if (!CONTRACT_ADDRESS) {
    throw new Error("CONTRACT_ADDRESS env is required");
  }

  const [signer] = await ethers.getSigners();
  console.log("Using account:", signer.address);

  const contract = await ethers.getContractAt("WatsonNFT", CONTRACT_ADDRESS);

  const owner = await contract.owner();
  const isMinter = await contract.authorizedMinters(signer.address);

  if (!isMinter) {
    if (owner.toLowerCase() !== signer.address.toLowerCase()) {
      throw new Error("Signer is not a minter and cannot self-authorize (owner only)");
    }

    const setMinterTx = await contract.setMinter(signer.address, true);
    await setMinterTx.wait();
    console.log("Minter authorized for signer");
  }

  const fileHash = ethers.keccak256(ethers.toUtf8Bytes(FILE_HASH_SEED));

  const mintTx = await contract.mintDocument(
    signer.address,
    WM_ID,
    fileHash,
    Math.floor(Date.now() / 1000),
    TOKEN_URI,
    IS_SUSPICIOUS
  );

  const receipt = await mintTx.wait();
  console.log("Mint complete. Tx hash:", receipt?.hash);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
