// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { LoanManager } from "../../contracts/LoanManager.sol";

contract LoanManagerHarness is LoanManager {

    function __setAccountedInterest(uint112 accountedInterest_) external {
        accountedInterest = accountedInterest_;
    }

    function __setDomainEnd(uint48 domainEnd_) external {
        domainEnd = domainEnd_;
    }

    function __setDomainStart(uint48 domainStart_) external {
        domainStart = domainStart_;
    }

    function __setIncomingNetInterest(uint256 paymentId_, uint128 incomingNetInterest_) external {
        payments[paymentId_].incomingNetInterest = incomingNetInterest_;
    }

    function __setIssuanceRate(uint256 issuanceRate_) external {
        issuanceRate = issuanceRate_;
    }

    function __setIssuanceRate(uint256 paymentId_, uint256 issuanceRate_) external {
        payments[paymentId_].issuanceRate = issuanceRate_;
    }

    function __setLocked(uint256 locked_) external {
        _locked = locked_;
    }

    function __setPaymentCounter(uint24 paymentCounter_) external {
        paymentCounter = paymentCounter_;
    }

    function __setPaymentDueDate(uint256 paymentId_, uint48 paymentDueDate_) external {
        payments[paymentId_].paymentDueDate       = paymentDueDate_;
        sortedPayments[paymentId_].paymentDueDate = paymentDueDate_;
    }

    function __setPaymentId(address loan_, uint24 paymentId_) external {
        paymentIdOf[loan_] = paymentId_;
    }

    function __setPaymentWithEarliestDueDate(uint24 paymentId_) external {
        paymentWithEarliestDueDate = paymentId_;
    }

    function __setPoolManager(address poolManager_) external {
        poolManager = poolManager_;
    }

    function __setPrincipalOut(uint128 principalOut_) external {
        principalOut = principalOut_;
    }

    function __setStartDate(uint256 paymentId_, uint48 startDate_) external {
        payments[paymentId_].startDate = startDate_;
    }

    function __setUnrealizedLosses(uint128 unrealizedLosses_) external {
        unrealizedLosses = unrealizedLosses_;
    }

}
