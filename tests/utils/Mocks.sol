// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { MockERC20 } from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";
import { Test }      from "../../modules/forge-std/src/Test.sol";

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

    bool internal _isBorrower;
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

    function isBorrower(address) external view returns (bool isBorrower_) {
        isBorrower_ = _isBorrower;
    }

    function __setIsBorrower(bool isBorrower_) external {
        _isBorrower = isBorrower_;
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

    address public factory;
    address public borrower;

    uint256 public paymentInterval;

    uint40 _dateImpaired;
    uint40 _datePaid;
    uint40 _defaultDate;
    uint40 _normalPaymentDueDate;
    uint40 _paymentDueDate;

    uint256 _principal;
    uint256 _interest;
    uint256 _lateInterest;

    function call(uint256) external spied returns (uint40 paymentDueDate_) {
        paymentDueDate_ = _paymentDueDate;
    }

    function datePaid() external view returns (uint40 datePaid_) {
        datePaid_ = _datePaid;
    }

    function defaultDate() external view returns (uint40 defaultDate_) {
        defaultDate_ = _defaultDate;
    }

    function fund() external spied returns (uint256 amount_, uint40 paymentDueDate_, uint40 defaultDate_) {
        ( amount_, paymentDueDate_, defaultDate_ ) = ( _principal, _paymentDueDate, _defaultDate );
    }

    function impair() external spied returns (uint40 paymentDueDate_, uint40 defaultDate_) {
        ( paymentDueDate_, defaultDate_ ) = ( _paymentDueDate, _defaultDate );
    }

    function isImpaired() external view returns (bool isImpaired_) {
        isImpaired_ = _dateImpaired != 0;
    }

    function normalPaymentDueDate() external view returns (uint40 paymentDueDate_) {
        paymentDueDate_ = _normalPaymentDueDate;
    }

    function paymentBreakdown(uint256 timestamp_) external view returns (uint256 interest_, uint256 lateInterest_) {
        timestamp_;
        ( interest_, lateInterest_ ) = ( _interest, _lateInterest );
    }

    function paymentDueDate() external view returns (uint40 paymentDueDate_) {
        paymentDueDate_ = _paymentDueDate;
    }

    function principal() external view returns (uint256 principal_) {
        principal_ = _principal;
    }

    function proposeNewTerms(
        address refinancer_,
        uint256 deadline_,
        bytes[] calldata calls_) 
        external pure returns (bytes32 refinanceCommitment_) 
    {
        refinanceCommitment_ =  keccak256(abi.encode(refinancer_, deadline_, calls_));
    }

    function removeCall() external spied returns (uint40 paymentDueDate_) {
        paymentDueDate_ = _paymentDueDate;
    }

    function repossess(address destination_) external returns (uint256 fundsRepossessed_) {}

    function removeImpairment() external spied returns (uint40 paymentDueDate_, uint40 defaultDate_) {
        ( paymentDueDate_, defaultDate_ ) = ( _paymentDueDate, _defaultDate );
    }

    function __setDateImpaired() external {
        _dateImpaired = uint40(block.timestamp);
    }

    function __setDatePaid(uint256 datePaid_) external {
        _datePaid = uint40(datePaid_);
    }

    function __setDefaultDate(uint256 defaultDate_) external {
        _defaultDate = uint40(defaultDate_);
    }

    function __setFactory(address factory_) external {
        factory = factory_;
    }

    function __setInterest(uint256 interest_) external {
        _interest = interest_;
    }

    function __setLateInterest(uint256 lateInterest_) external {
        _lateInterest = lateInterest_;
    }

    function __setNormalPaymentDueDate(uint256 normalPaymentDueDate_) external {
        _normalPaymentDueDate = uint40(normalPaymentDueDate_);
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

    address public borrower;
    address public factory;

    uint256 public principal;

     function fund() external returns (uint256 , uint256) {
        ILoanManager(msg.sender).fund(address(this), 0);
    }

    function __setFactory(address factory_) external {
        factory = factory_;
    }

    function __setPrincipal(uint256 principal_) external {
        principal = principal_;
    }

}

contract MockLoanFactory {

    address public mapleGlobals;
    
    mapping(address => bool) public isLoan;

    function __setGlobals(address globals_) external {
        mapleGlobals = globals_;
    }

    function __setIsLoan(address loan_, bool isLoan_) external {
        isLoan[loan_] = isLoan_;
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

contract MockPoolManager is Spied {

    address public asset;
    address public poolDelegate;
    address public factory;

    uint256 public delegateManagementFeeRate;

    function hasSufficientCover() external pure returns (bool hasSufficientCover_) {
        hasSufficientCover_ = true;
    }

    function requestFunds(address destination_, uint256 principal_) external pure { }

    function setDelegateManagementFeeRate(uint256 delegateManagementFeeRate_) external {
        delegateManagementFeeRate = delegateManagementFeeRate_;
    }

    function __setAsset(address asset_) external {
        asset = asset_;
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

contract MockRevertingERC20 {

    function approve(address, uint256) external pure returns (bool) {
        require(false);
    }

}
