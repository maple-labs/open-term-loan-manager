// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

interface IERC20Like {

    function balanceOf(address account_) external view returns (uint256 balance_);

    function decimals() external view returns (uint8 decimals_);

}

interface ILiquidatorLike {

    function collateralRemaining() external view returns (uint256 collateralRemaining_);

    function pullFunds(address token_, address destination_, uint256 amount_) external;

    function setCollateralRemaining(uint256 collateralAmount_) external;

}


interface ILoanFactoryLike {

    function isLoan(address loan_) external view returns (bool isLoan_);

}

interface IMapleGlobalsLike {

    function getLatestPrice(address asset_) external view returns (uint256 price_);

    function governor() external view returns (address governor_);

    function isBorrower(address borrower_) external view returns (bool isBorrower_);

    function isFactory(bytes32 factoryId_, address factory_) external view returns (bool isValid_);

    function isPoolDeployer(address poolDeployer_) external view returns (bool isPoolDeployer_);

    function isValidScheduledCall(address caller_, address contract_, bytes32 functionId_, bytes calldata callData_)
        external view returns (bool isValid_);

    function platformManagementFeeRate(address poolManager_) external view returns (uint256 platformManagementFeeRate_);

    function mapleTreasury() external view returns (address mapleTreasury_);

    function protocolPaused() external view returns (bool protocolPaused_);

    function unscheduleCall(address caller_, bytes32 functionId_, bytes calldata callData_) external;

}

interface IMapleLoanLike {

    function acceptLender() external;

    function borrower() external view returns (address borrower_);

    function call(uint256 principalToReturn_) external returns (uint40 paymentDueDate_);

    function collateralAsset() external view returns(address asset_);

    function datePaid() external view returns (uint40 datePaid_);

    function defaultDate() external view returns (uint40 paymentDefaultDate_);

    function factory() external view returns (address factory_);

    function fund() external returns (uint256 fundsLent_, uint40 paymentDueDate_, uint40 defaultDate_);

    function isImpaired() external view returns (bool isImpaired_);

    function impair() external returns (uint40 paymentDueDate_);

    function normalPaymentDueDate() external returns (uint40 paymentDueDate_);

    function paymentDueDate() external view returns (uint40 paymentDueDate_);

    function paymentInterval() external view returns (uint32 paymentInterval_);

    function paymentBreakdown(uint256 timestamp_)
        external view returns (
            uint256 principal_,
            uint256 interest_,
            uint256 lateInterest_,
            uint256 delegateServiceFee_,
            uint256 platformServiceFee_
        );

    function principal() external view returns (uint256 principal_);

    function proposeNewTerms(
        address refinancer_, 
        uint256 deadline_, 
        bytes[] calldata calls_) 
        external returns (bytes32 refinanceCommitment_);

    function removeCall() external returns (uint40 paymentDueDate_);

    function removeImpairment() external returns (uint40 paymentDueDate_);

    function repossess(address destination_) external returns (uint256 fundsRepossessed_);

    function setPendingLender(address pendingLender_) external;

}

interface IPoolLike is IERC20Like {

    function asset() external view returns (address asset_);

    function manager() external view returns (address manager_);

}

interface IPoolManagerLike {

    function delegateManagementFeeRate() external view returns (uint256 delegateManagementFeeRate_);

    function factory() external view returns (address factory_);

    function hasSufficientCover() external view returns (bool hasSufficientCover_);

    function poolDelegate() external view returns (address poolDelegate_);

    function requestFunds(address destination_, uint256 principal_) external;

}
