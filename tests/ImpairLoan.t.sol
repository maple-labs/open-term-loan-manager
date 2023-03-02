// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { LoanManagerFactory }     from "../contracts/LoanManagerFactory.sol";
import { LoanManagerInitializer } from "../contracts/LoanManagerInitializer.sol";

import { LoanManagerHarness } from "./utils/Harnesses.sol";
import { console2, TestBase } from "./utils/TestBase.sol";

import {
    MockERC20,
    MockFactory,
    MockGlobals,
    MockLoan,
    MockLoanFactory,
    MockPool,
    MockPoolManager
} from "./utils/Mocks.sol";

contract ImpairLoanBase is TestBase {

    event UnrealizedLossesUpdated(uint256 unrealizedLosses_);

    address governor     = makeAddr("governor");
    address poolDelegate = makeAddr("poolDelegate");

    uint256 start;

    LoanManagerHarness loanManager = new LoanManagerHarness();
    MockERC20          asset       = new MockERC20("A", "A", 18);
    MockFactory        factory     = new MockFactory();
    MockGlobals        globals     = new MockGlobals(governor);
    MockLoan           loan        = new MockLoan();
    MockLoanFactory    loanFactory = new MockLoanFactory();
    MockPoolManager    poolManager = new MockPoolManager();

    function setUp() public virtual {
        start = block.timestamp;

        globals.__setIsBorrower(true);
        globals.__setIsFactory("OT_LOAN", address(loanFactory), true);

        factory.__setGlobals(address(globals));

        loanManager.__setFactory(address(factory));
        loanManager.__setFundsAsset(address(asset));
        loanManager.__setLocked(1);
        loanManager.__setPoolManager(address(poolManager));

        poolManager.__setAsset(address(asset));
        poolManager.__setPoolDelegate(poolDelegate);

        loan.__setFactory(address(loanFactory));

        loanFactory.__setIsLoan(address(loan), true);
    }

}

contract ImpairLoanFailureTests is ImpairLoanBase {

    function test_impairLoan_paused() external {
        globals.__setProtocolPaused(true);

        vm.expectRevert("LM:IL:PAUSED");
        loanManager.impairLoan(address(loan));
    }

    function test_impairLoan_notPoolDelegateOrGovernor() external {
        vm.expectRevert("LM:IL:NO_AUTH");
        loanManager.impairLoan(address(loan));
    }

    function test_impairLoan_alreadyImpaired() external {
        loan.__setDateImpaired();

        vm.prank(poolDelegate);
        vm.expectRevert("LM:IL:IMPAIRED");
        loanManager.impairLoan(address(loan));
    }

    function test_impairLoan_notLoan() external {
        vm.prank(poolDelegate);
        vm.expectRevert("LM:IL:NOT_LOAN");
        loanManager.impairLoan(address(loan));
    }

}

