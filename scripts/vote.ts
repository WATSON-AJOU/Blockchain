import { ethers } from "hardhat";

const CONTRACT_ADDRESS = "0x21702c98A10f4a5D258AB31b761e261937508122";

async function main() {
  const contract = await ethers.getContractAt(
    "WatsonNFT",
    CONTRACT_ADDRESS
  );

  const tx = await contract.voteForDocument(1, true);
  await tx.wait();

  console.log("Vote submitted");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});