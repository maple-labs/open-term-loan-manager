// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address, TestUtils } from "../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 }          from "../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { LoanManagerFactory }     from "../contracts/LoanManagerFactory.sol";
import { LoanManagerInitializer } from "../contracts/LoanManagerInitializer.sol";

import { LoanManagerHarness } from "./harnesses/LoanManagerHarness.sol";

import { ILoanManagerStructs } from "./interfaces/ILoanManagerStructs.sol";

import {
    MockGlobals,
    MockLoan,
    MockPool,
    MockPoolManager
} from "./mocks/Mocks.sol";

contract LoanManagerTestBase is TestUtils {

    uint256 constant start = 5_000_000 seconds;

    address governor     = address(new Address());
    address poolDelegate = address(new Address());

    address implementation = address(new LoanManagerHarness());
    address initializer    = address(new LoanManagerInitializer());

    MockERC20       fundsAsset;
    MockGlobals     globals;
    MockLoan        loan;
    MockPool        pool;
    MockPoolManager poolManager;

    LoanManagerHarness loanManager;
    LoanManagerFactory factory;

    function setUp() public virtual {
        fundsAsset  = new MockERC20("FundsAsset", "FA", 18);
        globals     = new MockGlobals(governor);
        loan        = new MockLoan();
        pool        = new MockPool();
        poolManager = new MockPoolManager();

        pool.__setAsset(address(fundsAsset));
        pool.__setManager(address(poolManager));

        poolManager.__setPoolDelegate(poolDelegate);

        vm.startPrank(governor);
        factory = new LoanManagerFactory(address(globals));
        factory.registerImplementation(100, implementation, initializer);
        factory.setDefaultVersion(100);
        vm.stopPrank();

        bytes memory arguments = LoanManagerInitializer(initializer).encodeArguments(address(pool));
        loanManager = LoanManagerHarness(LoanManagerFactory(factory).createInstance(arguments, ""));

        vm.warp(start);
    }

    function assertLoanState(
        address loanAddress,
        uint24 paymentId,
        uint24 previousPaymentId,
        uint24 nextPaymentId,
        uint48 startDate,
        uint48 paymentDueDate,
        uint128 incomingNetInterest,
        uint256 issuanceRate
    ) internal {
        assertEq(loanManager.paymentIdOf(loanAddress), paymentId);

        ILoanManagerStructs.PaymentInfo memory paymentInfo = ILoanManagerStructs(address(loanManager)).payments(paymentId);

        assertEq(paymentInfo.startDate,           startDate);
        assertEq(paymentInfo.paymentDueDate,      paymentDueDate);
        assertEq(paymentInfo.incomingNetInterest, incomingNetInterest);
        assertEq(paymentInfo.issuanceRate,        issuanceRate);

        ILoanManagerStructs.SortedPayment memory sortedPayment = ILoanManagerStructs(address(loanManager)).sortedPayments(paymentId);

        assertEq(sortedPayment.previous,       previousPaymentId);
        assertEq(sortedPayment.next,           nextPaymentId);
        assertEq(sortedPayment.paymentDueDate, paymentDueDate);
    }

    function assertGlobalState(
        uint24 paymentCounter,
        uint24 paymentWithEarliestDueDate,
        uint48 domainStart,
        uint48 domainEnd,
        uint112 accountedInterest,
        uint128 principalOut,
        uint128 unrealizedLosses,
        uint256 issuanceRate
    ) internal {
        assertEq(loanManager.paymentCounter(),             paymentCounter);
        assertEq(loanManager.paymentWithEarliestDueDate(), paymentWithEarliestDueDate);
        assertEq(loanManager.domainStart(),                domainStart);
        assertEq(loanManager.domainEnd(),                  domainEnd);
        assertEq(loanManager.accountedInterest(),          accountedInterest);
        assertEq(loanManager.principalOut(),               principalOut);
        assertEq(loanManager.unrealizedLosses(),           unrealizedLosses);
        assertEq(loanManager.issuanceRate(),               issuanceRate);
    }

}
