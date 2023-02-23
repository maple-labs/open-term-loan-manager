// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { MockERC20 } from "../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { LoanManagerHarness } from "./utils/Harnesses.sol";
import { TestBase }            from "./utils/TestBase.sol";

import { MockGlobals, MockLoan, MockPoolManager, MockFactory } from "./utils/Mocks.sol";

contract DistributeClaimedFundsBase is TestBase {

    uint256 constant platformManagementFeeRate = 0.06e6;
    uint256 constant delegateManagementFeeRate = 0.04e6;

    address treasury = makeAddr("treasury");

    uint256 start;

    LoanManagerHarness loanManager = new LoanManagerHarness();
    MockERC20          asset       = new MockERC20("A", "A", 18);
    MockFactory        factory     = new MockFactory();
    MockGlobals        globals     = new MockGlobals(makeAddr("governor"));
    MockLoan           loan        = new MockLoan();
    MockPoolManager    poolManager = new MockPoolManager();

    function setUp() public virtual {
        poolManager = new MockPoolManager();

        factory.__setGlobals(address(globals));

        globals.setMapleTreasury(treasury);

        loanManager.__setFactory(address(factory));
        loanManager.__setFundsAsset(address(asset));
        loanManager.__setLocked(1);
        loanManager.__setPoolManager(address(poolManager));

        // Set Management Fees
        globals.setPlatformManagementFeeRate(address(poolManager), platformManagementFeeRate);
        poolManager.setDelegateManagementFeeRate(delegateManagementFeeRate);

        start = block.timestamp;
    }

}

contract DistributeClaimedFundsFailureTests is DistributeClaimedFundsBase {

    uint256 constant interest    = 1_000e6;
    uint256 constant platformFee = 200e6;
    uint256 constant delegateFee = 100e6;

    function setUp() public override {
        super.setUp();

        loan.__setPrincipal(1_000_000e6);
        loan.__setPaymentDueDate(start + 1_000_000);
        loan.__setInterest(10_000e6);

        vm.prank(address(poolManager));
        loanManager.fund(address(loan));

    }

    function test_distributeClaimFunds_notLoan() public {
        vm.expectRevert("LM:DCF:NOT_LOAN");
        loanManager.__distributeClaimedFunds(address(1), 0, interest, delegateFee, platformFee);
    }

    function test_distributeClaimFunds_zeroTreasury() public {
        globals.setMapleTreasury(address(0));

        vm.expectRevert("LM:DCF:ZERO_ADDRESS");
        loanManager.__distributeClaimedFunds(address(loan), 0, interest, delegateFee, platformFee);
    }

    function test_distributeClaimFunds_poolTransfer() public {
        vm.expectRevert("LM:DCF:POOL_TRANSFER");
        loanManager.__distributeClaimedFunds(address(loan), 0, interest, delegateFee, platformFee);
    }

    function test_distributeClaimFunds_platformTransfer() public {
        asset.mint(address(loanManager), interest);

        vm.expectRevert("LM:DCF:MT_TRANSFER");
        loanManager.__distributeClaimedFunds(address(loan), 0, interest, delegateFee, platformFee);
    }

    function test_distributeClaimFunds_delegateTransfer() public {
        asset.mint(address(loanManager), interest + platformFee);

        vm.expectRevert("LM:DCF:PD_TRANSFER");
        loanManager.__distributeClaimedFunds(address(loan), 0, interest, delegateFee, platformFee);
    }

}

contract DistributeClaimedFundsTests is DistributeClaimedFundsBase {

    address pool         = makeAddr("pool");
    address poolDelegate = makeAddr("poolDelegate");

    function setUp() public override {
        super.setUp();

        poolManager.__setPoolDelegate(poolDelegate);
        loanManager.__setPool(pool);

        // Just for fund, not used in distributeClaimedFunds.
        loan.__setPrincipal(1_000_000e6);
        loan.__setPaymentDueDate(start + 1_000_000);
        loan.__setInterest(10_000e6);

        vm.prank(address(poolManager));
        loanManager.fund(address(loan));

    }

    function testFuzz_distributeClaimFunds(uint256 principal, uint256 interest, uint256 delegateFee, uint256 platformFee) external {
        principal   = bound(principal,   1_000e6, 1e30);
        interest    = bound(interest,    1000e6,  1e30);
        delegateFee = bound(delegateFee, 10e6,    1e30);
        platformFee = bound(platformFee, 10e6,    1e30);

        asset.mint(address(loanManager), principal + interest + platformFee + delegateFee);

        vm.prank(address(loanManager));
        loanManager.__distributeClaimedFunds(address(loan), principal, interest, delegateFee, platformFee);

        uint256 netInterest           = interest * (1e6 - (platformManagementFeeRate + delegateManagementFeeRate)) / 1e6;
        uint256 platformManagementFee = interest * platformManagementFeeRate / 1e6;
        uint256 delegateManagementFee = interest * delegateManagementFeeRate / 1e6;

        assertTrue(asset.balanceOf(pool) >= principal + netInterest);         // Pool benefits from rounding errors
        assertApproxEqAbs(asset.balanceOf(pool), principal + netInterest, 2); // Pool benefits from rounding errors

        assertEq(asset.balanceOf(poolDelegate),         delegateFee + delegateManagementFee);
        assertEq(asset.balanceOf(treasury),             platformFee + platformManagementFee);
        assertEq(asset.balanceOf(address(loanManager)), 0);
    }

}
