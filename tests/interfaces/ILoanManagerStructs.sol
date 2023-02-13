// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { LoanManagerStorage } from "../../contracts/LoanManagerStorage.sol";

// TODO: Make sure to update this to match the latest version of the `LoanManagerStorage`.
interface ILoanManagerStructs {

    struct LiquidationInfo {
        bool    triggeredByGovernor;  // Slot 1: bool    -  1 bytes
        uint128 principal;            //         uint128 - 16 bytes: max = 3.4e38
        uint120 interest;             //         uint120 - 15 bytes: max = 1.7e38
        uint256 lateInterest;         // Slot 2: uint256 - 32 bytes: max = 1.1e77
        uint96  platformFees;         // Slot 2: uint96  - 12 bytes: max = 7.9e28 (>79b units at 1e18)
    }

    struct PaymentInfo {
        uint24  platformManagementFeeRate;  // Slot 1: uint24  -  3 bytes: max = 1.6e7  (1600%)
        uint24  delegateManagementFeeRate;  //         uint24  -  3 bytes: max = 1.6e7  (1600%)
        uint48  startDate;                  //         uint48  -  6 bytes: max = 2.8e14 (>8m years)
        uint48  paymentDueDate;             //         uint48  -  6 bytes: max = 2.8e14 (>8m years)
        uint128 incomingNetInterest;        // Slot 2: uint128 - 16 bytes: max = 3.4e38
        uint128 refinanceInterest;          //         uint128 - 16 bytes: max = 3.4e38
        uint256 issuanceRate;               // Slot 3: uint256 - 32 bytes: max = 1.1e77
    }

    struct SortedPayment {
        uint24 previous;
        uint24 next;
        uint48 paymentDueDate;
    }

    function liquidationInfo(address loan_) external view returns (LiquidationInfo memory liquidationInfo_);

    function payments(uint256 paymentId_) external view returns (PaymentInfo memory paymentInfo_);

    function sortedPayments(uint256 paymentId_) external view returns (SortedPayment memory sortedPayment_);

}
