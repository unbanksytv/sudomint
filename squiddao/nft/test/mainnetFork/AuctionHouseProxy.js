const { expect } = require("chai");
const { ethers } = require("hardhat");
const { impersonateAccount, stopImpersonateAccount } = require("../testUtils");
describe("MainnetFork", () => {
  let weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  let auctionHouse;
  let deployerAddress = "0x85277BD3D3273994Ce65FA1Bb9D0bf7Da0b1980b";
  let auctionHouseProxyAddress = "0xBD789bEddB50F9231Ea3e2ec76AFeB80C3e43Fc8";
  let newSquidDAONFT;
  let oldSquidDAONFTAddress = "0x31cae977e1cf721fc6b6f791deae2a37a6db6dba";
  let oldSquidDAONFT;

  it("changes implementation", async () => {
    var deployer = await impersonateAccount(deployerAddress);
    const squidDAONFTFactory = await ethers.getContractFactory("SquidDAONFT");

    oldSquidDAONFT = squidDAONFTFactory.attach(oldSquidDAONFTAddress);
    newSquidDAONFT = await squidDAONFTFactory.connect(deployer).deploy();

    await newSquidDAONFT.setAuctionHouse(auctionHouseProxyAddress);
    let baseURI = "ipfs://QmZg8yY13qegnucYpP5BvvHBV7172vr428RwqMKx8fCYEQ/";
    tx = await newSquidDAONFT.setBaseURI(baseURI);

    const auctionHouseFactory = await ethers.getContractFactory("AuctionHouse");
    auctionHouse = auctionHouseFactory.attach(auctionHouseProxyAddress);

    const newAuctionHouseFactory = await ethers.getContractFactory(
      "AuctionHouseV2"
    );
    const implementation = await newAuctionHouseFactory
      .connect(deployer)
      .deploy();
    await auctionHouse.connect(deployer).upgradeTo(implementation.address);
    auctionHouse = newAuctionHouseFactory.attach(auctionHouseProxyAddress);

    oldZeroOwner = await oldSquidDAONFT.ownerOf(0);
    oldTotalSupply = await oldSquidDAONFT.totalSupply();
    lastNFTOwner = await await oldSquidDAONFT.ownerOf(oldTotalSupply - 1); // last nft must be in auctionHouseProxy

    await auctionHouse
      .connect(deployer)
      .reMintAndSetNewNFT(newSquidDAONFT.address);
    expect(oldZeroOwner).to.eq(await newSquidDAONFT.ownerOf(0));
    expect(oldTotalSupply).to.eq(await newSquidDAONFT.totalSupply());
    expect(lastNFTOwner).to.eq(auctionHouseProxyAddress); // last nft must be in auctionHouseProxy
    expect(lastNFTOwner).to.eq(
      await newSquidDAONFT.ownerOf(oldTotalSupply - 1)
    ); // last nft must be in auctionHouseProxy
    expect(await auctionHouse.squidDAONFT()).to.eq(newSquidDAONFT.address);
  });
});
