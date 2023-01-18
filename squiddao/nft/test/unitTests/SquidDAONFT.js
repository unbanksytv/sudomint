const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SquidDAONFT", () => {
  let accounts;
  let admin, adminAddress;
  let user1, user1Address;
  let weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  let squidDAONFT;

  beforeEach(async () => {
    accounts = await ethers.getSigners();
    admin = accounts[0];
    adminAddress = await admin.getAddress();
    user1 = accounts[1];
    user1Address = await user1.getAddress();
    const squidDAONFTFactory = await ethers.getContractFactory("SquidDAONFT");
    squidDAONFT = await squidDAONFTFactory.deploy();
    await squidDAONFT.setAuctionHouse(adminAddress);
  });

  it("mint", async () => {
    await squidDAONFT.mint(user1Address);
    expect(await squidDAONFT.balanceOf(user1Address)).to.eq(1);
  });
  it("set token URI", async () => {
    let tokenURI = "https://test.com/1";
    let baseURI = "https://base.com/";
    await squidDAONFT.setTokenURI(0, tokenURI);
    await squidDAONFT.setBaseURI(baseURI);
    await squidDAONFT.mint(user1Address);
    expect(await squidDAONFT.tokenURI(0)).to.eq(tokenURI);
    await squidDAONFT.mint(user1Address);
    expect(await squidDAONFT.tokenURI(1)).to.eq(`${baseURI}1`);
  });
});
