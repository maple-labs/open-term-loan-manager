// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { LoanManagerHarness }        from "./utils/Harnesses.sol";
import { TestBase }                  from "./utils/TestBase.sol";
import { MockLoan, MockPoolManager } from "./utils/Mocks.sol";

contract RejectNewTermsTests is TestBase {

    address poolDelegate = makeAddr("poolDelegate");
    address refinancer   = makeAddr("refinancer");

    LoanManagerHarness loanManager = new LoanManagerHarness();
    MockLoan           loan        = new MockLoan();
    MockPoolManager    poolManager = new MockPoolManager();

    function setUp() public {
        poolManager.__setPoolDelegate(poolDelegate);

        loanManager.__setLocked(1);
        loanManager.__setPoolManager(address(poolManager));
    }

    function test_rejectNewTerms_notPoolDelegate() public {
        vm.expectRevert("LM:RNT:NOT_PD");
        loanManager.rejectNewTerms(address(loan), address(0), 0, new bytes[](0));
    }

    function test_rejectNewTerms_success() public {
        loan.__expectCall();
        loan.rejectNewTerms(refinancer, block.timestamp, new bytes[](1));

        vm.prank(poolDelegate);
        loanManager.rejectNewTerms(address(loan), address(refinancer), block.timestamp, new bytes[](1));
    }

}
