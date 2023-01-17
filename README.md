## Randomized tiered airdrop collection

## MDDA On Chain Dutch Auction with refund system

Imagine running true Dutch auctions within NFT sales. This implementation is the exact same one used for the KiwamiNFT drop. Note that the current version is highly experimental and could include a myriad of breaking bugs. Therefore, please use with extreme caution. One of the key features of MDDA is the admin has little to no control over modifying sale parameters after the auction has been set. This removes any ability for the admin to rug or adjust auction sale details once it has begun. For this reason, it is not to be used carelessly. A simple example is the auction start time. Once set, it cannot be adjusted. This gives the team and community confidence that the admin cannot adjust it to call withdrawFinalFunds, which pulls all contract funds, include any pending refunds. Additional safeguards are in place as well. The initial funds withdrawal function accounts for pending refunds, meaning you can be confident your refund is safe within the contract for at least one week. MDDA also provides the user full control over their refund. The admin is not responsible for sending refunds. This has a few implications: 

One, it puts the power in the hands of the users and removes any ability for the admin to control a user’s refund. 

Two, it also avoids poor coding practices of having massive loops run within a single call.

Three, it also avoids the recent attack seen with AkuDreams, where an exploiter was able to inject a malicious refund that never went to completion, which removed the ability for anyone to call the processRefunds function until the exploiter relinquished control.

Disclaimer: This code is still a rough draft. There could very well be major breaking bugs. There are not yet many unit tests. Please use this with discretion and make sure you fully understand the code before using it. Any and all scrutiny is welcome.

## Getting Started

Create a project using this example:

```bash
npx thirdweb create --contract --template hardhat-javascript-starter
```

You can start editing the page by modifying `contracts/Contract.sol`.

To add functionality to your contracts, you can use the `@thirdweb-dev/contracts` package which provides base contracts and extensions to inherit. The package is already installed with this project. Head to our [Contracts Extensions Docs](https://portal.thirdweb.com/contractkit) to learn more.

## Building the project

After any changes to the contract, run:

```bash
npm run build
# or
yarn build
```

to compile your contracts. This will also detect the [Contracts Extensions Docs](https://portal.thirdweb.com/contractkit) detected on your contract.

## Deploying Contracts

When you're ready to deploy your contracts, just run one of the following command to deploy you're contracts:

```bash
npm run deploy
# or
yarn deploy
```

## Releasing Contracts

If you want to release a version of your contracts publicly, you can use one of the followings command:

```bash
npm run release
# or
yarn release
```

## Join our Discord!

For any questions, suggestions, join our discord at [https://discord.gg/thirdweb](https://discord.gg/thirdweb).

## Experimental Contracts

mdda.sol "running true Dutch auctions within NFT sales"

Bondstyle and Asset Backed 721 experiments

an implementation of an ERC-721 token contract that is backed by a specific asset, such as an ERC-20 token. Overall, it looks like it's implementing the correct logic and using the OpenZeppelin libraries correctly. It's good practice to use the SafeMath library to perform arithmetic operations in order to protect against overflow/underflow errors.

The _mint and _burn functions are marked as internal, which means that they can only be called by other functions within the contract. It might be better to make them external, so that they can be called by other contracts or external users.

The _mint and _burn functions are virtual, which means that they can be overridden by derived contracts.
It is important to be aware that if you plan to inherit this contract, and want to use these functions, you should use the keyword override for these functions.

We might want to consider adding some additional functionality or constraints, such as:

A way to check the total supply of the token
A way to check the balance of an address
A way to check the token id of an owner
