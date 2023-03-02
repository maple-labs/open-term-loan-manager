// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { MockERC20 } from "../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { ILoanManagerStructs } from "./utils/Interfaces.sol";

import { LoanManagerHarness } from "./utils/Harnesses.sol";

import {
    MockFactory,
    MockGlobals,
    MockLoan,
    MockLoanFactory,
    MockPoolManager,
    MockReenteringLoan,
    MockRevertingERC20
} from "./utils/Mocks.sol";

import { TestBase } from "./utils/TestBase.sol";

contract FundFailureTests is TestBase {

    address poolDelegate = makeAddr("poolDelegate");

    LoanManagerHarness loanManager = new LoanManagerHarness();
    MockERC20          asset       = new MockERC20("Asset", "A", 6);
    MockGlobals        globals     = new MockGlobals(makeAddr("governor"));
    MockFactory        factory     = new MockFactory();
    MockLoan           loan        = new MockLoan();
    MockLoanFactory    loanFactory = new MockLoanFactory();
    MockPoolManager    poolManager = new MockPoolManager();

    function setUp() public virtual {
        poolManager = new MockPoolManager();

        globals.__setIsBorrower(true);
        globals.__setIsFactory("OT_LOAN", address(loanFactory), true);

        factory.__setGlobals(address(globals));

        poolManager.__setAsset(address(asset));
        poolManager.__setPoolDelegate(address(poolDelegate));

        loanManager.__setFactory(address(factory));
        loanManager.__setFundsAsset(address(asset));
        loanManager.__setLocked(1);
        loanManager.__setPoolManager(address(poolManager));

        loan.__setFactory(address(loanFactory));
        loan.__setPrincipal(1);

        loanFactory.__setIsLoan(address(loan), true);
    }

    function test_fund_notPoolDelegate() public {
        vm.expectRevert("LM:F:NOT_PD");
        loanManager.fund(address(loan), 1);
    }

    function test_fund_invalidFactory() public {
        globals.__setIsFactory("OT_LOAN", address(loanFactory), false);

        vm.prank(poolDelegate);
        vm.expectRevert("LM:VL:INVALID_LOAN_FACTORY");
        loanManager.fund(address(loan), 1);
    }

    function test_fund_invalidLoan() public {
        loanFactory.__setIsLoan(address(loan), false);

        vm.prank(poolDelegate);
        vm.expectRevert("LM:VL:INVALID_LOAN_INSTANCE");
        loanManager.fund(address(loan), 1);
    }

    function test_fund_invalidBorrower() public {
        globals.__setIsBorrower(false);

        vm.prank(poolDelegate);
        vm.expectRevert("LM:VL:INVALID_BORROWER");
        loanManager.fund(address(loan), 1);
    }

    function test_fund_inactiveLoan() public {
        loan.__setPrincipal(0);

        vm.prank(poolDelegate);
        vm.expectRevert("LM:VL:LOAN_NOT_ACTIVE");
        loanManager.fund(address(loan), 1);
    }

    function test_fund_failedApproval() public {
        loanManager.__setFundsAsset(address(new MockRevertingERC20()));

        vm.prank(poolDelegate);
        vm.expectRevert("LM:F:APPROVE_FAILED");
        loanManager.fund(address(loan), 1);
    }

    function test_fund_reentrancy() public {
        MockReenteringLoan loan_ = new MockReenteringLoan();
        loan_.__setFactory(address(loanFactory));
        loan_.__setPrincipal(1);

        loanFactory.__setIsLoan(address(loan_), true);

        vm.prank(poolDelegate);
        vm.expectRevert("LM:LOCKED");
        loanManager.fund(address(loan_), 1);
    }

}

