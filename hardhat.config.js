require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-chai-matchers");
const dotenv = require("dotenv");
dotenv.config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.18",
  networks: {
    polygonMainnet: {
      url: process.env.POLYGON_MAINNET_URL,
      accounts: [process.env.PRIVATE_KEY],
      chainId: 137,
      blockConfirmations: 6,
    },
    mumbai: {
      url: process.env.MUMBAI_URL,
      accounts: [process.env.PRIVATE_KEY],
      chainID: 80001,
      blockConfirmations: 6,
    },
    localhost: {
      url: "http://127.0.0.1:8545/",
      chainId: 31337,
      blockConfirmations: 6,
    },
  },
  etherscan: {
    apiKey: process.env.POLYGONSCAN_API_KEY,
  },
};
