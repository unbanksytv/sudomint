/**
 * @type import('hardhat/config').HardhatUserConfig
 */
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");
require("hardhat-gas-reporter");
require("solidity-coverage");
const {
  infuraProjectId,
  privateKey,
  etherscanApiKey,
  coinMarketCapApiKey,
  rinkebyPrivateKey,
} = require("./secrets.json");
const deployer = "0x51e8c347F85082603b90dD1381e128DEdC825b49";
const mockWeth = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";

task("deploy-upgrade", async (_, hre) => {
  let auctionHouseProxyAddress = "0xbd789beddb50f9231ea3e2ec76afeb80c3e43fc8"; // mainnet proxy

  const squidDAONFTFactory = await ethers.getContractFactory("SquidDAONFT");

  newSquidDAONFT = await squidDAONFTFactory.deploy();
  await newSquidDAONFT.deployed();
  console.log(`new NFT ${newSquidDAONFT.address}`);

  tx = await newSquidDAONFT.setAuctionHouse(auctionHouseProxyAddress);
  console.log(`setAuctionHouse hash ${tx.hash}`);
  await tx.wait();
  let baseURI = "ipfs://QmZg8yY13qegnucYpP5BvvHBV7172vr428RwqMKx8fCYEQ/";
  tx = await newSquidDAONFT.setBaseURI(baseURI);
  console.log(`setBaseURI hash ${tx.hash}`);
  await tx.wait();

  const auctionHouseFactory = await ethers.getContractFactory("AuctionHouse");
  auctionHouse = auctionHouseFactory.attach(auctionHouseProxyAddress);

  const newAuctionHouseFactory = await ethers.getContractFactory(
    "AuctionHouseV2"
  );
  const implementation = await newAuctionHouseFactory.deploy();
  console.log(`new impl addr ${implementation.address}`);
  await implementation.deployed();
  tx = await auctionHouse.upgradeTo(implementation.address);
  console.log(`upgradeTo hash ${tx.hash}`);
  await tx.wait();

  auctionHouse = newAuctionHouseFactory.attach(auctionHouseProxyAddress);
  tx = await auctionHouse.reMintAndSetNewNFT(newSquidDAONFT.address);
  console.log(`remint hash ${tx.hash}`);
  await tx.wait();
});

task("deploy-auction", async (_, hre) => {
  const squidDAONFTFactory = await ethers.getContractFactory("SquidDAONFT");
  const auctionHouseFactory = await ethers.getContractFactory("AuctionHouse");
  const auctionHouseProxyFactory = await ethers.getContractFactory(
    "AuctionHouseProxy"
  );

  squidDAONFT = await squidDAONFTFactory.deploy({
    gasLimit: ethers.BigNumber.from("2000000"),
  });
  await squidDAONFT.deployed();

  console.log(`squidDAONFT ${squidDAONFT.address}`);

  const implementation = await auctionHouseFactory.deploy({
    gasLimit: ethers.BigNumber.from("2500000"),
  });
  await implementation.deployed();
  console.log(`auctionHouse implementation ${implementation.address}`);

  const fragment = auctionHouseFactory.interface.getFunction("initialize");
  const initData = auctionHouseFactory.interface.encodeFunctionData(fragment, [
    "0x31CAe977e1cF721Fc6B6f791DEAe2a37A6Db6DBa",
    mockWeth,
    300, // 5min
    ethers.BigNumber.from("1000000000000000000"), // 1 ether
    5,
    60 * 60 * 24, // 24hr
  ]);

  const proxy = await auctionHouseProxyFactory.deploy(
    implementation.address,
    initData,
    { gasLimit: ethers.BigNumber.from("500000") }
  );
  await proxy.deployed();
  console.log(`auctionHouse proxy ${proxy.address}`);
  await squidDAONFT.setAuctionHouse(proxy.address);
});

task("verify-auction", async (_, hre) => {
  squidDAONFTAddress = "0x7136Ca86129E178399B703932464dF8872F9A57a";
  impl = "0x64e20B6EeD66c6D70A234596F0194e56D3ee9E42";
  proxy = "0xBD789bEddB50F9231Ea3e2ec76AFeB80C3e43Fc8";
  addresses = [squidDAONFTAddress, impl];
  for (i = 0; i < addresses.length; i++) {
    verifyResult = await hre.run("verify:verify", {
      address: addresses[i],
    });
    console.log(verifyResult);
  }

  // const auctionHouseFactory = await ethers.getContractFactory("AuctionHouse");
  // const fragment = auctionHouseFactory.interface.getFunction("initialize");
  // const initData = auctionHouseFactory.interface.encodeFunctionData(
  //   fragment,
  //   [
  //     squidDAONFTAddress,
  //     mockWeth,
  //     300, // 5min
  //     ethers.BigNumber.from("1000000000000000000"), // 1 ether
  //     5,
  //     60 * 60 * 24, // 24hr
  //   ],
  //   { gasLimit: "800000" }
  // );
  // verifyResult = await hre.run("verify:verify", {
  //   address: proxy,
  //   contract: "contracts/AuctionHouseProxy.sol:AuctionHouseProxy",
  //   constructorArguments: [impl, initData],
  // });
  // console.log(verifyResult);
});
module.exports = {
  defaultNetwork: "hardhat",
  solidity: {
    version: "0.8.7",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  etherscan: {
    apiKey: etherscanApiKey,
  },
  networks: {
    mainnet: {
      url: `https://mainnet.infura.io/v3/${infuraProjectId}`,
      // accounts: [`0x${privateKey}`],
      gasPrice: 300000000000,
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${infuraProjectId}`,
      // accounts: [`0x${rinkebyPrivateKey}`],
    },
    hardhat: {
      forking: {
        url: "https://mainnet-eth.compound.finance/",
        blockNumber: 13518840,
        // accounts: [`0x${privateKey}`],
      },
    },
  },
  mocha: {
    timeout: 600000,
  },
  gasReporter: {
    currency: "USD",
    coinmarketcap: coinMarketCapApiKey,
  },
};
