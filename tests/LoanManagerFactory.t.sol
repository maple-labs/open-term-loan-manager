// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Test } from "../modules/forge-std/src/Test.sol";

import { LoanManager }            from "../contracts/LoanManager.sol";
import { LoanManagerFactory }     from "../contracts/LoanManagerFactory.sol";
import { LoanManagerInitializer } from "../contracts/LoanManagerInitializer.sol";

import { MockFactory, MockGlobals, MockPool, MockPoolManager } from "./utils/Mocks.sol";

// TODO: This should be a test of just the initializer.

contract LoanManagerFactoryBase is Test {

    address asset;
    address governor;
    address implementation;
    address initializer;
    address treasury;

    MockFactory     poolManagerFactory;
    MockGlobals     globals;
    MockPool        pool;
    MockPoolManager poolManager;

    LoanManagerFactory factory;

    function setUp() public virtual {
        asset          = makeAddr("asset");
        governor       = makeAddr("governor");
        implementation = address(new LoanManager());
        initializer    = address(new LoanManagerInitializer());
        treasury       = makeAddr("treasury");

        globals            = new MockGlobals();
        pool               = new MockPool();
        poolManager        = new MockPoolManager();
        poolManagerFactory = new MockFactory();

        globals.__setGovernor(governor);
        globals.setMapleTreasury(treasury);

        vm.startPrank(governor);
        factory = new LoanManagerFactory(address(globals));
        factory.registerImplementation(1, implementation, initializer);
        factory.setDefaultVersion(1);
        vm.stopPrank();

        globals.setValidPoolDeployer(address(this), true);

        poolManager.__setAsset(address(asset));
        poolManager.__setPool(address(pool));

        pool.__setManager(address(poolManager));
    }

    function test_createInstance_notPoolDeployer() external {
        globals.setValidPoolDeployer(address(this), false);

        vm.expectRevert();
        LoanManager(factory.createInstance(abi.encode(address(pool)), "SALT"));
    }

    function test_createInstance_invalidPoolManagerFactory() external {
        vm.expectRevert("LMF:CI:INVALID_FACTORY");
        vm.prank(address(poolManager));
        LoanManager(factory.createInstance(abi.encode(address(pool)), "SALT"));
    }

    function test_createInstance_notPoolManager() external {
        globals.__setIsFactory("POOL_MANAGER", address(poolManagerFactory), true);
        poolManager.__setFactory(address(poolManagerFactory));

        vm.expectRevert("LMF:CI:NOT_PM");
        vm.prank(address(poolManager));
        LoanManager(factory.createInstance(abi.encode(address(pool)), "SALT"));
    }

    function testFail_createInstance_notPool() external {
        factory.createInstance(abi.encode(address(1)), "SALT");
    }

    function testFail_createInstance_collision() external {
        factory.createInstance(abi.encode(address(pool)), "SALT");
        factory.createInstance(abi.encode(address(pool)), "SALT");
    }

    function test_createInstance_success() external {
        LoanManager loanManager_ = LoanManager(factory.createInstance(abi.encode(address(pool)), "SALT"));

        assertEq(loanManager_.HUNDRED_PERCENT(), 1e6);
        assertEq(loanManager_.PRECISION(),       1e27);
        assertEq(loanManager_.factory(),         address(factory));
        assertEq(loanManager_.fundsAsset(),      address(asset));
        assertEq(loanManager_.globals(),         address(globals));
        assertEq(loanManager_.governor(),        governor);
        assertEq(loanManager_.implementation(),  implementation);
        assertEq(loanManager_.mapleTreasury(),   address(treasury));
        assertEq(loanManager_.pool(),            address(pool));
        assertEq(loanManager_.poolManager(),     address(poolManager));
    }

    function test_createInstance_withPoolManager() external {
        globals.__setIsFactory("POOL_MANAGER", address(poolManagerFactory), true);
        poolManager.__setFactory(address(poolManagerFactory));
        poolManagerFactory.__setIsInstance(address(poolManager), true);

        vm.prank(address(poolManager));

        LoanManager loanManager_ = LoanManager(factory.createInstance(abi.encode(address(pool)), "SALT"));

        assertEq(loanManager_.HUNDRED_PERCENT(), 1e6);
        assertEq(loanManager_.PRECISION(),       1e27);
        assertEq(loanManager_.factory(),         address(factory));
        assertEq(loanManager_.fundsAsset(),      address(asset));
        assertEq(loanManager_.globals(),         address(globals));
        assertEq(loanManager_.governor(),        governor);
        assertEq(loanManager_.implementation(),  implementation);
        assertEq(loanManager_.mapleTreasury(),   address(treasury));
        assertEq(loanManager_.pool(),            address(pool));
        assertEq(loanManager_.poolManager(),     address(poolManager));
    }

}