contract ImpairLoanSuccessTests is ImpairLoanBase {

    uint256 constant principal        = 1_000_000e6;
    uint256 constant duration         = 1_000_000 seconds;
    uint256 constant expectedInterest = 1_000e6;

    uint256 constant expectedIssuanceRate = (expectedInterest * 1e30) / duration;

    function setUp() public override {
        super.setUp();

        loan.__setPrincipal(principal);
        loan.__setPaymentDueDate(block.timestamp + duration);
        loan.__setInterest(expectedInterest);

        vm.prank(poolDelegate);
        loanManager.fund(address(loan), principal);

        assertGlobalState({
            loanManager:                address(loanManager),
            paymentCounter:             1,
            paymentWithEarliestDueDate: 1,
            domainStart:                start,
            domainEnd:                  start + duration,
            accountedInterest:          0,
            accruedInterest:            0,
            assetsUnderManagement:      principal,
            principalOut:               principal,
            unrealizedLosses:           0,
            issuanceRate:               expectedIssuanceRate
        });

        assertLoanState({
            loanManager:                 address(loanManager),
            loan:                        address(loan),
            paymentId:                   1,
            previousPaymentId:           0,
            nextPaymentId:               0,
            startDate:                   start,
            paymentInfoPaymentDueDate:   start + duration,
            sortedPaymentPaymentDueDate: start + duration,
            incomingNetInterest:         expectedInterest,
            issuanceRate:                expectedIssuanceRate
        });

        assertLiquidationInfo({
            loanManager:         address(loanManager),
            loan:                address(loan),
            triggeredByGovernor: false,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0
        });
    }

    function test_impairLoan_acl_governor() external {
        vm.prank(governor);
        loanManager.impairLoan(address(loan));
    }

    function test_impairLoan_acl_poolDelegate() external {
        vm.prank(poolDelegate);
        loanManager.impairLoan(address(loan));
    }

    function test_impairLoan_success_earlyLoan() external {
        vm.warp(start + 500_000);  // Halfway through loan payment period

        loan.__expectCall();
        loan.impair();

        vm.prank(poolDelegate);
        vm.expectEmit(false, false, false, true);
        emit UnrealizedLossesUpdated(principal + (expectedInterest / 2));
        loanManager.impairLoan(address(loan));

        assertGlobalState({
            loanManager:                address(loanManager),
            paymentCounter:             1,
            paymentWithEarliestDueDate: 0,
            domainStart:                start + 500_000,
            domainEnd:                  start + 500_000,
            accountedInterest:          (expectedInterest / 2),
            accruedInterest:            0,
            assetsUnderManagement:      principal + (expectedInterest / 2),
            principalOut:               principal,
            unrealizedLosses:           principal + (expectedInterest / 2),  // Half of the interest + principal
            issuanceRate:               0
        });

        assertLoanState({
            loanManager:                 address(loanManager),
            loan:                        address(loan),
            paymentId:                   1,
            previousPaymentId:           0,
            nextPaymentId:               0,
            startDate:                   start,
            paymentInfoPaymentDueDate:   start + duration,
            sortedPaymentPaymentDueDate: 0,  // Payment removed from sorted list
            incomingNetInterest:         expectedInterest,
            issuanceRate:                expectedIssuanceRate
        });

        assertLiquidationInfo({
            loanManager:         address(loanManager),
            loan:                address(loan),
            triggeredByGovernor: false,
            principal:           principal,
            interest:            expectedInterest / 2,  // Half of the interest
            lateInterest:        0,
            platformFees:        0
        });
    }

    function test_impairLoan_success_lateLoan() external {
        vm.warp(start + 1_500_000);  // Loan is late

        uint256 lateInterest = 2_000e6;

        loan.__setLateInterest(lateInterest);  // Set late interest to be returned in paymentBreakdown()

        loan.__expectCall();
        loan.impair();

        vm.prank(poolDelegate);
        vm.expectEmit(false, false, false, true);
        emit UnrealizedLossesUpdated(principal + expectedInterest);
        loanManager.impairLoan(address(loan));

        assertGlobalState({
            loanManager:                address(loanManager),
            paymentCounter:             1,
            paymentWithEarliestDueDate: 0,
            domainStart:                start + 1_500_000,
            domainEnd:                  start + 1_500_000,
            accountedInterest:          expectedInterest,
            accruedInterest:            0,
            assetsUnderManagement:      principal + expectedInterest,
            principalOut:               principal,
            unrealizedLosses:           uint256(principal + expectedInterest),  // Full interest + principal
            issuanceRate:               0
        });

        assertLoanState({
            loanManager:                 address(loanManager),
            loan:                        address(loan),
            paymentId:                   1,
            previousPaymentId:           0,
            nextPaymentId:               0,
            startDate:                   start,
            paymentInfoPaymentDueDate:   start + duration,
            sortedPaymentPaymentDueDate: 0,  // Payment removed from sorted list
            incomingNetInterest:         expectedInterest,
            issuanceRate:                0
        });

        assertLiquidationInfo({
            loanManager:         address(loanManager),
            loan:                address(loan),
            triggeredByGovernor: false,
            principal:           principal,
            interest:            expectedInterest,
            lateInterest:        lateInterest,
            platformFees:        0  // Update when @vbidin merges service fee PR
        });
    }

}

