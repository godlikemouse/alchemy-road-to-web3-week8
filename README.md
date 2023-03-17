# Alchemy's Road to Web3 Week 8

This repository covers the modified code following Alchemy's Road to Web3 Week 8.

## Development Setup

    yarn

Create a `.env` file at the root of this project and add the following:

    URL=
    MNEMONIC=

The `URL` can be obtained from creating an application on Alchemy.com for Optimism. The `MNEMONIC` comes from your development MetaMask account.

## Running

The application can be deployed and manually invoked using hardhat.

    yarn hardhat run scripts/deploy.js

On Optimism Goerli:

    yarn hardhat run scripts/deploy.js --network optimism-goerli

## Developer Note

I updated the contract to perform and keccak256 as a pure public function, ensuring both internal and external encoded values match.

Implemented FraudDetected and BetRevealed events for better clarity.
