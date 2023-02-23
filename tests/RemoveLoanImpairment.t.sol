// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Test } from "../modules/forge-std/src/Test.sol";

import { LoanManagerHarness } from "./utils/Harnesses.sol";

import { MockGlobals, MockFactory, MockPoolManager } from "./utils/Mocks.sol";

contract RemoveLoanImpairmentFailureTests is Test {

    address governor;
    address loan;
    address poolDelegate;

    LoanManagerHarness loanManager;
    MockGlobals        globals;
    MockFactory        factory;
    MockPoolManager    poolManager;

    function setUp() external {
        governor     = makeAddr("governor");
        loan         = makeAddr("loan");
        poolDelegate = makeAddr("poolDelegate");

        factory     = new MockFactory();
        globals     = new MockGlobals(governor);
        loanManager = new LoanManagerHarness();
        poolManager = new MockPoolManager();

        factory.__setGlobals(address(globals));

        loanManager.__setFactory(address(factory));
        loanManager.__setLocked(1);
        loanManager.__setPoolManager(address(poolManager));

        poolManager.__setPoolDelegate(poolDelegate);
    }

    function test_removeLoanImpairment_paused() external {
        globals.__setProtocolPaused(true);

        vm.expectRevert("LM:RLI:PAUSED");
        loanManager.removeLoanImpairment(address(loan));
    }

    function test_removeLoanImpairment_notGovernor() external {
        loanManager.__setLiquidationInfo(loan, true, 0, 0, 0, 0);

        vm.expectRevert("LM:RLI:NO_AUTH");
        vm.prank(poolDelegate);
        loanManager.removeLoanImpairment(address(loan));
    }

    function test_removeLoanImpairment_notPoolDelegate() external {
        loanManager.__setLiquidationInfo(loan, false, 0, 0, 0, 0);

        vm.expectRevert("LM:RLI:NO_AUTH");
        loanManager.removeLoanImpairment(address(loan));
    }

    // TODO: Add failure test for PAST DATE if we decide to keep that.

}