contract FundTests is TestBase {

    address poolDelegate = makeAddr("poolDelegate");

    uint256 start;

    // Saving to storage to avoid stack issues
    uint256 currentRate;
    uint256 currentPrincipal;

    LoanManagerHarness loanManager = new LoanManagerHarness();
    MockFactory        factory     = new MockFactory();
    MockGlobals        globals     = new MockGlobals(makeAddr("governor"));
    MockERC20          asset       = new MockERC20("Asset", "A", 6);
    MockLoanFactory    loanFactory = new MockLoanFactory();
    MockPoolManager    poolManager = new MockPoolManager();

    function setUp() public virtual {
        start       = block.timestamp;
        poolManager = new MockPoolManager();

        globals.__setIsBorrower(true);
        globals.__setIsFactory("OT_LOAN", address(loanFactory), true);

        factory.__setGlobals(address(globals));

        poolManager.__setAsset(address(asset));
        poolManager.__setPoolDelegate(poolDelegate);

        loanManager.__setFactory(address(factory));
        loanManager.__setFundsAsset(address(asset));
        loanManager.__setLocked(1);
        loanManager.__setPoolManager(address(poolManager));

        // Set both fees to sum up to 10%
        globals.setPlatformManagementFeeRate(address(poolManager), 0.06e6);
        poolManager.setDelegateManagementFeeRate(0.04e6);

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
    }


    function testFuzz_fund_multipleLoans(uint256 seed) external {
        uint256 lowestInterval      = type(uint256).max;
        uint256 lowestIntervalIndex = 1;

        for (uint256 i = 1; i < seed % 50; i++) {
            // Bound each loan parameter
            uint256 principal_       = bound(randomize(seed, i, "principal"), 1e6,       1e30);
            uint256 grossInterest_   = bound(randomize(seed, i, "interest"),  1e6,       1e30);
            uint256 paymentInterval_ = bound(randomize(seed, i, "interval"),  1_000_000, 365 days);

            // Calculate net interest
            uint256 interest_ = grossInterest_ * 0.9e6 / 1e6;

            currentPrincipal += principal_;
            currentRate      += interest_ * 1e30 / paymentInterval_;

            if (paymentInterval_ < lowestInterval) {
                lowestIntervalIndex = i;
                lowestInterval      = paymentInterval_;
            }

            MockLoan loan_ = new MockLoan();

            loan_.__setFactory(address(loanFactory));
            loan_.__setPrincipal(principal_);
            loan_.__setPaymentDueDate(block.timestamp + paymentInterval_);
            loan_.__setInterest(grossInterest_);

            loanFactory.__setIsLoan(address(loan_), true);

            loan_.__expectCall();
            loan_.fund();

            vm.prank(poolDelegate);
            loanManager.fund(address(loan_), principal_);

            ILoanManagerStructs.SortedPayment memory sortedPayment = ILoanManagerStructs(address(loanManager)).sortedPayments(i);

            assertGlobalState({
                loanManager:                address(loanManager),
                paymentCounter:             uint24(i),
                paymentWithEarliestDueDate: uint24(lowestIntervalIndex),
                domainStart:                uint48(start),
                domainEnd:                  uint48(start + lowestInterval),
                accountedInterest:          0,
                accruedInterest:            0,
                assetsUnderManagement:      uint128(currentPrincipal),
                principalOut:               uint128(currentPrincipal),
                unrealizedLosses:           0,
                issuanceRate:               currentRate
            });

            assertLoanState({
                loanManager:                 address(loanManager),
                loan:                        address(loan_),
                paymentId:                   uint24(i),
                previousPaymentId:           sortedPayment.previous,
                nextPaymentId:               sortedPayment.next,
                startDate:                   uint40(start),
                paymentInfoPaymentDueDate:   uint40(start + paymentInterval_),
                sortedPaymentPaymentDueDate: uint40(start + paymentInterval_),
                incomingNetInterest:         uint128(interest_),
                issuanceRate:                interest_ * 1e30 / paymentInterval_
            });

        }

    }

    function randomize(uint256 seed, uint256 salt1, string memory salt2) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(seed, salt1, salt2)));
    }

}
