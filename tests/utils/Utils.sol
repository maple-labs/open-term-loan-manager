// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;


import { StdAssertions } from "../../modules/forge-std/src/StdAssertions.sol";

import { ILoanManagerStructs } from "../interfaces/ILoanManagerStructs.sol";

import { LoanManagerHarness } from "./Harnesses.sol";

contract Utils is StdAssertions {

    function assertLoanState(
        address loanManager,
        address loan,
        uint24  paymentId,
        uint24  previousPaymentId,
        uint24  nextPaymentId,
        uint48  startDate,
        uint48  paymentDueDate,
        uint128 incomingNetInterest,
        uint256 issuanceRate
    ) internal {
        assertEq(LoanManagerHarness(loanManager).paymentIdOf(loan), paymentId);

        ILoanManagerStructs.PaymentInfo memory paymentInfo = ILoanManagerStructs(loanManager).payments(paymentId);

        assertEq(paymentInfo.startDate,           startDate);
        assertEq(paymentInfo.paymentDueDate,      paymentDueDate);

        assertApproxEqAbs(paymentInfo.incomingNetInterest, incomingNetInterest, 1);  // Can be off by 1 because LM uses issuance rate to calculate net interest.
        assertApproxEqAbs(paymentInfo.issuanceRate,        issuanceRate,        1);

        ILoanManagerStructs.SortedPayment memory sortedPayment = ILoanManagerStructs(loanManager).sortedPayments(paymentId);

        assertEq(sortedPayment.previous,       previousPaymentId);
        assertEq(sortedPayment.next,           nextPaymentId);
        assertEq(sortedPayment.paymentDueDate, paymentDueDate);
    }

    function assertGlobalState(
        address loanManager,
        uint24  paymentCounter,
        uint24  paymentWithEarliestDueDate,
        uint48  domainStart,
        uint48  domainEnd,
        uint112 accountedInterest,
        uint128 principalOut,
        uint128 unrealizedLosses,
        uint256 issuanceRate
    ) internal {
        LoanManagerHarness loanManager_ = LoanManagerHarness(loanManager);

        assertEq(loanManager_.paymentCounter(),             paymentCounter);
        assertEq(loanManager_.paymentWithEarliestDueDate(), paymentWithEarliestDueDate);
        assertEq(loanManager_.domainStart(),                domainStart);
        assertEq(loanManager_.domainEnd(),                  domainEnd);
        assertEq(loanManager_.accountedInterest(),          accountedInterest);
        assertEq(loanManager_.principalOut(),               principalOut);
        assertEq(loanManager_.unrealizedLosses(),           unrealizedLosses);
        assertEq(loanManager_.issuanceRate(),               issuanceRate);
    }

}

