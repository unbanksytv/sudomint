const { expect } = require("chai");
const { ethers, waffle } = require("hardhat");
const { impersonateAccount, stopImpersonateAccount } = require("../testUtils");
const treasuryAbi = require("../../abi/treasury.js");
const erc20Abi = require("../../abi/erc20.js");
const erc20 = require("../../abi/erc20.js");

describe("Ohm Bid", () => {
  let weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  let auctionHouse;
  let deployerAddress = "0x85277BD3D3273994Ce65FA1Bb9D0bf7Da0b1980b";
  let auctionHouseProxyAddress = "0xBD789bEddB50F9231Ea3e2ec76AFeB80C3e43Fc8";
  let treasuryAddress = "0x61d8a57b3919e9F4777C80b6CF1138962855d2Ca";
  let squidTokenAddress = "0x21ad647b8F4Fe333212e735bfC1F36B4941E6Ad2";
  let multiSigAddress = "0x42E61987A5CbA002880b3cc5c800952a5804a1C5";
  let squidApeAddress = "0x26Ff41364D8b1AeBCE855C3D356cEb9ef2d2280E";
  let ohmWhaleAddress = "0x955311354a9c35a6FE0BD5b8F388D8Ba102bb4BA";
  let ohmTokenAddress = "0x383518188C0C6d7730D91b2c03a03C837814a899";
  let ethWhaleAddress = "0x020cA66C30beC2c4Fe3861a94E4DB4A498A35872";
  it("changes implementation", async () => {
    // impersonate and some money to dao
    deployer = await impersonateAccount(deployerAddress);
    multiSig = await impersonateAccount(multiSigAddress);
    ohmWhale = await impersonateAccount(ohmWhaleAddress);
    ohm = new ethers.Contract(ohmTokenAddress, erc20Abi, waffle.provider);
    initialEtherBalance = await ohmWhale.getBalance();
    console.log(initialEtherBalance.toString());
    initialOhmBalance = await ohm.balanceOf(ohmWhaleAddress);
    console.log(initialOhmBalance.toString());

    // get proxy
    const auctionHouseFactory = await ethers.getContractFactory("AuctionHouse");
    auctionHouse = auctionHouseFactory.attach(auctionHouseProxyAddress);

    // deploy and upgrade and setup
    const implementation = await auctionHouseFactory.connect(deployer).deploy();
    await auctionHouse.connect(multiSig).upgradeTo(implementation.address);
    await auctionHouse.connect(multiSig).setOhm(ohmTokenAddress);
    await auctionHouse.connect(multiSig).setReservePrice("10000000"); // min 1 ohm;
    expect(await auctionHouse.ohm()).to.eq(ohmTokenAddress);
    await auctionHouse
      .connect(ohmWhale)
      .createBid(82, "0", { value: ethers.utils.parseEther("1") });
    afterEtherBalance = await ohmWhale.getBalance();
    console.log(afterEtherBalance.toString());
    await auctionHouse
      .connect(ohmWhale)
      .createBid(82, "0", { value: ethers.utils.parseEther("2") });
    afterEtherBalance = await ohmWhale.getBalance();
    console.log(afterEtherBalance.toString());
    await network.provider.send("evm_increaseTime", [60 * 60 * 24]); // for auction to concludes
    await network.provider.send("evm_mine");
    await auctionHouse.connect(ohmWhale).settleCurrentAndCreateNewAuction();

    await ohm.connect(ohmWhale).approve(auctionHouseProxyAddress, "1000000000"); // approve 100 ohm
    await auctionHouse.connect(ohmWhale).createBid(83, "10000000");
    expect(await ohm.balanceOf(auctionHouseProxyAddress)).to.eq("10000000");
    await auctionHouse.connect(ohmWhale).createBid(83, "20000000");
    expect(await ohm.balanceOf(auctionHouseProxyAddress)).to.eq("20000000");
  });
});
