import { ethers, network } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying WatsonNFT...");
  console.log("Network:", network.name);
  console.log("Deployer:", deployer.address);

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
