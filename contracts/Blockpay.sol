// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./PriceConverter.sol";
import "./Payment.sol";

error CallFromFactory();

contract Blockpay {
    using PriceConverter for uint256;

    // create Payment plans (subscription)
    // struct for paid users
    // struct for payment plans
    // receive > emit event
    // constructor function - admin
    // initialize

    receive() external payable {}

    fallback() external payable {}

    event Created(string planName, uint256 amountInUSD);

    event ReceivedPayment(
        uint256 amountInUSD,
        string firstName,
        string lastname,
        string email
    );

    mapping(address => Payments[]) public addressToPayments;

    address public immutable i_deployer;
    address public immutable i_factoryContractAddress;
    AggregatorV3Interface public priceFeedAddress;

    constructor(
        AggregatorV3Interface _priceFeedAddress,
        address _deployer,
        address _factoryContractAddress
    ) {
        i_deployer = _deployer;
        priceFeedAddress = _priceFeedAddress;
        i_factoryContractAddress = _factoryContractAddress;
    }

    modifier onlyDeployer(address _deployer) {
        require(_deployer == i_deployer, "You are not the deployer");
        _;
    }
    // struct Payments {
    //     uint256 amountInUSD;
    //     string firstName;
    //     string lastName;
    //     string email;
    // }

    PaymentPlan private paymentPlan;
    Payments[] private payments;

    // create payment plan
    function createPaymentPlan(
        string memory _planName,
        uint256 _amountInUSD,
        string memory _paymentId,
        uint256 _timeCreated,
        address _caller
    ) public onlyDeployer(_caller) {
        paymentPlan.amountInUSD = _amountInUSD;
        paymentPlan.planName = _planName;
        paymentPlan.paymentId = _paymentId;
        paymentPlan.timeCreated = _timeCreated;
        emit Created(_planName, _amountInUSD);
    }

    // receive payment for certain payment plan
    function receivePayment(
        string memory _firstName,
        string memory _lastname,
        string memory _email,
        uint256 _value,
        address _caller,
        uint256 _timeStamp,
        string memory _paymentId
    ) public payable {
        // get plan amount
        uint256 planAmount = paymentPlan.amountInUSD;
        uint256 usdvalue = _value.getConversionRate(priceFeedAddress);
        // require the amount of matic sent in USD
        require(
            msg.sender == i_factoryContractAddress,
            "Call from factory contract"
        );
        require(usdvalue >= planAmount, "Insufficient matic");
        payments.push(
            Payments(
                usdvalue,
                _firstName,
                _lastname,
                _email,
                _timeStamp,
                _paymentId,
                _caller
            )
        );

        mapPaymentsToAddress(
            Payments(
                usdvalue,
                _firstName,
                _lastname,
                _email,
                _timeStamp,
                _paymentId,
                _caller
            ),
            _caller
        );

        emit ReceivedPayment(usdvalue, _firstName, _lastname, _email);
    }

    function mapPaymentsToAddress(
        Payments memory _payment,
        address _caller
    ) public {
        addressToPayments[_caller].push(_payment);
    }

    function getPayments() public view returns (Payments[] memory) {
        return payments;
    }

    function getPaymentPlan() public view returns (PaymentPlan memory) {
        return paymentPlan;
    }

    function getPaymentsPerAddress(
        address _user
    ) public view returns (Payments[] memory) {
        return addressToPayments[_user];
    }

    function conversionRate(uint256 _maticInWEI) public view returns (uint256) {
        return _maticInWEI.getConversionRate(priceFeedAddress);
    }

    function changePriceFeedAddress(address _newPriceFeedAddress) public {
        priceFeedAddress = AggregatorV3Interface(_newPriceFeedAddress);
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // withdraw
    function withdraw(address _caller) public onlyDeployer(_caller) {
        (bool sent, ) = _caller.call{value: address(this).balance}("");
        require(sent, "Withdrawal failed");
    }
}