contract ImpairLoanFuzzTests is ImpairLoanBase {

    uint256 principal;
    uint256 duration;
    uint256 expectedInterest;
    uint256 earlyInterval;
    uint256 lateInterval;

    function testFuzz_impairLoan_early(
        uint256 principal_,
        uint256 duration_,
        uint256 expectedInterest_,
        uint256 earlyInterval_
    ) external {
        principal        = bound(principal_,        1e6,    1e30);
        duration         = bound(duration_,         1 days, 365 days);
        expectedInterest = bound(expectedInterest_, 1e6,    1e30);
        earlyInterval    = bound(earlyInterval_,    0,      duration - 1);

        loan.__setPrincipal(principal);
        loan.__setPaymentDueDate(block.timestamp + duration);
        loan.__setInterest(expectedInterest);

        vm.prank(poolDelegate);
        loanManager.fund(address(loan), principal);

        uint256 expectedIssuanceRate = (expectedInterest * 1e30) / duration;

        assertEq(expectedIssuanceRate, loanManager.issuanceRate());

        uint256 expectedIncomingNetInterest = loanManager.issuanceRate() * duration / 1e30;  // To account for rounding errors

        assertApproxEqAbs(expectedInterest, expectedIncomingNetInterest, 1);

        assertGlobalState({
            loanManager:                address(loanManager),
            paymentCounter:             1,
            paymentWithEarliestDueDate: 1,
            domainStart:                start,
            domainEnd:                  start + duration,
            accountedInterest:          0,
            accruedInterest:            0,
            assetsUnderManagement:      principal,
            principalOut:               principal,
            unrealizedLosses:           0,
            issuanceRate:               expectedIssuanceRate
        });

        assertLoanState({
            loanManager:                 address(loanManager),
            loan:                        address(loan),
            paymentId:                   1,
            previousPaymentId:           0,
            nextPaymentId:               0,
            startDate:                   start,
            paymentInfoPaymentDueDate:   start + duration,
            sortedPaymentPaymentDueDate: start + duration,
            incomingNetInterest:         expectedIncomingNetInterest,
            issuanceRate:                expectedIssuanceRate
        });

        assertLiquidationInfo({
            loanManager:         address(loanManager),
            loan:                address(loan),
            triggeredByGovernor: false,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0
        });

        vm.warp(start + duration - earlyInterval);  // Impair before payment due

        loan.__expectCall();
        loan.impair();

        uint256 postImpairIncomingNetInterest = expectedIssuanceRate * (duration - earlyInterval) / 1e30;
        uint256 expectedAum                   = principal + postImpairIncomingNetInterest;

        vm.prank(poolDelegate);
        vm.expectEmit(false, false, false, true);
        emit UnrealizedLossesUpdated(expectedAum);  // Equal to AUM because of single loan
        loanManager.impairLoan(address(loan));

        assertGlobalState({
            loanManager:                address(loanManager),
            paymentCounter:             1,
            paymentWithEarliestDueDate: 0,
            domainStart:                start + duration - earlyInterval,
            domainEnd:                  start + duration - earlyInterval,
            accountedInterest:          postImpairIncomingNetInterest,
            accruedInterest:            0,
            assetsUnderManagement:      expectedAum,
            principalOut:               principal,
            unrealizedLosses:           expectedAum,
            issuanceRate:               0
        });

        assertLoanState({
            loanManager:                 address(loanManager),
            loan:                        address(loan),
            paymentId:                   1,
            previousPaymentId:           0,
            nextPaymentId:               0,
            startDate:                   start,
            paymentInfoPaymentDueDate:   start + duration,
            sortedPaymentPaymentDueDate: 0,  // Payment removed from sorted list
            incomingNetInterest:         expectedIncomingNetInterest,
            issuanceRate:                expectedIssuanceRate
        });

        assertLiquidationInfo({
            loanManager:         address(loanManager),
            loan:                address(loan),
            triggeredByGovernor: false,
            principal:           principal,
            interest:            postImpairIncomingNetInterest,
            lateInterest:        0,
            platformFees:        0
        });
    }

    function testFuzz_impairLoan_late(
        uint256 principal_,
        uint256 duration_,
        uint256 expectedInterest_,
        uint256 lateInterval_
    ) external {
        principal        = bound(principal_,        1e6,    1e30);
        duration         = bound(duration_,         1 days, 365 days);
        expectedInterest = bound(expectedInterest_, 1e6,    1e30);
        lateInterval     = bound(lateInterval_,     1,      duration);

        loan.__setPrincipal(principal);
        loan.__setPaymentDueDate(block.timestamp + duration);
        loan.__setInterest(expectedInterest);

        vm.prank(poolDelegate);
        loanManager.fund(address(loan), principal);

        uint256 expectedIssuanceRate = (expectedInterest * 1e30) / duration;

        assertEq(expectedIssuanceRate, loanManager.issuanceRate());

        uint256 expectedIncomingNetInterest = loanManager.issuanceRate() * duration / 1e30;  // To account for rounding errors

        assertApproxEqAbs(expectedInterest, expectedIncomingNetInterest, 1);

        assertGlobalState({
            loanManager:                address(loanManager),
            paymentCounter:             1,
            paymentWithEarliestDueDate: 1,
            domainStart:                start,
            domainEnd:                  start + duration,
            accountedInterest:          0,
            accruedInterest:            0,
            assetsUnderManagement:      principal,
            principalOut:               principal,
            unrealizedLosses:           0,
            issuanceRate:               expectedIssuanceRate
        });

        assertLoanState({
            loanManager:                 address(loanManager),
            loan:                        address(loan),
            paymentId:                   1,
            previousPaymentId:           0,
            nextPaymentId:               0,
            startDate:                   start,
            paymentInfoPaymentDueDate:   start + duration,
            sortedPaymentPaymentDueDate: start + duration,
            incomingNetInterest:         expectedIncomingNetInterest,
            issuanceRate:                expectedIssuanceRate
        });

        assertLiquidationInfo({
            loanManager:         address(loanManager),
            loan:                address(loan),
            triggeredByGovernor: false,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0
        });

        vm.warp(start + duration + lateInterval);  // Late Payment

        loan.__expectCall();
        loan.impair();

        uint256 expectedAum = principal + expectedIncomingNetInterest;

        vm.prank(poolDelegate);
        vm.expectEmit(false, false, false, true);
        emit UnrealizedLossesUpdated(expectedAum);  // Equal to AUM because of single loan
        loanManager.impairLoan(address(loan));

        assertGlobalState({
            loanManager:                address(loanManager),
            paymentCounter:             1,
            paymentWithEarliestDueDate: 0,
            domainStart:                start + duration + lateInterval,
            domainEnd:                  start + duration + lateInterval,
            accountedInterest:          expectedIncomingNetInterest,
            accruedInterest:            0,
            assetsUnderManagement:      expectedAum,
            principalOut:               principal,
            unrealizedLosses:           expectedAum,
            issuanceRate:               0
        });

        assertLoanState({
            loanManager:                 address(loanManager),
            loan:                        address(loan),
            paymentId:                   1,
            previousPaymentId:           0,
            nextPaymentId:               0,
            startDate:                   start,
            paymentInfoPaymentDueDate:   start + duration,
            sortedPaymentPaymentDueDate: 0,  // Payment removed from sorted list
            incomingNetInterest:         expectedIncomingNetInterest,
            issuanceRate:                0
        });

        assertLiquidationInfo({
            loanManager:         address(loanManager),
            loan:                address(loan),
            triggeredByGovernor: false,
            principal:           principal,
            interest:            expectedIncomingNetInterest,
            lateInterest:        0,
            platformFees:        0
        });
    }

}
