// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

struct Payments {
    uint256 amountInUSD;
    string firstName;
    string lastName;
    string email;
    uint256 timeStamp;
    string paymentId;
    address payer;
}

// store payment plans
struct PaymentPlan {
    string planName;
    string paymentId;
    uint256 amountInUSD;
    uint256 timeCreated;
}
