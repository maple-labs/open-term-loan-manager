// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Test } from "../modules/forge-std/src/Test.sol";

import { LoanManager }            from "../contracts/LoanManager.sol";
import { LoanManagerFactory }     from "../contracts/LoanManagerFactory.sol";
import { LoanManagerInitializer } from "../contracts/LoanManagerInitializer.sol";

import { MockGlobals, MockPool } from "./utils/Mocks.sol";

contract LoanManagerFactoryBase is Test {

    address governor;
    address implementation;
    address initializer;

    MockGlobals globals;
    MockPool    pool;

    LoanManagerFactory factory;

    function setUp() public virtual {
        governor       = makeAddr("governor");
        implementation = address(new LoanManager());
        initializer    = address(new LoanManagerInitializer());

        globals = new MockGlobals(governor);
        pool    = new MockPool();

        vm.startPrank(governor);
        factory = new LoanManagerFactory(address(globals));
        factory.registerImplementation(1, implementation, initializer);
        factory.setDefaultVersion(1);
        vm.stopPrank();

        globals.setValidPoolDeployer(address(this), true);
    }

    function testFail_createInstance_notPool() external {
        factory.createInstance(abi.encode(address(1)), "SALT");
    }

    function testFail_createInstance_collision() external {
        factory.createInstance(abi.encode(address(pool)), "SALT");
        factory.createInstance(abi.encode(address(pool)), "SALT");
    }

    // TODO: Revisit the need for: `test_createInstance_notPoolDeployer()`

    function test_createInstance_success() external {
        pool.__setAsset(address(1));
        pool.__setManager(address(2));

        LoanManager loanManager_ = LoanManager(factory.createInstance(abi.encode(address(pool)), "SALT"));

        assertEq(loanManager_.pool(),        address(pool));
        assertEq(loanManager_.fundsAsset(),  address(1));
        assertEq(loanManager_.poolManager(), address(2));
    }

}
