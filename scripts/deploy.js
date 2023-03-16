async function main() {
    const signer = await ethers.getSigner();
    const balance = await ethers.provider.getBalance(signer.address);

    console.info(
        "Deployer balance (",
        signer.address,
        "):",
        ethers.utils.formatEther(balance.toString()),
        "Ether"
    );

    const Casino = await hre.ethers.getContractFactory("Casino");
    const casino = await Casino.deploy();

    const tx = await casino.deployed();
    console.info(tx);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
