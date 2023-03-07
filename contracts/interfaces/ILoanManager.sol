// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IMapleProxied } from "../../modules/maple-proxy-factory/contracts/interfaces/IMapleProxied.sol";

import { ILoanManagerStorage } from "./ILoanManagerStorage.sol";

interface ILoanManager is IMapleProxied, ILoanManagerStorage {

    /**************************************************************************************************************************************/
    /*** Events                                                                                                                         ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Funds have been claimed and distributed into the Pool.
     *  @param loan_        The address of the loan contract.
     *  @param principal_   The amount of principal paid.
     *  @param netInterest_ The amount of net interest paid.
     */
    event FundsDistributed(address indexed loan_, uint256 principal_, uint256 netInterest_);

    /**
     *  @dev   Emitted when the issuance parameters are changed.
     *  @param domainEnd_         The timestamp of the domain end.
     *  @param issuanceRate_      New value for the issuance rate.
     *  @param accountedInterest_ The amount of accounted interest.
     */
    event IssuanceParamsUpdated(uint48 domainEnd_, uint256 issuanceRate_, uint112 accountedInterest_);

    /**
     *  @dev   A fee payment was made.
     *  @param loan_                  The address of the loan contract.
     *  @param delegateManagementFee_ The amount of delegate management fee paid.
     *  @param platformManagementFee_ The amount of platform management fee paid.
    */
    event ManagementFeesPaid(address indexed loan_, uint256 delegateManagementFee_, uint256 platformManagementFee_);

    /**
     *  @dev   Emitted when a payment is removed from the LoanManager payments array.
     *  @param loan_      The address of the loan.
     *  @param paymentId_ The payment ID of the payment that was removed.
     */
    event PaymentAdded(
        address indexed loan_,
        uint256 indexed paymentId_,
        uint256 platformManagementFeeRate_,
        uint256 delegateManagementFeeRate_,
        uint256 startDate_,
        uint256 nextPaymentDueDate_,
        uint256 netRefinanceInterest_,
        uint256 newRate_
    );

    /**
     *  @dev   Emitted when a payment is removed from the LoanManager payments array.
     *  @param loan_      The address of the loan.
     *  @param paymentId_ The payment ID of the payment that was removed.
     */
    event PaymentRemoved(address indexed loan_, uint256 indexed paymentId_);

    /**
     *  @dev   Emitted when principal out is updated
     *  @param principalOut_ The new value for principal out.
     */
    event PrincipalOutUpdated(uint128 principalOut_);

    /**
     *  @dev   Emitted when unrealized losses is updated.
     *  @param unrealizedLosses_ The new value for unrealized losses.
     */
    event UnrealizedLossesUpdated(uint256 unrealizedLosses_);

    /**************************************************************************************************************************************/
    /*** External Functions                                                                                                             ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Called by loans when payments are made, updating the accounting.
     *  @param principal_          The amount of principal paid.
     *  @param interest_           The amount of interest paid.
     *  @param platformServiceFee_ The amount of platform service fee paid.
     *  @param delegateServiceFee_ The amount of delegate service fee paid.
     *  @param paymentDueDate_     The new payment due date.
     */
    function claim(
        uint256 principal_,
        uint256 interest_,
        uint256 delegateServiceFee_,
        uint256 platformServiceFee_,
        uint40  paymentDueDate_
    ) external;

    /**
     *  @dev   Funds a new loan.
     *  @param loan_      Loan to be funded.
     *  @param principal_ Amount of principal to fund the Loan with.
     */
    function fund(address loan_, uint256 principal_) external;

    /**
     *  @dev   Triggers the loan impairment for a loan.
     *  @param loan_ Loan to trigger the loan impairment.
     */
    function impairLoan(address loan_) external;

    /**
     *  @dev   Removes the loan impairment for a loan.
     *  @param loan_ Loan to remove the loan impairment.
     */
    function removeLoanImpairment(address loan_) external;

    /**
     *  @dev    Triggers the default of a loan.
     *  @param  loan_                Loan to trigger the default.
     *  @param  liquidatorFactory_   Address of the liquidator factory (ignored for open-term loans).
     *  @return liquidationComplete_ If the liquidation is complete (always true for open-term loans)
     *  @return remainingLosses_     The amount of remaining losses.
     *  @return platformFees_        The amount of platform fees.
     */
    function triggerDefault(
        address loan_,
        address liquidatorFactory_
    ) external returns (bool liquidationComplete_, uint256 remainingLosses_, uint256 platformFees_);

    /**
     *  @dev Updates the issuance parameters of the LoanManager, callable by the Governor and the PoolDelegate.
     *       Useful to call when `block.timestamp` is greater than `domainEnd` and the LoanManager is not accruing interest.
     */
    function updateAccounting() external;

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Returns the precision used for the contract.
     *  @return precision_ The precision used for the contract.
     */
    function PRECISION() external returns (uint256 precision_);

    /**
     *  @dev    Returns the value considered as the hundred percent.
     *  @return hundredPercent_ The value considered as the hundred percent.
     */
    function HUNDRED_PERCENT() external returns (uint256 hundredPercent_);

    /**
     *  @dev    Gets the amount of assets under the management of the contract.
     *  @return assetsUnderManagement_ The amount of assets under the management of the contract.
     */
    function assetsUnderManagement() external view returns (uint256 assetsUnderManagement_);

    /**
     *  @dev    Gets the amount of accrued interest up until this point in time.
     *  @return accruedInterest_ The amount of accrued interest up until this point in time.
     */
    function getAccruedInterest() external view returns (uint256 accruedInterest_);

    /**
     *  @dev    Gets the address of the Maple globals contract.
     *  @return globals_ The address of the Maple globals contract.
     */
    function globals() external view returns (address globals_);

    /**
     *  @dev    Gets the address of the governor contract.
     *  @return governor_ The address of the governor contract.
     */
    function governor() external view returns (address governor_);

    /**
     *  @dev    Gets the address of the pool delegate.
     *  @return poolDelegate_ The address of the pool delegate.
     */
    function poolDelegate() external view returns (address poolDelegate_);

    /**
     *  @dev    Gets the address of the Maple treasury.
     *  @return treasury_ The address of the Maple treasury.
     */
    function mapleTreasury() external view returns (address treasury_);

}
