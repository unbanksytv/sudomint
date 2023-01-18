const { expect } = require("chai");
const { ethers, waffle } = require("hardhat");
const { impersonateAccount, stopImpersonateAccount } = require("../testUtils");
const treasuryAbi = require("../../abi/treasury.js");
const erc20Abi = require("../../abi/erc20.js");

describe("AutoMint", () => {
  let weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  let auctionHouse;
  let deployerAddress = "0x85277BD3D3273994Ce65FA1Bb9D0bf7Da0b1980b";
  let auctionHouseProxyAddress = "0xBD789bEddB50F9231Ea3e2ec76AFeB80C3e43Fc8";
  let treasuryAddress = "0x61d8a57b3919e9F4777C80b6CF1138962855d2Ca";
  let squidTokenAddress = "0x21ad647b8F4Fe333212e735bfC1F36B4941E6Ad2";
  let multiSigAddress = "0x42E61987A5CbA002880b3cc5c800952a5804a1C5";
  let squidApeAddress = "0x26Ff41364D8b1AeBCE855C3D356cEb9ef2d2280E";

  it("changes implementation", async () => {
    // setup block and time
    for (i = 0; i < 250; i++) {
      await network.provider.send("evm_mine"); // for toggling
    }

    // impersonate and some money to dao
    deployer = await impersonateAccount(deployerAddress);
    multiSig = await impersonateAccount(multiSigAddress);
    squidApe = await impersonateAccount(squidApeAddress);
    await deployer.sendTransaction({
      to: multiSigAddress,
      value: ethers.utils.parseEther("1"),
    });

    // toggle reserve token depositor
    const treasury = new ethers.Contract(
      treasuryAddress,
      treasuryAbi,
      waffle.provider
    );
    await treasury
      .connect(deployer)
      .toggle(0, auctionHouseProxyAddress, ethers.constants.AddressZero);

    // get proxy
    const auctionHouseFactory = await ethers.getContractFactory("AuctionHouse");
    auctionHouse = auctionHouseFactory.attach(auctionHouseProxyAddress);

    // deploy and upgrade and setup
    const implementation = await auctionHouseFactory.connect(deployer).deploy();
    await auctionHouse.connect(multiSig).upgradeTo(implementation.address);
    await auctionHouse.connect(multiSig).setSquidToken(squidTokenAddress);
    await auctionHouse.connect(multiSig).setTreasury(treasuryAddress);
    expect(await auctionHouse.squidToken()).to.eq(squidTokenAddress);
    expect(await auctionHouse.treasury()).to.eq(treasuryAddress);

    await auctionHouse
      .connect(squidApe)
      .createBid(43, { value: ethers.utils.parseEther("1") });
    await network.provider.send("evm_increaseTime", [60 * 60 * 7]); // for auction to concludes
    await network.provider.send("evm_mine");

    await auctionHouse.connect(squidApe).settleCurrentAndCreateNewAuction();

    // checks
    squidToken = new ethers.Contract(
      squidTokenAddress,
      erc20Abi,
      waffle.provider
    );
    squidBalance = await squidToken.balanceOf(squidApeAddress);
    expect(squidBalance.toString()).to.eq("1000000000");
  });
});
