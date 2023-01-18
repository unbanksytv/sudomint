const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AuctionHouseProxy", () => {
  let accounts;
  let admin, adminAddress;
  let user1, user1Address;
  let weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  let auctionHouse;

  beforeEach(async () => {
    accounts = await ethers.getSigners();
    admin = accounts[0];
    adminAddress = await admin.getAddress();
    user1 = accounts[1];
    user1Address = await user1.getAddress();
    const squidDAONFTFactory = await ethers.getContractFactory("SquidDAONFT");
    const squidDAONFT = await squidDAONFTFactory.deploy();
    const auctionHouseFactory = await ethers.getContractFactory("AuctionHouse");
    const implementation = await auctionHouseFactory.deploy();
    const fragment = auctionHouseFactory.interface.getFunction("initialize");
    const initData = auctionHouseFactory.interface.encodeFunctionData(
      fragment,
      [
        squidDAONFT.address,
        weth,
        300, // 5min
        ethers.BigNumber.from("1000000000000000000"), // 1 ether
        5,
        3600, // 60 min one auction
      ]
    );
    const auctionHouseProxyFactory = await ethers.getContractFactory(
      "AuctionHouseProxy"
    );
    const proxy = await auctionHouseProxyFactory.deploy(
      implementation.address,
      initData
    );

    auctionHouse = auctionHouseFactory.attach(proxy.address);
  });

  it("changes implementation", async () => {
    const auctionHouseFactory = await ethers.getContractFactory(
      "AuctionHouseExtension"
    );
    const implementation = await auctionHouseFactory.deploy();
    await auctionHouse.upgradeTo(implementation.address);
    auctionHouse = auctionHouseFactory.attach(auctionHouse.address);
    expect(await auctionHouse.test()).to.eq("test");
  });
});
