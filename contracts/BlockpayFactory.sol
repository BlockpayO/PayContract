// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./Blockpay.sol";
import "./Payment.sol";

error TransactionNotSent();

contract BlockpayFactory {
    using PriceConverter for uint256;
    // create new Blockpay contracts
    // assign the creator address to each contract
    event CreatedPaymentPlanBpF(
        Blockpay blockPayContract,
        string planName,
        uint256 amount,
        uint256 contractIndex,
        string paymentId
    );
    event ReceivedPaymentBpF(
        address payer,
        string paymentId,
        string firstname,
        string lastname,
        string email,
        uint256 timeStamp
    );
    event WithdrawnBpF(
        address planCreator,
        Blockpay[] indexed blockpayContract,
        uint256 withdrawnAmount
    );
    address public factoryDeployer;

    uint256 count = 0;
    AggregatorV3Interface public priceFeedAddress;

    mapping(address => Blockpay[]) addressToContract;
    mapping(address => mapping(Blockpay => uint256)) creatorToContractAddressToContractIndex;
    mapping(string => Blockpay) paymentIDToBlockpayContract;

    constructor(address _priceFeedAddress) {
        factoryDeployer = msg.sender;
        priceFeedAddress = AggregatorV3Interface(_priceFeedAddress);
    }

    // create a new contract for each payment link
    // map the contract to the creator's address to keep track of
    // all his/her contracts
    function createPaymentBpF(
        string memory _planName,
        uint256 _amountInUSD,
        string memory _paymentId
    ) public {
        Blockpay blockpayContract = new Blockpay(
            priceFeedAddress,
            msg.sender,
            address(this)
        );
        require(
            paymentIDToBlockpayContract[_paymentId] ==
                Blockpay(payable(address(0))),
            "PaymentId already exists"
        );
        blockpayContract.createPaymentPlan(
            _planName,
            _amountInUSD,
            _paymentId,
            block.timestamp,
            msg.sender
        );
        addressToContract[msg.sender].push(blockpayContract);
        creatorToContractAddressToContractIndex[msg.sender][
            blockpayContract
        ] = count;
        paymentIDToBlockpayContract[_paymentId] = blockpayContract;
        emit CreatedPaymentPlanBpF(
            blockpayContract,
            _planName,
            _amountInUSD,
            count,
            _paymentId
        );
        count += 1;
    }

    // receive payment
    function receivePaymentBpF(
        string memory _paymentId,
        string memory _firstName,
        string memory _lastname,
        string memory _email
    ) public payable {
        Blockpay blockpayContract = getContractById(_paymentId);
        uint256 _amountInUSD = getPaymentPlanBpF(_paymentId).amountInUSD;
        require(
            msg.value.getConversionRate(priceFeedAddress) >= _amountInUSD,
            "Insufficient Matic sent"
        );
        (bool sent, ) = address(blockpayContract).call{value: msg.value}("");
        if (sent) {
            blockpayContract.receivePayment(
                _firstName,
                _lastname,
                _email,
                msg.value,
                msg.sender,
                block.timestamp,
                _paymentId
            );
            emit ReceivedPaymentBpF(
                msg.sender,
                _paymentId,
                _firstName,
                _lastname,
                _email,
                block.timestamp
            );
        } else {
            revert TransactionNotSent();
        }
    }

    function getTotalPaymentsBpF(
        address _contractCreator,
        uint256 _contractIndex
    ) public view returns (Payments[] memory) {
        Blockpay blockpayContract = getContract(
            _contractCreator,
            _contractIndex
        );
        return blockpayContract.getPayments();
    }

    function getPaymentsPerAddressBpF(
        string memory _paymentId,
        address _user
    ) public view returns (Payments[] memory) {
        Blockpay blockpayContract = getContractById(_paymentId);
        return blockpayContract.getPaymentsPerAddress(_user);
    }

    function conversionRateBpF(
        uint256 _maticInWEI
    ) public view returns (uint256) {
        return _maticInWEI.getConversionRate(priceFeedAddress);
    }

    function changePriceFeedAddressBpf(address _newPriceFeedAddress) public {
        priceFeedAddress = AggregatorV3Interface(_newPriceFeedAddress);
    }

    function getPaymentPlanBpF(
        string memory _paymentId
    ) public view returns (PaymentPlan memory) {
        Blockpay blockpayContract = getContractById(_paymentId);

        return blockpayContract.getPaymentPlan();
    }

    // get contracts based creator and index
    function getContract(
        address _contractCreator,
        uint256 _contractIndex
    ) public view returns (Blockpay) {
        return addressToContract[_contractCreator][_contractIndex];
    }

    // get contract by paymentId
    function getContractById(
        string memory _paymentId
    ) public view returns (Blockpay) {
        return paymentIDToBlockpayContract[_paymentId];
    }

    // get the index of a blockpay contract
    function getContractIndex(
        address _contractCreator,
        address blockpayAddress
    ) public view returns (uint256) {
        Blockpay blockpayContract = Blockpay(payable(blockpayAddress));
        return
            creatorToContractAddressToContractIndex[_contractCreator][
                blockpayContract
            ];
    }

    function getContractsLength(
        address _contractCreator
    ) public view returns (uint256) {
        return addressToContract[_contractCreator].length;
    }

    function getPaymentplans(
        address _contractCreator
    ) public view returns (PaymentPlan[] memory) {
        PaymentPlan[] memory _paymentPlans = new PaymentPlan[](
            addressToContract[_contractCreator].length
        );
        for (
            uint256 i = 0;
            i < addressToContract[_contractCreator].length;
            i++
        ) {
            _paymentPlans[i] = addressToContract[_contractCreator][i]
                .getPaymentPlan();
        }

        return _paymentPlans;
    }

    function getContractsBalanceBpF(
        address _contractCreator
    ) public view returns (uint256) {
        uint256 totalBalance = 0;
        for (
            uint256 i = 0;
            i < addressToContract[_contractCreator].length;
            i++
        ) {
            Blockpay blockpayContract = getContract(_contractCreator, i);
            uint256 balance = blockpayContract.getContractBalance();
            totalBalance += balance;
        }

        return totalBalance;
    }

    function withdrawBpF() public {
        Blockpay[] memory blockpayContracts = new Blockpay[](
            addressToContract[msg.sender].length
        );
        uint256 totalBalance;
        for (uint256 i = 0; i < addressToContract[msg.sender].length; i++) {
            Blockpay blockpayContract = getContract(msg.sender, i);
            uint256 balance = blockpayContract.getContractBalance();
            blockpayContract.withdraw(msg.sender);
            blockpayContracts[i] = blockpayContract;
            totalBalance += balance;
        }
        emit WithdrawnBpF(msg.sender, blockpayContracts, totalBalance);
    }
}
