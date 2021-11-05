# windranger-governance

Governance contracts framework developed by Windranger to be proposed to BitDAO.

## Docs

[Architecture](docs/Architecture.md)

[Proposals](docs/Proposals.md)

[Use cases](docs/use_cases.md)

[Flows](docs/flows/flows.puml)

## Sequence diagrams

Build images of the above flow diagrams:

`npm install`

`npm run plant`

Images are generated and placed into the `./build` folder. Image files are numbered incrementally
for each `newpage` in `./docs/flows/flows.puml`.

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

## Sequence Diagram Rendering

To create or update the renders for the Plant UML sequence diagrams

#### Ensure Java is installed

```shell
java -version
```

The output will vary depending on OS, however if it fails claiming Java is not found, then you must install before proceeding.

#### Generate renders for all Plant UML documents under `docs/spec`

```shell
npm run plant
```


## Security

Not yet defined

## License

[Apache 2.0](LICENSE)