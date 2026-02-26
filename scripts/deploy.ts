import { ethers } from "hardhat";

async function main() {
  console.log("Deploying WatsonNFT...");

  const WatsonNFT = await ethers.getContractFactory("WatsonNFT");
  const contract = await WatsonNFT.deploy();

  await contract.waitForDeployment();

  const address = await contract.getAddress();

  console.log("WatsonNFT deployed to:", address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});