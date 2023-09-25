const networkConfig = {
  137: {
    name: "polygon_mainnet",
    maticUSDPriceFeed: "0x327e23A4855b6F663a28c5161541d69Af8973302",
  },
  80001: {
    name: "mumbai",
    maticUSDPriceFeed: "0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada",
  },
};

const developmentChains = ["hardhat", "localhost"];
const DECIMALS = 8;
const INITIAL_ANSWER = 1 * 10 ** DECIMALS;

module.exports = {
  networkConfig,
  developmentChains,
  DECIMALS,
  INITIAL_ANSWER,
};
