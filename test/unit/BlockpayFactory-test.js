const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  networkConfig,
  developmentChains,
  DECIMALS,
  INITIAL_ANSWER,
} = require("../../helper-hardhat-config");

describe("BlockpayFactory", () => {
  const deployFactoryFixture = async () => {
    const [owner, address1, address2] = await ethers.getSigners();
    if (developmentChains.includes(network.name)) {
      let aggregator = await ethers.getContractFactory("MockV3Aggregator");
      aggregator = await aggregator.deploy(DECIMALS, INITIAL_ANSWER);
      priceFeedAddress = aggregator.target;
    } else {
      priceFeedAddress =
        networkConfig[String(network.config.chainID)].maticUSDPriceFeed;
    }
    let blockpayFactory = await ethers.getContractFactory("BlockpayFactory");
    blockpayFactory = await blockpayFactory.deploy(priceFeedAddress);

    return { blockpayFactory, owner, address1, address2 };
  };

  const createPaymentLinkFixture = async () => {
    const planName = "Lagos Dev Event Ticket";
    const amountInUSD = ethers.parseEther("9800");
    const paymentId = "1020193913e1-19nr1jrif10";
    const { blockpayFactory, owner, address1 } = await loadFixture(
      deployFactoryFixture
    );
    const createPayment = await blockpayFactory
      .connect(address1)
      .createPaymentBpF(planName, amountInUSD, paymentId);
    const getBlockpayContract = await blockpayFactory.getContract(
      address1.address,
      0
    );
    return { paymentId, planName, amountInUSD };
  };

  describe("createPaymentBpF", () => {
    it("Should deploy blockpay contract on createPaymentBpF function call", async () => {
      const { blockpayFactory, owner, address1 } = await loadFixture(
        deployFactoryFixture
      );
      const { paymentId } = await loadFixture(createPaymentLinkFixture);
      const getBlockpayPlanById = await blockpayFactory.getPaymentPlanBpF(
        paymentId
      );
      expect(paymentId).to.equal(getBlockpayPlanById[1]);
    });

    it("Should fail if paymentId already exist on createPaymentBpF function call", async () => {
      const { blockpayFactory, owner, address1, address2 } = await loadFixture(
        deployFactoryFixture
      );
      // first blockpay contract deployment (create payment function creates a new blockpay contract)
      const { paymentId, planName, amountInUSD } = await loadFixture(
        createPaymentLinkFixture
      );
      // deploying blockpay contract again (create payment function creates a new blockpay contract)
      const createPayment = blockpayFactory
        .connect(address2)
        .createPaymentBpF(planName, amountInUSD, paymentId);

      await expect(createPayment).to.revertedWith("PaymentId already exists");
    });
  });

  describe("receivePaymentBpF", () => {
    it("Should make payment if required amount is sent", async () => {
      const firstName = "Knowledge";
      const lastName = "Okhakumhe";
      const email = "megamindtheincredible@gmail.com";
      const { blockpayFactory, owner, address1, address2 } = await loadFixture(
        deployFactoryFixture
      );
      // first blockpay contract deployment (create payment function creates a new blockpay contract)
      const { paymentId, planName, amountInUSD } = await loadFixture(
        createPaymentLinkFixture
      );
      // convert usd to wei for payment
      const conversion = await blockpayFactory.conversionRateBpF(amountInUSD);
      const makePayment = await blockpayFactory
        .connect(address2)
        .receivePaymentBpF(paymentId, firstName, lastName, email, {
          value: conversion,
        });
      const getPaymentByAddress =
        await blockpayFactory.getPaymentsPerAddressBpF(
          paymentId,
          address2.address
        );
      expect(getPaymentByAddress[0][6]).to.equal(address2.address);
      expect(getPaymentByAddress[0][5]).to.equal(paymentId);
      expect(getPaymentByAddress[0][0]).to.equal(conversion);
    });

    it("Should revert if payer doesn't send specified amount", async () => {
      const firstName = "Knowledge";
      const lastName = "Okhakumhe";
      const email = "megamindtheincredible@gmail.com";
      const newAmountInUSD = ethers.parseEther("99");
      const { blockpayFactory, owner, address1, address2 } = await loadFixture(
        deployFactoryFixture
      );
      // first blockpay contract deployment (create payment function creates a new blockpay contract)
      const { paymentId, planName, amountInUSD } = await loadFixture(
        createPaymentLinkFixture
      );
      // convert usd to wei for payment
      const conversion = await blockpayFactory.conversionRateBpF(
        newAmountInUSD
      );
      // send transaction with new amount (specified amount in createPaymentLink fixture)
      const makePayment = blockpayFactory
        .connect(address2)
        .receivePaymentBpF(paymentId, firstName, lastName, email, {
          value: conversion,
        });

      expect(makePayment).to.be.revertedWith("Insufficient Matic sent");
    });
  });

  describe("withdraw", () => {
    it("Should withdraw if caller is the creator of payment Links", async () => {
      const firstName = "Knowledge";
      const lastName = "Okhakumhe";
      const email = "megamindtheincredible@gmail.com";
      const { blockpayFactory, owner, address1, address2 } = await loadFixture(
        deployFactoryFixture
      );
      // first blockpay contract deployment (create payment function creates a new blockpay contract)
      const { paymentId, planName, amountInUSD } = await loadFixture(
        createPaymentLinkFixture
      );
      // convert usd to wei for payment
      const conversion = await blockpayFactory.conversionRateBpF(amountInUSD);
      const makePayment = await blockpayFactory
        .connect(address2)
        .receivePaymentBpF(paymentId, firstName, lastName, email, {
          value: conversion,
        });

      const addressBalanceBeforeWithdrawal = await ethers.provider.getBalance(
        address1.address
      );
      const withdraw = await blockpayFactory.connect(address1).withdrawBpF();
      const addressBalanceAfterWithdrawal = await ethers.provider.getBalance(
        address1.address
      );

      expect(
        Number(addressBalanceBeforeWithdrawal) + Number(conversion)
      ).to.greaterThanOrEqual(Number(addressBalanceAfterWithdrawal));
    });
    it("Should not withdraw if caller is not the creator of payment Links", async () => {
      const firstName = "Knowledge";
      const lastName = "Okhakumhe";
      const email = "megamindtheincredible@gmail.com";
      const { blockpayFactory, owner, address1, address2 } = await loadFixture(
        deployFactoryFixture
      );
      // first blockpay contract deployment (create payment function creates a new blockpay contract)
      const { paymentId, planName, amountInUSD } = await loadFixture(
        createPaymentLinkFixture
      );
      // convert usd to wei for payment
      const conversion = await blockpayFactory.conversionRateBpF(amountInUSD);
      const makePayment = await blockpayFactory
        .connect(address2)
        .receivePaymentBpF(paymentId, firstName, lastName, email, {
          value: conversion,
        });

      const addressBalanceBeforeWithdrawal = await ethers.provider.getBalance(
        address2.address
      );
      const withdraw = await blockpayFactory.connect(address2).withdrawBpF();
      const addressBalanceAfterWithdrawal = await ethers.provider.getBalance(
        address2.address
      );

      expect(Number(addressBalanceBeforeWithdrawal)).to.be.greaterThanOrEqual(
        Number(addressBalanceAfterWithdrawal)
      );
    });
  });
});
