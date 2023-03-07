// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { LoanManagerHarness }         from "./utils/Harnesses.sol";
import { TestBase }                   from "./utils/TestBase.sol";
import { MockLoan, MockPoolManager }  from "./utils/Mocks.sol";

contract ProposeNewTermsTests is TestBase {

    address poolDelegate = makeAddr("poolDelegate");
    address refinancer   = makeAddr("refinancer");  

    LoanManagerHarness loanManager = new LoanManagerHarness();

    MockLoan        loan        = new MockLoan();
    MockPoolManager poolManager = new MockPoolManager();

    function setUp() public {
        poolManager.__setPoolDelegate(poolDelegate);

        loanManager.__setLocked(1);
        loanManager.__setPoolManager(address(poolManager));
    }

    function test_proposeNewTerms_notPoolDelegate() public {
        vm.expectRevert("LM:PNT:NOT_PD");
        loanManager.proposeNewTerms(address(loan), refinancer, block.timestamp, new bytes[](1));
    }

    function test_proposeNewTerms_success() public {
        loan.__expectCall();
        loan.proposeNewTerms(refinancer, block.timestamp, new bytes[](1));

        vm.prank(poolDelegate);
        loanManager.proposeNewTerms(address(loan), refinancer, block.timestamp, new bytes[](1));
    }

}
