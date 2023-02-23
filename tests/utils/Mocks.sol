// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Test } from "../../modules/forge-std/src/Test.sol";

import { MockERC20 } from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { ILoanManager } from "../../contracts/interfaces/ILoanManager.sol";

import { LoanManagerStorage }  from "../../contracts/LoanManagerStorage.sol";

// TODO: Eventually propose this to `forge-std`.
contract Spied is Test {

    bool internal assertCalls;
    bool internal captureCall;

    uint256 callCount;

    bytes[] internal calls;

    modifier spied() {
        if (captureCall) {
            calls.push(msg.data);
            captureCall = false;
        } else {
            if (assertCalls) {
                assertEq(msg.data, calls[callCount++], "Unexpected call spied");
            }

            _;
        }
    }

    function __expectCall() public {
        assertCalls = true;
        captureCall = true;
    }

}

contract MockFactory {

    address public mapleGlobals;

    mapping(address => bool) public isInstance;

    function __setGlobals(address globals_) external {
        mapleGlobals = globals_;
    }

    function __setIsInstance(address instance_, bool isInstance_) external {
        isInstance[instance_] = isInstance_;
    }

}

contract MockGlobals {

    bool internal _isValidScheduledCall;

    address public governor;
    address public mapleTreasury;

    bool public protocolPaused;

    mapping(address => bool) public isPoolDeployer;

    mapping(address => uint256) public getLatestPrice;
    mapping(address => uint256) public platformManagementFeeRate;

    mapping(bytes32 => mapping(address => bool)) public isFactory;

    constructor(address governor_) {
        governor = governor_;
    }

    function isValidScheduledCall(address, address, bytes32, bytes calldata) external view returns (bool isValid_) {
        isValid_ = _isValidScheduledCall;
    }

    function __setIsFactory(bytes32 factoryType_, address factory_, bool isFactory_) external {
        isFactory[factoryType_][factory_] = isFactory_;
    }

    function __setIsValidScheduledCall(bool isValid_) external {
        _isValidScheduledCall = isValid_;
    }

    function setMapleTreasury(address treasury_) external {
        mapleTreasury = treasury_;
    }

    function __setProtocolPaused(bool paused_) external {
        protocolPaused = paused_;
    }

    function setPlatformManagementFeeRate(address poolManager_, uint256 platformManagementFeeRate_) external {
        platformManagementFeeRate[poolManager_] = platformManagementFeeRate_;
    }

    function setValidPoolDeployer(address poolDeployer_, bool isValid_) external {
        isPoolDeployer[poolDeployer_] = isValid_;
    }

    function unscheduleCall(address, bytes32, bytes calldata) external {}

}

contract MockLoan is Spied {

    uint256 public paymentInterval;

    uint40 _paymentDueDate;
    uint40 _dateImpaired;
    uint40 _defaultDate;

    uint256 _principal;
    uint256 _interest;
    uint256 _lateInterest;

    function call(uint256) external spied returns (uint40 paymentDueDate_) {
        paymentDueDate_ = _paymentDueDate;
    }

    function fund() external spied returns (uint256 amount_, uint256 date_) {
        ( amount_, date_ ) = ( _principal, _paymentDueDate );
    }

    function impair() external spied returns (uint40 paymentDueDate_, uint40 defaultDate_) {
        ( paymentDueDate_, defaultDate_ ) = ( _paymentDueDate, _defaultDate );
    }

    function isImpaired() external view returns (bool isImpaired_) {
        isImpaired_ = _dateImpaired != 0;
    }

    function paymentBreakdown() external view returns (uint256 interest_, uint256 lateInterest_) {
        ( interest_, lateInterest_ ) = ( _interest, _lateInterest );
    }

    function paymentDueDate() external view returns (uint40 paymentDueDate_) {
        paymentDueDate_ = _paymentDueDate;
    }

    function principal() external view returns (uint256 principal_) {
        principal_ = _principal;
    }

    function removeCall() external spied returns (uint40 paymentDueDate_) {
        paymentDueDate_ = _paymentDueDate;
    }

    function __setDateImpaired() external {
        _dateImpaired = uint40(block.timestamp);
    }

    function __setDefaultDate() external {
        _defaultDate = uint40(block.timestamp);
    }

    function __setInterest(uint256 interest_) external {
        _interest = interest_;
    }

    function __setLateInterest(uint256 lateInterest_) external {
        _lateInterest = lateInterest_;
    }

    function __setPaymentDueDate(uint256 paymentDueDate_) external {
        _paymentDueDate = uint40(paymentDueDate_);
    }

    function __setPaymentInterval(uint256 paymentInterval_) external {
        paymentInterval = paymentInterval_;
    }

    function __setPrincipal(uint256 principal_) external {
        _principal = principal_;
    }

}

contract MockReenteringLoan {

     function fund() external returns (uint256 amount_, uint256 date_) {
        ILoanManager(msg.sender).fund(address(this));
    }

}

contract MockLoanManagerMigrator is LoanManagerStorage {

    fallback() external {
        fundsAsset = abi.decode(msg.data, (address));
    }

}

contract MockPool {

    address public asset;
    address public manager;

    function __setAsset(address asset_) external {
        asset = asset_;
    }

    function __setManager(address manager_) external {
        manager = manager_;
    }

}

contract MockPoolManager {

    address public poolDelegate;
    address public factory;

    uint256 public delegateManagementFeeRate;

    function hasSufficientCover() external pure returns (bool hasSufficientCover_) {
        hasSufficientCover_ = true;
    }

    function setDelegateManagementFeeRate(uint256 delegateManagementFeeRate_) external {
        delegateManagementFeeRate = delegateManagementFeeRate_;
    }

    function __setFactory(address factory_) external {
        factory = factory_;
    }

    function __setPoolDelegate(address poolDelegate_) external {
        poolDelegate = poolDelegate_;
    }

}

contract MockLiquidator {

    uint256 public collateralRemaining;

    fallback() external {
        // Do nothing.
    }

}

contract MockLiquidatorFactory {

    function createInstance(bytes calldata, bytes32) external returns (address instance_) {
        instance_ = address(new MockLiquidator());
    }

}
