// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { LoanManagerFactory }     from "../contracts/LoanManagerFactory.sol";
import { LoanManagerInitializer } from "../contracts/LoanManagerInitializer.sol";

import { LoanManagerHarness } from "./utils/Harnesses.sol";
import { TestBase }           from "./utils/TestBase.sol";

import {
    MockERC20,
    MockFactory,
    MockGlobals,
    MockLoan,
    MockPoolManager
} from "./utils/Mocks.sol";

// TODO: Test ERC20 balances with recovered funds in success tests.

contract TriggerDefaultBase is TestBase {

    address poolDelegate = makeAddr("poolDelegate");

    LoanManagerHarness loanManager = new LoanManagerHarness();
    MockFactory        factory     = new MockFactory();
    MockGlobals        globals     = new MockGlobals();
    MockPoolManager    poolManager = new MockPoolManager();

    function setUp() public virtual {
        factory.__setGlobals(address(globals));

        loanManager.__setFactory(address(factory));
        loanManager.__setPoolManager(address(poolManager));

        poolManager.__setPoolDelegate(poolDelegate);
    }

}

contract TriggerDefaultFailureTests is TriggerDefaultBase {

    function test_triggerDefault_paused() external {
        globals.__setProtocolPaused(true);

        vm.expectRevert("LM:PAUSED");
        loanManager.triggerDefault(address(1));
    }

    function test_triggerDefault_notPoolDelegate() external {
        vm.expectRevert("LM:TD:NOT_PM");
        loanManager.triggerDefault(address(1));
    }

    function test_triggerDefault_notLoan() external {
        vm.expectRevert("LM:AFLI:NOT_LOAN");
        vm.prank(address(poolManager));
        loanManager.triggerDefault(address(1));
    }

}

contract TriggerDefaultSuccessTests is TriggerDefaultBase {

    address borrower = makeAddr("borrower");
    address governor = makeAddr("governor");
    address pool     = makeAddr("pool");
    address treasury = makeAddr("treasury");

    uint256 constant duration     = 1_000_000 seconds;
    uint256 constant interest     = 1_000e6;
    uint256 constant issuanceRate = (interest * 1e27) / duration;
    uint256 constant principal    = 1_000_000e6;

    uint256 constant delegateManagementFeeRate = 0.04e6;
    uint256 constant platformManagementFeeRate = 0.06e6;

    uint256 start       = block.timestamp;
    uint256 defaultDate = start + duration + 1;

    MockLoan  loan  = new MockLoan();
    MockERC20 asset = new MockERC20("A", "A", 18);

    function setUp() public override {
        super.setUp();

        globals.setMapleTreasury(treasury);

        poolManager.__setPool(pool);

        loan.__setBorrower(borrower);
        loan.__setPrincipal(principal);
        loan.__setPaymentDueDate(start + duration);
        loan.__setInterest(start + duration, interest);

        loanManager.__setDomainStart(start);
        loanManager.__setFundsAsset(address(asset));
        loanManager.__setIssuanceRate(issuanceRate);
        loanManager.__setPrincipalOut(principal);

        loanManager.__setPaymentFor({
            loan_:                      address(loan),
            platformManagementFeeRate_: platformManagementFeeRate,
            delegateManagementFeeRate_: delegateManagementFeeRate,
            startDate_:                 start,
            issuanceRate_:              issuanceRate
        });

        vm.warp(defaultDate);
    }

    function test_triggerDefault_success() external {
        assertGlobalState({
            loanManager:           address(loanManager),
            domainStart:           start,
            accountedInterest:     0,
            accruedInterest:       issuanceRate * (duration + 1) / 1e27,
            assetsUnderManagement: principal + issuanceRate * (duration + 1) / 1e27,
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

        // TODO: Test return.
        vm.prank(address(poolManager));
        loanManager.triggerDefault(address(loan));

        assertGlobalState({
            loanManager:           address(loanManager),
            domainStart:           start + duration + 1,
            accountedInterest:     0,
            accruedInterest:       0,
            assetsUnderManagement: 0,
            principalOut:          0,
            unrealizedLosses:      0,
            issuanceRate:          0
        });

        assertPaymentState({
            loanManager:  address(loanManager),
            loan:         address(loan),
            startDate:    0,
            issuanceRate: 0
        });
    }

    function test_triggerDefault_success_impaired() external {
        uint256 impairedDate = start + duration / 2;

        loanManager.__setAccountedInterest(interest / 2);
        loanManager.__setDomainStart(impairedDate);
        loanManager.__setImpairmentFor(address(loan), impairedDate, false);
        loanManager.__setIssuanceRate(0);
        loanManager.__setUnrealizedLosses(principal + interest / 2);

        // TODO: Test return.
        vm.prank(address(poolManager));
        loanManager.triggerDefault(address(loan));

        assertGlobalState({
            loanManager:           address(loanManager),
            domainStart:           start + duration + 1,
            accountedInterest:     0,
            accruedInterest:       0,
            assetsUnderManagement: 0,
            principalOut:          0,
            unrealizedLosses:      0,
            issuanceRate:          0
        });

        assertPaymentState({
            loanManager:  address(loanManager),
            loan:         address(loan),
            startDate:    0,
            issuanceRate: 0
        });

        assertImpairment({
            loanManager:        address(loanManager),
            loan:               address(loan),
            impairedDate:       0,
            impairedByGovernor: false
        });
    }

}
