// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { LoanManagerFactory }     from "../contracts/LoanManagerFactory.sol";
import { LoanManagerInitializer } from "../contracts/LoanManagerInitializer.sol";

import { LoanManagerHarness } from "./utils/Harnesses.sol";
import { TestBase }           from "./utils/TestBase.sol";

import {
    MockFactory,
    MockGlobals,
    MockLoan,
    MockLoanFactory,
    MockPoolManager
} from "./utils/Mocks.sol";

contract ImpairLoanBase is TestBase {

    event AccountingStateUpdated(uint256 issuanceRate_, uint112 accountedInterest_);
    event UnrealizedLossesUpdated(uint128 unrealizedLosses_);

    address governor     = makeAddr("governor");
    address poolDelegate = makeAddr("poolDelegate");

    LoanManagerHarness loanManager = new LoanManagerHarness();
    MockFactory        factory     = new MockFactory();
    MockGlobals        globals     = new MockGlobals();
    MockLoan           loan        = new MockLoan();
    MockLoanFactory    loanFactory = new MockLoanFactory();
    MockPoolManager    poolManager = new MockPoolManager();

    function setUp() public virtual {
        factory.__setGlobals(address(globals));

        globals.__setGovernor(governor);

        loanManager.__setFactory(address(factory));
        loanManager.__setPoolManager(address(poolManager));

        poolManager.__setPoolDelegate(poolDelegate);

        loan.__setFactory(address(loanFactory));

        loanFactory.__setIsLoan(address(loan), true);
    }

}

contract ImpairLoanFailureTests is ImpairLoanBase {

    function test_impairLoan_paused() external {
        globals.__setProtocolPaused(true);

        vm.expectRevert("LM:PAUSED");
        loanManager.impairLoan(address(loan));
    }

    function test_impairLoan_notPoolDelegateOrGovernor() external {
        vm.expectRevert("LM:IL:NO_AUTH");
        loanManager.impairLoan(address(loan));
    }

    function test_impairLoan_notLoan() external {
        vm.expectRevert("LM:AFLI:NOT_LOAN");
        vm.prank(poolDelegate);
        loanManager.impairLoan(address(loan));
    }

}

contract ImpairLoanSuccessTests is ImpairLoanBase {

    uint256 constant principal    = 1_000_000e6;
    uint256 constant duration     = 1_000_000 seconds;
    uint256 constant issuanceRate = (1_000e6 * 1e27) / duration;

    uint256 start = block.timestamp;

    function setUp() public override {
        super.setUp();

        loan.__setDateFunded(start);
        loan.__setPrincipal(principal);
        loan.__setPaymentDueDate(start + duration);

        loanManager.__setPaymentFor({
            loan_:                      address(loan),
            platformManagementFeeRate_: 0,
            delegateManagementFeeRate_: 0,
            startDate_:                 start,
            issuanceRate_:              issuanceRate
        });

        loanManager.__setDomainStart(start);
        loanManager.__setIssuanceRate(issuanceRate);
        loanManager.__setPrincipalOut(principal);

        vm.warp(start + duration / 2);
    }

    function test_impairLoan_acl_governor() external {
        vm.prank(governor);
        loanManager.impairLoan(address(loan));
    }

    function test_impairLoan_acl_poolDelegate() external {
        vm.prank(poolDelegate);
        loanManager.impairLoan(address(loan));
    }

    function test_impairLoan_success() public {
        assertGlobalState({
            loanManager:           address(loanManager),
            domainStart:           start,
            accountedInterest:     0,
            accruedInterest:       (issuanceRate * (duration / 2)) / 1e27,
            assetsUnderManagement: principal + (issuanceRate * (duration / 2)) / 1e27,
            principalOut:          principal,
            unrealizedLosses:      0,
            issuanceRate:          issuanceRate
        });

        assertPaymentState({
            loanManager:  address(loanManager),
            loan:         address(loan),
            startDate:    start,
            issuanceRate: issuanceRate
        });

        assertImpairment({
            loanManager:        address(loanManager),
            loan:               address(loan),
            impairedDate:       0,
            impairedByGovernor: false
        });

        loan.__expectCall();
        loan.impair();

        vm.expectEmit();
        emit AccountingStateUpdated(0, uint112((issuanceRate * (duration / 2)) / 1e27));

        vm.expectEmit();
        emit UnrealizedLossesUpdated(uint112(principal + (issuanceRate * (duration / 2)) / 1e27));

        vm.prank(poolDelegate);
        loanManager.impairLoan(address(loan));

        assertGlobalState({
            loanManager:           address(loanManager),
            domainStart:           start + duration / 2,
            accountedInterest:     (issuanceRate * (duration / 2)) / 1e27,
            accruedInterest:       0,
            assetsUnderManagement: principal + (issuanceRate * (duration / 2)) / 1e27,
            principalOut:          principal,
            unrealizedLosses:      principal + (issuanceRate * (duration / 2)) / 1e27,
            issuanceRate:          0
        });

        assertPaymentState({
            loanManager:  address(loanManager),
            loan:         address(loan),
            startDate:    start,
            issuanceRate: issuanceRate
        });

        assertImpairment({
            loanManager:        address(loanManager),
            loan:               address(loan),
            impairedDate:       start + duration / 2,
            impairedByGovernor: false
        });
    }

    function test_impairLoan_success_alreadyImpaired() public {
        // TODO: This can be done cleaner by setting up harness state, but then it undoes `setUp`.
        test_impairLoan_success();

        vm.warp(start + duration);

        loan.__expectCall();
        loan.impair();

        vm.prank(poolDelegate);
        loanManager.impairLoan(address(loan));

        assertGlobalState({
            loanManager:           address(loanManager),
            domainStart:           start + duration / 2,
            accountedInterest:     (issuanceRate * (duration / 2)) / 1e27,
            accruedInterest:       0,
            assetsUnderManagement: principal + (issuanceRate * (duration / 2)) / 1e27,
            principalOut:          principal,
            unrealizedLosses:      principal + (issuanceRate * (duration / 2)) / 1e27,  // Half of the interest + principal
            issuanceRate:          0
        });

        assertPaymentState({
            loanManager:  address(loanManager),
            loan:         address(loan),
            startDate:    start,
            issuanceRate: issuanceRate
        });

        assertImpairment({
            loanManager:        address(loanManager),
            loan:               address(loan),
            impairedDate:       start + duration / 2,
            impairedByGovernor: false
        });
    }

}
