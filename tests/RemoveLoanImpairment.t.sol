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
    MockPool,
    MockPoolManager
} from "./utils/Mocks.sol";

contract RemoveLoanImpairmentBase is TestBase {

    address governor     = makeAddr("governor");
    address poolDelegate = makeAddr("poolDelegate");

    uint256 constant duration             = 1_000_000;
    uint256 constant expectedInterest     = 1_000e6;
    uint256 constant expectedIssuanceRate = (expectedInterest * 1e30) / duration;
    uint256 constant principal            = 1_000_000e6;

    uint256 start;

    LoanManagerHarness loanManager = new LoanManagerHarness();
    MockERC20          asset       = new MockERC20("A", "A", 18);
    MockFactory        factory     = new MockFactory();
    MockGlobals        globals     = new MockGlobals(makeAddr("governor"));
    MockLoan           loan        = new MockLoan();
    MockPoolManager    poolManager = new MockPoolManager();

    function setUp() public virtual {
        start = block.timestamp;

        factory.__setGlobals(address(globals));

        loanManager.__setFactory(address(factory));
        loanManager.__setFundsAsset(address(asset));
        loanManager.__setLocked(1);
        loanManager.__setPoolManager(address(poolManager));

        poolManager.__setAsset(address(asset));
        poolManager.__setPoolDelegate(poolDelegate);

        loan.__setPrincipal(principal);
        loan.__setPaymentDueDate(block.timestamp + duration);
        loan.__setNormalPaymentDueDate(block.timestamp + duration);
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

}

contract RemoveLoanImpairmentFailureTests is RemoveLoanImpairmentBase {

    function test_removeLoanImpairment_paused() external {
        globals.__setProtocolPaused(true);

        vm.expectRevert("LM:RLI:PAUSED");
        loanManager.removeLoanImpairment(address(loan));
    }

    function test_removeLoanImpairment_noAuth() external {
        vm.expectRevert("LM:RLI:NO_AUTH");
        loanManager.removeLoanImpairment(address(loan));
    }

    function test_removeLoanImpairment_pastDate() external {
        vm.warp(start + duration + 1);

        vm.prank(poolDelegate);
        vm.expectRevert("LM:RLI:PAST_DATE");
        loanManager.removeLoanImpairment(address(loan));
    }

    function test_removeLoanImpairment_notLoan() external {
        MockLoan unregisteredLoan = new MockLoan();

        unregisteredLoan.__setNormalPaymentDueDate(block.timestamp + duration);

        vm.prank(poolDelegate);
        vm.expectRevert("LM:RLI:NOT_LOAN");
        loanManager.removeLoanImpairment(address(unregisteredLoan));
    }

    function test_removeLoanImpairment_poolDelegateAfterGovernor() external {
        vm.prank(governor);
        loanManager.impairLoan(address(loan));

        vm.prank(poolDelegate);
        vm.expectRevert("LM:RLI:NO_AUTH");
        loanManager.removeLoanImpairment(address(loan));
    }

}

// TODO: Tests may need updating depending on potential overlap of calls / impairments
contract RemoveLoanImpairmentSuccessTests is RemoveLoanImpairmentBase {

    uint256 impairmentTimestamp;

    function setUp() public override {
        super.setUp();

        impairmentTimestamp = start + 500_000;

        vm.warp(impairmentTimestamp);

        vm.prank(governor);
        loanManager.impairLoan(address(loan));

        assertGlobalState({
            loanManager:                address(loanManager),
            paymentCounter:             1,
            paymentWithEarliestDueDate: 0,
            domainStart:                impairmentTimestamp,
            domainEnd:                  impairmentTimestamp,
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
            triggeredByGovernor: true,
            principal:           principal,
            interest:            expectedInterest / 2,  // Half of the interest
            lateInterest:        0,
            platformFees:        0
        });
    }

    function test_removeLoanImpairment_acl_governor_success() external {
        vm.prank(governor);
        loanManager.removeLoanImpairment(address(loan));
    }

    function test_removeLoanImpairment_success() external {
        loan.__expectCall();
        loan.removeImpairment();

        uint256 removeImpairmentTimestamp = start + 600_000 seconds;

        vm.warp(removeImpairmentTimestamp);

        vm.prank(governor);
        loanManager.removeLoanImpairment(address(loan));

        assertGlobalState({
            loanManager:                address(loanManager),
            paymentCounter:             2,
            paymentWithEarliestDueDate: 2,
            domainStart:                removeImpairmentTimestamp,
            domainEnd:                  start + duration,  // Original paymentDueDate
            accountedInterest:          (expectedInterest * 6 / 10),  // 60% through payment interval
            accruedInterest:            0,
            assetsUnderManagement:      principal + (expectedInterest * 6 / 10),
            principalOut:               principal,
            unrealizedLosses:           0,  // Half of the interest + principal
            issuanceRate:               expectedIssuanceRate
        });

        assertLoanState({
            loanManager:                 address(loanManager),
            loan:                        address(loan),
            paymentId:                   2,
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

}


