// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { MockERC20 } from "../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { LoanManagerHarness } from "./utils/Harnesses.sol";
import { TestBase }           from "./utils/TestBase.sol";

import { MockGlobals, MockLoan, MockPoolManager, MockFactory } from "./utils/Mocks.sol";

contract ClaimTestBase is TestBase {

    LoanManagerHarness loanManager = new LoanManagerHarness();
    MockERC20          asset       = new MockERC20("A", "A", 18);
    MockFactory        factory     = new MockFactory();
    MockGlobals        globals     = new MockGlobals(makeAddr("governor"));
    MockPoolManager    poolManager = new MockPoolManager();

    function setUp() public virtual {
        poolManager = new MockPoolManager();

        factory.__setGlobals(address(globals));

        globals.setMapleTreasury(makeAddr("treasury"));

        loanManager.__setFactory(address(factory));
        loanManager.__setFundsAsset(address(asset));
        loanManager.__setLocked(1);
        loanManager.__setPoolManager(address(poolManager));
    }

}

contract ClaimFailureTests is ClaimTestBase {

    function test_claim_notLoan() public {
        vm.expectRevert("LM:C:NOT_LOAN");
        loanManager.claim(0, 100_000e6, uint40(block.timestamp + 60 days));
    }

}

contract ClaimTests is ClaimTestBase {

    uint256 constant interest1       = 100e6;
    uint256 constant interest2       = 200e6;
    uint256 constant paymentInterval = 1_000_000;
    uint256 constant principal       = 2_000_000e6;

    uint256 start;

    function setUp() public override {
        super.setUp();

        // Assert pre-state
        assertGlobalState({
            loanManager:                address(loanManager),
            paymentCounter:             0,
            paymentWithEarliestDueDate: 0,
            domainStart:                0,
            domainEnd:                  0,
            accountedInterest:          0,
            accruedInterest:            0,
            assetsUnderManagement:      0,
            principalOut:               0,
            unrealizedLosses:           0,
            issuanceRate:               0
        });

        start = block.timestamp;
    }

    function test_claim_singleLoan_earlyPayment() external {
        // First, create the loan that will be claimed and set the needed variables.
        MockLoan loan = new MockLoan();

        loan.__setPrincipal(principal);
        loan.__setPaymentDueDate(start + paymentInterval);
        loan.__setInterest(interest1);

        vm.prank(address(poolManager));
        loanManager.fund(address(loan));

        // The new payment should been added
        assertGlobalState({
            loanManager:                address(loanManager),
            paymentCounter:             1,
            paymentWithEarliestDueDate: 1,
            domainStart:                uint40(start),
            domainEnd:                  uint40(start + paymentInterval),
            accountedInterest:          0,
            accruedInterest:            0,
            assetsUnderManagement:      uint128(principal),
            principalOut:               uint128(principal),
            unrealizedLosses:           0,
            issuanceRate:               interest1 * 1e30 / paymentInterval
        });

        assertLoanState({
            loanManager:                 address(loanManager),
            loan:                        address(loan),
            paymentId:                   1,
            previousPaymentId:           0,
            nextPaymentId:               0,
            startDate:                   uint40(start),
            paymentInfoPaymentDueDate:   uint40(start + paymentInterval),
            sortedPaymentPaymentDueDate: uint40(start + paymentInterval),
            incomingNetInterest:         uint128(interest1),
            issuanceRate:                interest1 * 1e30 / paymentInterval
        });

        // Simulate a payment in the loan
        vm.warp(start + paymentInterval);
        asset.mint(address(loanManager), interest1);

        loan.__setPaymentDueDate(start + 2 * paymentInterval);
        loan.__setInterest(interest2);

        vm.prank(address(loan));
        loanManager.claim(0, interest1, uint40(start + 2 * paymentInterval));

        assertGlobalState({
            loanManager:                address(loanManager),
            paymentCounter:             2,
            paymentWithEarliestDueDate: 2,
            domainStart:                uint40(start + paymentInterval),
            domainEnd:                  uint40(start + 2 * paymentInterval),
            accountedInterest:          0,
            accruedInterest:            0,
            assetsUnderManagement:      uint128(principal),
            principalOut:               uint128(principal),
            unrealizedLosses:           0,
            issuanceRate:               interest2 * 1e30 / paymentInterval
        });

        assertLoanState({
            loanManager:                 address(loanManager),
            loan:                        address(loan),
            paymentId:                   2,
            previousPaymentId:           0,
            nextPaymentId:               0,
            startDate:                   uint40(start + paymentInterval),
            paymentInfoPaymentDueDate:   uint40(start + (paymentInterval * 2)),
            sortedPaymentPaymentDueDate: uint40(start + (paymentInterval * 2)),
            incomingNetInterest:         uint128(interest2),
            issuanceRate:                interest2 * 1e30 / paymentInterval
        });
    }

}
