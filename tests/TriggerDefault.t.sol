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

contract TriggerDefaultBase is TestBase {

    address governor     = makeAddr("governor");
    address poolDelegate = makeAddr("poolDelegate");

    uint256 constant duration             = 1_000_000 seconds;
    uint256 constant expectedInterest     = 1_000e6;
    uint256 constant expectedIssuanceRate = (expectedInterest * 1e30) / duration;
    uint256 constant principal            = 1_000_000e6;

    uint256 start = block.timestamp;

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
            loanManager:          address(loanManager),
            loan:                 address(loan),
            triggeredByGovernor:  false,
            principal:            0,
            interest:             0,
            lateInterest:         0,
            platformFees:         0
        });
    }

}

contract TriggerDefaultFailureTests is TriggerDefaultBase {

    function test_triggerDefault_notPoolDelegate() external {
        vm.expectRevert("LM:TD:NOT_PM");
        loanManager.triggerDefault(address(loan));
    }

    function test_triggerDefault_notLoan() external {
        MockLoan unregisteredLoan = new MockLoan();

        vm.prank(address(poolManager));
        vm.expectRevert("LM:TD:NOT_LOAN");
        loanManager.triggerDefault(address(unregisteredLoan));
    }

}

contract TriggerDefaultSuccessTests is TriggerDefaultBase {

    function test_triggerDefault_success() external {
        vm.warp(start + duration + 1);

        assertGlobalState({
            loanManager:                address(loanManager),
            paymentCounter:             1,
            paymentWithEarliestDueDate: 1,
            domainStart:                start,
            domainEnd:                  start + duration,
            accountedInterest:          0,
            accruedInterest:            expectedInterest,
            assetsUnderManagement:      principal + expectedInterest,
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

        vm.prank(address(poolManager));
        loanManager.triggerDefault(address(loan));

        assertGlobalState({
            loanManager:                address(loanManager),
            paymentCounter:             1,
            paymentWithEarliestDueDate: 0,
            domainStart:                start + duration + 1,
            domainEnd:                  start + duration + 1,
            accountedInterest:          0,
            accruedInterest:            0,
            assetsUnderManagement:      0,
            principalOut:               0,
            unrealizedLosses:           0,
            issuanceRate:               0
        });

        assertLoanState({
            loanManager:                 address(loanManager),
            loan:                        address(loan),
            paymentId:                   0,
            previousPaymentId:           0,
            nextPaymentId:               0,
            startDate:                   0,
            paymentInfoPaymentDueDate:   0,
            sortedPaymentPaymentDueDate: 0,
            incomingNetInterest:         0,
            issuanceRate:                0
        });
    }

}
