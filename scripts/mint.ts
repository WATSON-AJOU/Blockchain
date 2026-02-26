import { ethers } from "hardhat";

const CONTRACT_ADDRESS = "0x21702c98A10f4a5D258AB31b761e261937508122";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Using account:", deployer.address);

  const contract = await ethers.getContractAt(
    "WatsonNFT",
    CONTRACT_ADDRESS
  );

  // minter 권한 부여 (owner만 가능)
  const setMinterTx = await contract.setMinter(deployer.address, true);
  await setMinterTx.wait();
  console.log("Minter authorized");

  // 테스트용 fileHash 생성
  const fileHash = ethers.keccak256(
    ethers.toUtf8Bytes("test-file-1")
  );

  // mint 실행
  const mintTx = await contract.mintDocument(
    deployer.address,
    1,                      // wmId
    fileHash,
    Math.floor(Date.now() / 1000),
    "ipfs://test-metadata",
    true                    // isSuspicious → Pending 상태
  );

  await mintTx.wait();

  console.log("Mint complete");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});