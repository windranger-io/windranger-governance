# governance
BitDAO Governance contracts framework

## Bulding sequence diagrams

`npm install`

`npm run plant`

Images are generated and placed into the `./build` folder. 
Image files are numbered incrementally for each `newpage` in `./docs/flows/flows.puml`.


## Yarn approach

### Set environment variables

`export TS_NODE_FILES=true`

`export NODE_API_KEY=http://127.0.0.1:8545`

`export MNEMONIC=186e446fbd41dD51Ea2213dB2d3ae18B05A05ba8` or other address

`export ETHERSCAN_API_KEY=ABC` (not essential)

### Build

`yarn`

`yarn build`

### Test 


#### Run Ganache

Do the following in a different terminal window:

`yarn add ganache-cli`

`./node_modules/ganache-cli/cli.js`


#### Run Tests

`yarn test`


## NodeJS approach

### Build

`npm install`

`npm run build`

### Test

#### Configure node

`npm config set include=dev`

`npm install`


#### Run Ganache

Do the following in a different terminal window:

`npm install ganache-cli`

`./node_modules/ganache-cli/cli.js`

#### Run Tests

`npm run test`
