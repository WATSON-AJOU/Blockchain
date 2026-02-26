import { ethers } from "hardhat";

const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS ?? "";
const TOKEN_ID = Number(process.env.TOKEN_ID ?? "1");
const IS_ORIGINAL = (process.env.IS_ORIGINAL ?? "true").toLowerCase() === "true";

async function main() {
  if (!CONTRACT_ADDRESS) {
    throw new Error("CONTRACT_ADDRESS env is required");
  }

  const [voter] = await ethers.getSigners();
  console.log("Using voter:", voter.address);

  const contract = await ethers.getContractAt("WatsonNFT", CONTRACT_ADDRESS);

  const voterBalance = await contract.balanceOf(voter.address);
  if (voterBalance === 0n) {
    throw new Error("Only NFT holders can vote. Current signer has 0 NFT.");
  }

  const doc = await contract.documents(TOKEN_ID);
  if (doc.status !== 0n) {
    throw new Error(`Token ${TOKEN_ID} is not Pending (status=${doc.status})`);
  }

  if (doc.endTime <= BigInt(Math.floor(Date.now() / 1000))) {
    throw new Error(`Voting already ended for token ${TOKEN_ID}`);
  }

  const alreadyVoted = await contract.hasVoted(TOKEN_ID, voter.address);
  if (alreadyVoted) {
    throw new Error(`Signer already voted for token ${TOKEN_ID}`);
  }

  const tx = await contract.voteForDocument(TOKEN_ID, IS_ORIGINAL);
  const receipt = await tx.wait();

  console.log("Vote submitted. Tx hash:", receipt?.hash);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
