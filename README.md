# governance
BitDAO Governance contracts framework

## Build

`npm run build`

## Test

### Set environment variables

`export TS_NODE_FILES=true`
`export NODE_API_KEY=http://127.0.0.1:8545`
`export MNEMONIC=186e446fbd41dD51Ea2213dB2d3ae18B05A05ba8`
`export ETHERSCAN_API_KEY=ABC`

### Run Ganache

Do the following in a different terminal window:
`npm install ganache-cli`
`./node_modules/ganache-cli/cli.js`

### Run Tests

`npm run test`