// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { MockERC20 } from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";
import { Test }      from "../../modules/forge-std/src/Test.sol";

import { ILoanManager } from "../../contracts/interfaces/ILoanManager.sol";

import { LoanManagerStorage } from "../../contracts/LoanManagerStorage.sol";

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

    function __setGovernor(address governor_) external {
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

    function unscheduleCall(address, bytes32, bytes calldata) external pure {}

}

contract MockLoan is Spied {

    address public factory;
    address public borrower;

    uint40 public dateImpaired;
    uint40 public datePaid;
    uint40 public dateFunded;
    uint40 public defaultDate;
    uint40 public paymentDueDate;

    uint256 public paymentInterval;
    uint256 public principal;

    uint256 _fundsLent;

    mapping(uint256 => uint256) _interest;
    mapping(uint256 => uint256) _lateInterest;

    function callPrincipal(uint256) external virtual spied returns (uint40 paymentDueDate_, uint40 defaultDate_) {
        ( paymentDueDate_, defaultDate_ ) = ( paymentDueDate, defaultDate );
    }

    function fund() public virtual spied returns (uint256 fundsLent_, uint40 paymentDueDate_, uint40 defaultDate_) {
        ( fundsLent_, paymentDueDate_, defaultDate_ ) = ( _fundsLent, paymentDueDate, defaultDate );
    }

    function impair() external virtual spied returns (uint40 paymentDueDate_, uint40 defaultDate_) {
        ( paymentDueDate_, defaultDate_ ) = ( paymentDueDate, defaultDate );
    }

    function isImpaired() external view returns (bool isImpaired_) {
        isImpaired_ = dateImpaired != 0;
    }

    function paymentBreakdown(uint256 timestamp_)
        external view
        returns (
            uint256 calledPrincipal_,
            uint256 interest_,
            uint256 lateInterest_,
            uint256 delegateServiceFee_,
            uint256 platformServiceFee_
        )
    {
        timestamp_;

        (
            calledPrincipal_,
            interest_,
            lateInterest_,
            delegateServiceFee_,
            platformServiceFee_
        ) = ( 0, _interest[timestamp_], _lateInterest[timestamp_], 0, 0 );
    }

    function proposeNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_)
        external virtual spied returns (bytes32 refinanceCommitment_)
    {
        refinanceCommitment_ =  keccak256(abi.encode(refinancer_, deadline_, calls_));
    }

    function removeCall() external virtual spied returns (uint40 paymentDueDate_, uint40 defaultDate_) {
        ( paymentDueDate_, defaultDate_) = ( paymentDueDate, defaultDate );
    }

    function repossess(address destination_) external virtual spied returns (uint256 fundsRepossessed_) {}

    function removeImpairment() external virtual spied returns (uint40 paymentDueDate_, uint40 defaultDate_) {
        ( paymentDueDate_, defaultDate_ ) = ( paymentDueDate, defaultDate );
    }

    function __setBorrower(address borrower_) external {
        borrower = borrower_;
    }

    function __setDateFunded(uint256 dateFunded_) external {
        dateFunded = uint40(dateFunded_);
    }

    function __setDateImpaired(uint256 dateImpaired_) external {
        dateImpaired = uint40(dateImpaired_);
    }

    function __setDatePaid(uint256 datePaid_) external {
        datePaid = uint40(datePaid_);
    }

    function __setDefaultDate(uint256 defaultDate_) external {
        defaultDate = uint40(defaultDate_);
    }

    function __setFactory(address factory_) external {
        factory = factory_;
    }

    function __setFundsLent(uint256 fundsLent_) external {
        _fundsLent = fundsLent_;
    }

    function __setInterest(uint256 timestamp_, uint256 interest_) external {
        _interest[timestamp_] = interest_;
    }

    function __setLateInterest(uint256 timestamp_, uint256 lateInterest_) external {
        _lateInterest[timestamp_] = lateInterest_;
    }

    function __setPaymentDueDate(uint256 paymentDueDate_) external {
        paymentDueDate = uint40(paymentDueDate_);
    }

    function __setPaymentInterval(uint256 paymentInterval_) external {
        paymentInterval = paymentInterval_;
    }

    function __setPrincipal(uint256 principal_) external {
        principal = principal_;
    }

}

contract MockReenteringLoan is MockLoan {

    function fund() public override returns (uint256 fundsLent_, uint40 paymentDueDate_, uint40 defaultDate_) {
        ILoanManager(msg.sender).fund(address(this));
        ( fundsLent_, paymentDueDate_, defaultDate_ ) = super.fund();
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
    address public factory;
    address public pool;
    address public poolDelegate;

    uint256 public delegateManagementFeeRate;

    function hasSufficientCover() external pure returns (bool hasSufficientCover_) {
        hasSufficientCover_ = true;
    }

    function requestFunds(address destination_, uint256 principal_) external pure {}

    function setDelegateManagementFeeRate(uint256 delegateManagementFeeRate_) external {
        delegateManagementFeeRate = delegateManagementFeeRate_;
    }

    function __setAsset(address asset_) external {
        asset = asset_;
    }

    function __setFactory(address factory_) external {
        factory = factory_;
    }

    function __setPool(address pool_) external {
        pool = pool_;
    }

    function __setPoolDelegate(address poolDelegate_) external {
        poolDelegate = poolDelegate_;
    }

}

contract MockRevertingERC20 {

    function approve(address, uint256) external pure returns (bool success_) {
        success_ = false;
        require(false);
    }

}
