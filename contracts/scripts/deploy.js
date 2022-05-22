async function main() {
    const [deployer] = await ethers.getSigners();
  
    console.log("Deploying contracts with the account:", deployer.address);
  
    console.log("Account balance:", (await deployer.getBalance()).toString());
  
    const BoilerplateLending = await ethers.getContractFactory("BoilerplateLending");
    const boilerplateLending = await BoilerplateLending.deploy();
  
    console.log("Token address:", boilerplateLending.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });