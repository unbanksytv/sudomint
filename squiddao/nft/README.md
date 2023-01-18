# Squid DAO NFT



## Table of Contents

- [Install](#install)
- [Secret](#secret)
- [Commands](#commands)
- [Addresses](#addresses)
- [Functions](#function)
- [License](#license)

## Install

```bash
# Install project dependencies
npm install
```

## Secret
You should setup a ```secret.json``` file with the following content, and place the file in the root of this project.
```json
{
    "infuraProjectId":"", 
    "privateKey":"", 
    "etherscanApiKey":"",
    "coinMarketCapApiKey":""
}
```

## Commands

```bash
# Lint code
npm run lint

# Format code
npm run format

# Unit test coverage
npm run coverage

# Run test and generate gas usage report
npm run unit-test

# Run main net fork test
npm run integration-test
```
## Addresses

The contract are deployed and available on the following blockchains:

Ethereum mainnet deployment:
- AuctionHouseProxy: [0xbd789beddb50f9231ea3e2ec76afeb80c3e43fc8](https://etherscan.io/address/0xbd789beddb50f9231ea3e2ec76afeb80c3e43fc8#code)
- SquidDAONFT: [0x7136ca86129e178399b703932464df8872f9a57a](https://etherscan.io/address/0x7136ca86129e178399b703932464df8872f9a57a#code)

Testnet deployment on Rinkeby:

## Function

## License
 
GPL-3.0
