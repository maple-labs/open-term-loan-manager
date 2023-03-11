// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IMapleProxied } from "../../modules/maple-proxy-factory/contracts/interfaces/IMapleProxied.sol";

import { ILoanManagerStorage } from "./ILoanManagerStorage.sol";

interface ILoanManager is IMapleProxied, ILoanManagerStorage {

    /**************************************************************************************************************************************/
    /*** Events                                                                                                                         ***/
    /**************************************************************************************************************************************/

    // TODO: Make one FundsDistributed event with all fees and principal and interest.

    /**
     *  @dev   Emitted when the accounting state of the loan manager is updated.
     *  @param issuanceRate_      New value for the issuance rate.
     *  @param accountedInterest_ The amount of accounted interest.
     */
    event AccountingStateUpdated(uint256 issuanceRate_, uint112 accountedInterest_);

    /**
     *  @dev   Funds have been claimed and distributed into the Pool.
     *  @param loan_        The address of the loan contract.
     *  @param principal_   The amount of principal paid.
     *  @param netInterest_ The amount of net interest paid.
     */
    event FundsDistributed(address indexed loan_, uint256 principal_, uint256 netInterest_);

    /**
     *  @dev   A fee payment was made.
     *  @param loan_                  The address of the loan contract.
     *  @param delegateManagementFee_ The amount of delegate management fee paid.
     *  @param platformManagementFee_ The amount of platform management fee paid.
    */
    event ManagementFeesPaid(address indexed loan_, uint256 delegateManagementFee_, uint256 platformManagementFee_);

    /**
     *  @dev   Emitted when a payment is removed from the LoanManager payments array.
     *  @param loan_ The address of the loan.
     */
    event PaymentAdded(
        address indexed loan_,
        uint256 platformManagementFeeRate_,
        uint256 delegateManagementFeeRate_,
        uint256 paymentDueDate_,
        uint256 issuanceRate_
    );

    /**
     *  @dev   Emitted when a payment is removed from the LoanManager payments array.
     *  @param loan_ The address of the loan.
     */
    event PaymentRemoved(address indexed loan_);

    /**
     *  @dev   Emitted when principal out is updated
     *  @param principalOut_ The new value for principal out.
     */
    event PrincipalOutUpdated(uint128 principalOut_);

    /**
     *  @dev   Emitted when unrealized losses is updated.
     *  @param unrealizedLosses_ The new value for unrealized losses.
     */
    event UnrealizedLossesUpdated(uint128 unrealizedLosses_);

    /**************************************************************************************************************************************/
    /*** External Functions                                                                                                             ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Calls a loan.
     *  @param loan_      Loan to be called.
     *  @param principal_ Amount of principal to call the Loan with.
     */
    function callPrincipal(address loan_, uint256 principal_) external;

    /**
     *  @dev   Called by loans when payments are made, updating the accounting.
     *  @param principal_          The difference in principal. Positive if net principal change moves funds into pool, negative if it moves
     *                             funds out of pool.
     *  @param interest_           The amount of interest paid.
     *  @param platformServiceFee_ The amount of platform service fee paid.
     *  @param delegateServiceFee_ The amount of delegate service fee paid.
     *  @param paymentDueDate_     The new payment due date.
     */
    function claim(
        int256  principal_,
        uint256 interest_,
        uint256 delegateServiceFee_,
        uint256 platformServiceFee_,
        uint40  paymentDueDate_
    ) external;

    /**
     *  @dev   Funds a new loan.
     *  @param loan_ Loan to be funded.
     */
    function fund(address loan_) external;

    /**
     *  @dev   Triggers the loan impairment for a loan.
     *  @param loan_ Loan to trigger the loan impairment.
     */
    function impairLoan(address loan_) external;

    /**
     *  @dev   Triggers the loan impairment for a loan.
     *  @param loan_       The loan to propose new changes to.
     *  @param refinancer_ The refinancer to use in the refinance.
     *  @param deadline_   The deadline by which the borrower must accept the new terms.
     *  @param calls_      The array of calls to be made to the refinancer.
     */
    function proposeNewTerms(address loan_, address refinancer_, uint256 deadline_, bytes[] calldata calls_) external;

    /**
     *  @dev   Removes a loan call.
     *  @param loan_ Loan to remove call for.
     */
    function removeCall(address loan_) external;

    /**
     *  @dev   Removes the loan impairment for a loan.
     *  @param loan_ Loan to remove the loan impairment.
     */
    function removeLoanImpairment(address loan_) external;

    /**
     *  @dev    Triggers the default of a loan. Different interface for PM to accommodate vs FT-LM.
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
     *  @dev    Triggers the default of a loan.
     *  @param  loan_            Loan to trigger the default.
     *  @return remainingLosses_ The amount of remaining losses.
     *  @return platformFees_    The amount of platform fees.
     */
    function triggerDefault(address loan_) external returns (uint256 remainingLosses_, uint256 platformFees_);

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
     *  @dev    Gets the amount of accrued interest up until this point in time.
     *  @return accruedInterest_ The amount of accrued interest up until this point in time.
     */
    function accruedInterest() external view returns (uint256 accruedInterest_);

    /**
     *  @dev    Gets the amount of assets under the management of the contract.
     *  @return assetsUnderManagement_ The amount of assets under the management of the contract.
     */
    function assetsUnderManagement() external view returns (uint256 assetsUnderManagement_);

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
     *  @dev    Gets the address of the pool.
     *  @return pool_ The address of the pool.
     */
    function pool() external view returns (address pool_);

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
