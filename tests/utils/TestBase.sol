// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console2, Test } from "../../modules/forge-std/src/Test.sol";

import { ILoanManagerStructs } from "./Interfaces.sol";

import { LoanManagerHarness } from "./Harnesses.sol";

contract TestBase is Test {

    function assertLiquidationInfo(
        address loanManager,
        address loan,
        bool    triggeredByGovernor,
        uint256 principal,
        uint256 interest,
        uint256 lateInterest,
        uint256 platformFees
    ) internal {

        ILoanManagerStructs.LiquidationInfo memory liquidationInfo = ILoanManagerStructs(loanManager).liquidationInfo(loan);

        assertEq(liquidationInfo.triggeredByGovernor, triggeredByGovernor,   "triggeredByGovernor");
        assertEq(liquidationInfo.principal,           _uint128(principal),   "principal");
        assertEq(liquidationInfo.interest,            _uint120(interest),    "interest");
        assertEq(liquidationInfo.lateInterest,        lateInterest,          "lateInterest");
        assertEq(liquidationInfo.platformFees,        _uint96(platformFees), "platformFees");
    }

    function assertLoanState(
        address loanManager,
        address loan,
        uint256 paymentId,
        uint256 previousPaymentId,
        uint256 nextPaymentId,
        uint256 startDate,
        uint256 paymentInfoPaymentDueDate,
        uint256 sortedPaymentPaymentDueDate,
        uint256 incomingNetInterest,
        uint256 issuanceRate
    ) internal {
        LoanManagerHarness loanManager_ = LoanManagerHarness(loanManager);

        assertEq(loanManager_.paymentIdOf(loan), _uint24(paymentId));

        ILoanManagerStructs.PaymentInfo memory paymentInfo = ILoanManagerStructs(address(loanManager)).payments(_uint24(paymentId));

        assertEq(paymentInfo.startDate,      _uint48(startDate),                 "startDate");
        assertEq(paymentInfo.paymentDueDate, _uint48(paymentInfoPaymentDueDate), "paymentDueDate");

        assertApproxEqAbs(paymentInfo.incomingNetInterest, _uint128(incomingNetInterest), 1, "incomingNetInterest");
        assertApproxEqAbs(paymentInfo.issuanceRate,        issuanceRate,                  1, "issuanceRate");

        ILoanManagerStructs.SortedPayment memory sortedPayment =
            ILoanManagerStructs(address(loanManager)).sortedPayments(_uint24(paymentId));

        assertEq(sortedPayment.previous,       _uint24(previousPaymentId),           "previous");
        assertEq(sortedPayment.next,           _uint24(nextPaymentId),               "next");
        assertEq(sortedPayment.paymentDueDate, _uint48(sortedPaymentPaymentDueDate), "sortedPaymentDueDate");
    }

    function assertGlobalState(
        address loanManager,
        uint256 paymentCounter,
        uint256 paymentWithEarliestDueDate,
        uint256 domainStart,
        uint256 domainEnd,
        uint256 accountedInterest,
        uint256 accruedInterest,
        uint256 assetsUnderManagement,
        uint256 principalOut,
        uint256 unrealizedLosses,
        uint256 issuanceRate
    ) internal {
        LoanManagerHarness loanManager_ = LoanManagerHarness(loanManager);

        assertEq(loanManager_.paymentCounter(),             _uint24(paymentCounter),             "paymentCounter");
        assertEq(loanManager_.paymentWithEarliestDueDate(), _uint24(paymentWithEarliestDueDate), "paymentWithEarliestDueDate");
        assertEq(loanManager_.domainStart(),                _uint48(domainStart),                "domainStart");
        assertEq(loanManager_.domainEnd(),                  _uint48(domainEnd),                  "domainEnd");
        assertEq(loanManager_.accountedInterest(),          _uint112(accountedInterest),         "accountedInterest");
        assertEq(loanManager_.getAccruedInterest(),         _uint112(accruedInterest),           "accruedInterest");
        assertEq(loanManager_.assetsUnderManagement(),      assetsUnderManagement,               "assetsUnderManagement");
        assertEq(loanManager_.principalOut(),               _uint128(principalOut),              "principalOut");
        assertEq(loanManager_.unrealizedLosses(),           _uint128(unrealizedLosses),          "unrealizedLosses");
        assertEq(loanManager_.issuanceRate(),               issuanceRate,                        "issuanceRate");
    }

    /**************************************************************************************************************************************/
    /*** Internal Pure Utility Functions                                                                                                ***/
    /**************************************************************************************************************************************/

    function _uint24(uint256 input_) internal pure returns (uint24 output_) {
        require(input_ <= type(uint24).max, "TB:UINT24_CAST");
        output_ = uint24(input_);
    }

    function _uint48(uint256 input_) internal pure returns (uint48 output_) {
        require(input_ <= type(uint48).max, "TB:UINT48_CAST");
        output_ = uint48(input_);
    }

    function _uint96(uint256 input_) internal pure returns (uint96 output_) {
        require(input_ <= type(uint96).max, "TB:UINT96_CAST");
        output_ = uint96(input_);
    }

    function _uint112(uint256 input_) internal pure returns (uint112 output_) {
        require(input_ <= type(uint112).max, "TB:UINT112_CAST");
        output_ = uint112(input_);
    }

    function _uint120(uint256 input_) internal pure returns (uint120 output_) {
        require(input_ <= type(uint120).max, "TB:UINT120_CAST");
        output_ = uint120(input_);
    }

    function _uint128(uint256 input_) internal pure returns (uint128 output_) {
        require(input_ <= type(uint128).max, "TB:UINT128_CAST");
        output_ = uint128(input_);
    }

}
