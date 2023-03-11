// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { ERC20Helper }           from "../modules/erc20-helper/src/ERC20Helper.sol";
import { IMapleProxyFactory }    from "../modules/maple-proxy-factory/contracts/interfaces/IMapleProxyFactory.sol";
import { MapleProxiedInternals } from "../modules/maple-proxy-factory/contracts/MapleProxiedInternals.sol";

import { ILoanManager }                                                          from "./interfaces/ILoanManager.sol";
import { ILoanFactoryLike, IMapleGlobalsLike, IMapleLoanLike, IPoolManagerLike } from "./interfaces/Interfaces.sol";

import { LoanManagerStorage } from "./LoanManagerStorage.sol";

/*

    ██╗      ██████╗  █████╗ ███╗   ██╗    ███╗   ███╗ █████╗ ███╗   ██╗ █████╗  ██████╗ ███████╗██████╗
    ██║     ██╔═══██╗██╔══██╗████╗  ██║    ████╗ ████║██╔══██╗████╗  ██║██╔══██╗██╔════╝ ██╔════╝██╔══██╗
    ██║     ██║   ██║███████║██╔██╗ ██║    ██╔████╔██║███████║██╔██╗ ██║███████║██║  ███╗█████╗  ██████╔╝
    ██║     ██║   ██║██╔══██║██║╚██╗██║    ██║╚██╔╝██║██╔══██║██║╚██╗██║██╔══██║██║   ██║██╔══╝  ██╔══██╗
    ███████╗╚██████╔╝██║  ██║██║ ╚████║    ██║ ╚═╝ ██║██║  ██║██║ ╚████║██║  ██║╚██████╔╝███████╗██║  ██║
    ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝    ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝

*/

contract LoanManager is ILoanManager, MapleProxiedInternals, LoanManagerStorage {

    uint256 public override constant HUNDRED_PERCENT = 1e6;   // 100.0000%
    uint256 public override constant PRECISION       = 1e27;

    /**************************************************************************************************************************************/
    /*** Modifiers                                                                                                                      ***/
    /**************************************************************************************************************************************/

    modifier notPaused() {
        require(!IMapleGlobalsLike(globals()).protocolPaused(), "LM:PAUSED");

        _;
    }

    modifier nonReentrant() {
        require(_locked == 1, "LM:LOCKED");

        _locked = 2;

        _;

        _locked = 1;
    }

    /**************************************************************************************************************************************/
    /*** Upgradeability Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    function migrate(address migrator_, bytes calldata arguments_) external override {
        require(msg.sender == _factory(),        "LM:M:NOT_FACTORY");
        require(_migrate(migrator_, arguments_), "LM:M:FAILED");
    }

    function setImplementation(address implementation_) external override {
        require(msg.sender == _factory(), "LM:SI:NOT_FACTORY");
        _setImplementation(implementation_);
    }

    function upgrade(uint256 version_, bytes calldata arguments_) external override {
        address poolDelegate_ = IPoolManagerLike(poolManager).poolDelegate();

        require(msg.sender == poolDelegate_ || msg.sender == governor(), "LM:U:NO_AUTH");

        IMapleGlobalsLike mapleGlobals = IMapleGlobalsLike(globals());

        if (msg.sender == poolDelegate_) {
            require(mapleGlobals.isValidScheduledCall(msg.sender, address(this), "LM:UPGRADE", msg.data), "LM:U:INVALID_SCHED_CALL");

            mapleGlobals.unscheduleCall(msg.sender, "LM:UPGRADE", msg.data);
        }

        IMapleProxyFactory(_factory()).upgradeInstance(version_, arguments_);
    }

    /**************************************************************************************************************************************/
    /*** Loan Funding and Refinancing Functions                                                                                         ***/
    /**************************************************************************************************************************************/

    function fund(address loan_) external override notPaused nonReentrant {
        require(msg.sender == poolDelegate(), "LM:F:NOT_PD");

        address           factory_ = IMapleLoanLike(loan_).factory();
        IMapleGlobalsLike globals_ = IMapleGlobalsLike(globals());

        require(globals_.isFactory("OT_LOAN", factory_),               "LM:F:INVALID_LOAN_FACTORY");
        require(ILoanFactoryLike(factory_).isLoan(loan_),              "LM:F:INVALID_LOAN_INSTANCE");
        require(globals_.isBorrower(IMapleLoanLike(loan_).borrower()), "LM:F:INVALID_BORROWER");

        uint256 principal_ = IMapleLoanLike(loan_).principal();

        require(principal_ != 0, "LM:F:LOAN_NOT_ACTIVE");

        _prepareFundsForLoan(loan_, principal_);

        ( uint256 fundsLent_, , ) = IMapleLoanLike(loan_).fund();

        require(fundsLent_ == principal_, "LM:F:FUNDING_MISMATCH");

        _updatePrincipalOut(_int256(fundsLent_));

        Payment memory payment_ = _addPayment(loan_);

        _updateAccountingState(0, _int256(payment_.issuanceRate));
    }

    function proposeNewTerms(address loan_, address refinancer_, uint256 deadline_, bytes[] calldata calls_) external override {
        require(msg.sender == poolDelegate(), "LM:PNT:NOT_PD");

        IMapleLoanLike(loan_).proposeNewTerms(refinancer_, deadline_, calls_);
    }

    /**************************************************************************************************************************************/
    /*** Loan Payment Claim Function                                                                                                    ***/
    /**************************************************************************************************************************************/

    // TODO: Consider renaming to something else.
    function claim(
        int256  principal_,
        uint256 interest_,
        uint256 delegateServiceFee_,
        uint256 platformServiceFee_,
        uint40  nextPaymentDueDate_
    )
        external override nonReentrant
    {
        uint256 principalRemaining_ = IMapleLoanLike(msg.sender).principal();

        // Either a next payment and remaining principal exists, or neither exist and principal is returned.
        require(
            (nextPaymentDueDate_ > 0 && principalRemaining_ > 0) ||                          // First given it's most likely.
            ((nextPaymentDueDate_ == 0) && (principalRemaining_ == 0) && (principal_ > 0)),
            "LM:C:INVALID"
        );

        _accountForLoanImpairmentRemoval(msg.sender);

        // Transfer the funds from the loan to the `pool`, `poolDelegate`, and `mapleTreasury`.
        _distributeClaimedFunds(msg.sender, principal_, interest_, delegateServiceFee_, platformServiceFee_);

        // If principal is changing, update `principalOut`.
        // If principal is positive, it is being repaid, so `principalOut` is decremented.
        // If principal is negative, it is being taken from the Pool, so `principalOut` is incremented.
        if (principal_ != 0) {
            _updatePrincipalOut(-principal_);
        }

        // Remove the payment and cache the struct.
        Payment memory claimedPayment_ = _removePayment(msg.sender);

        int256 interestAdjustment_ = -_int256(_getIssuance(claimedPayment_.issuanceRate, block.timestamp - claimedPayment_.startDate));

        // If no new payment to track, update accounting and account for discrepancies in paid interest vs accrued interest since the
        // payment's start date, and exit.
        if (nextPaymentDueDate_ == 0) return _updateAccountingState(interestAdjustment_, -_int256(claimedPayment_.issuanceRate));

        if (principal_ < 0) {
            // TODO: Need to check borrower is still whitelisted?
            // TODO: Issue exists where the loan doesn't pull funds, and this can't revert due to loss of context, resulting in stuck funds.
            _prepareFundsForLoan(msg.sender, _uint256(-principal_));
        }

        // Track the new payment.
        Payment memory nextPayment_ = _addPayment(msg.sender);

        // Update accounting and account for discrepancies in paid interest vs accrued interest since the payment's start date, and exit.
        _updateAccountingState(interestAdjustment_, _int256(nextPayment_.issuanceRate) - _int256(claimedPayment_.issuanceRate));
    }

    /**************************************************************************************************************************************/
    /*** Loan Call Functions                                                                                                            ***/
    /**************************************************************************************************************************************/

    // TODO: Check if we want to also allow the governor to `call()` and `removeCall()`
    function callPrincipal(address loan_, uint256 principal_) external override notPaused {
        require(msg.sender == poolDelegate(), "LM:C:NOT_PD");

        IMapleLoanLike(loan_).callPrincipal(principal_);
    }

    function removeCall(address loan_) external override notPaused {
        require(msg.sender == poolDelegate(), "LM:RC:NOT_PD");

        IMapleLoanLike(loan_).removeCall();
    }

    /**************************************************************************************************************************************/
    /*** Loan Impairment Functions                                                                                                      ***/
    /**************************************************************************************************************************************/

    function impairLoan(address loan_) external override notPaused {
        bool isGovernor_ = msg.sender == governor();

        require(isGovernor_ || msg.sender == poolDelegate(), "LM:IL:NO_AUTH");

        _accountForLoanImpairment(loan_, isGovernor_);

        IMapleLoanLike(loan_).impair();
    }

    function removeLoanImpairment(address loan_) external override notPaused {
        ( , bool impairedByGovernor ) = _accountForLoanImpairmentRemoval(loan_);

        require(msg.sender == governor() || (!impairedByGovernor && msg.sender == poolDelegate()), "LM:RLI:NO_AUTH");

        IMapleLoanLike(loan_).removeImpairment();
    }

    /**************************************************************************************************************************************/
    /*** Loan Default Functions                                                                                                         ***/
    /**************************************************************************************************************************************/

    function triggerDefault(
        address loan_,
        address liquidatorFactory_
    ) external override returns (bool liquidationComplete_, uint256 remainingLosses_, uint256 platformFees_) {
        liquidatorFactory_;  // Silence compiler warning.
        ( remainingLosses_, platformFees_ ) = triggerDefault(loan_);
        liquidationComplete_ = true;
    }

    function triggerDefault(address loan_) public override notPaused returns (uint256 remainingLosses_, uint256 platformFees_) {
        require(msg.sender == poolManager, "LM:TD:NOT_PM");

        // Always remove impairment before proceeding, to clean up state and streamline remaining logic.
        _accountForLoanImpairmentRemoval(loan_);

        // Remove the payment and cache the struct.
        Payment memory payment_ = _removePayment(loan_);

        ( , uint256 interest_, uint256 lateInterest_, , uint256 platformServiceFee_ )
            = IMapleLoanLike(loan_).paymentBreakdown(block.timestamp);

        // Get total interest net of management fees owed to the platform.
        uint256 totalInterestNetOfManagementFees_
            = _getNetInterest(interest_ + lateInterest_, payment_.delegateManagementFeeRate + payment_.platformManagementFeeRate);

        uint256 principal_ = IMapleLoanLike(loan_).principal();

        // Pool's unrealized loses are the outstanding principal and total interest net of management fees.
        uint256 unrealizedLosses_ = principal_ + totalInterestNetOfManagementFees_;

        // Pull any `fundsAsset` in loan into LM.
        uint256 recoveredFunds_ = IMapleLoanLike(loan_).repossess(address(this));

        platformFees_ = _getRatedAmount(interest_ + lateInterest_, payment_.platformManagementFeeRate) + platformServiceFee_;

        // Distribute the recovered funds (to treasury, pool, and borrower) and determine the losses, if any, that must still be realized.
        // TODO: Update this return value to capture all losses, not just LP losses.
        remainingLosses_ = _distributeLiquidationFunds(loan_, recoveredFunds_, platformFees_, unrealizedLosses_);

        // The payment's interest until now must be deducted from `accountedInterest`, thus realizing the interest loss.
        // The payment's `issuanceRate` must be deducted from the global `issuanceRate`.
        // The the loan's principal must be deducted from `principalOut`, hus realizing the principal loss.
        _updateAccountingState(
            -_int256(_getIssuance(payment_.issuanceRate, block.timestamp - payment_.startDate)),
            -_int256(payment_.issuanceRate)
        );

        _updatePrincipalOut(-_int256(principal_));
    }

    /**************************************************************************************************************************************/
    /*** Internal Functions                                                                                                             ***/
    /**************************************************************************************************************************************/

    function _addPayment(address loan_) internal returns (Payment memory payment_) {
        uint256 platformManagementFeeRate_ = IMapleGlobalsLike(globals()).platformManagementFeeRate(poolManager);
        uint256 delegateManagementFeeRate_ = IPoolManagerLike(poolManager).delegateManagementFeeRate();
        uint256 managementFeeRate_         = platformManagementFeeRate_ + delegateManagementFeeRate_;

        // NOTE: If combined fee is greater than 100%, then cap delegate fee and clamp management fee.
        if (managementFeeRate_ > HUNDRED_PERCENT) {
            delegateManagementFeeRate_ = HUNDRED_PERCENT - platformManagementFeeRate_;
            managementFeeRate_         = HUNDRED_PERCENT;
        }

        uint256 paymentDueDate_ = IMapleLoanLike(loan_).paymentDueDate();
        uint256 dueInterest_    = _getNetInterest(loan_, paymentDueDate_, managementFeeRate_);

        // NOTE: Can assume `paymentDueDate_ > block.timestamp` and interest at `block.timestamp` is 0 because payments are only added when
        //         - loans are funded, or
        //         - payments are claimed, resulting in a new payment.
        uint256 paymentIssuanceRate_ = (dueInterest_ * PRECISION) / (paymentDueDate_ - block.timestamp);

        paymentFor[loan_] = payment_ = Payment({
            platformManagementFeeRate: _uint24(platformManagementFeeRate_),
            delegateManagementFeeRate: _uint24(delegateManagementFeeRate_),
            startDate:                 _uint40(block.timestamp),
            issuanceRate:              _uint168(paymentIssuanceRate_)
        });

        emit PaymentAdded(
            loan_,
            platformManagementFeeRate_,
            delegateManagementFeeRate_,
            paymentDueDate_,
            paymentIssuanceRate_
        );
    }

    function _accountForLoanImpairment(address loan_, bool isGovernor_) internal {
        Payment memory payment_ = paymentFor[loan_];

        require(payment_.startDate != 0, "LM:AFLI:NOT_LOAN");

        if (impairmentFor[loan_].impairedDate != 0) return;

        impairmentFor[loan_] = Impairment(_uint40(block.timestamp), isGovernor_);

        // Account for all interest until now (including this payment's), then remove payment's `issuanceRate` from global `issuanceRate`.
        _updateAccountingState(0, -_int256(payment_.issuanceRate));

        uint256 principal_ = IMapleLoanLike(loan_).principal();

        // Add the payment's entire interest until now (negating above), and the loan's principal, to unrealized losses.
        _updateUnrealizedLosses(_int256(principal_ + _getIssuance(payment_.issuanceRate, block.timestamp - payment_.startDate)));
    }

    function _accountForLoanImpairmentRemoval(address loan_) internal returns (uint40 impairedDate_, bool impairedByGovernor_) {
        Payment memory payment_ = paymentFor[loan_];

        require(payment_.startDate != 0, "LM:AFLIR:NOT_LOAN");

        Impairment memory impairment_ = impairmentFor[loan_];

        impairedDate_       = impairment_.impairedDate;
        impairedByGovernor_ = impairment_.impairedByGovernor;

        if (impairedDate_ == 0) return ( impairedDate_, impairedByGovernor_ );

        delete impairmentFor[loan_];

        uint256 principal_ = IMapleLoanLike(loan_).principal();

        // Subtract the payment's entire interest until it's impairment date, and the loan's principal, from unrealized losses.
        _updateUnrealizedLosses(-_int256(principal_ + _getIssuance(payment_.issuanceRate, impairedDate_ - payment_.startDate)));

        // Account for all interest until now, adjusting for payment's interest between its impairment date and now,
        // then add payment's `issuanceRate` from global `issuanceRate`.
        // NOTE: Upon impairment, for payment's interest between its start date and its impairment date were accounted for.
        _updateAccountingState(
            _int256(_getIssuance(payment_.issuanceRate, block.timestamp - impairedDate_)),
            _int256(payment_.issuanceRate)
        );
    }

    function _distributeClaimedFunds(
        address loan_,
        int256  principal_,
        uint256 interest_,
        uint256 delegateServiceFee_,
        uint256 platformServiceFee_
    )
        internal
    {
        Payment memory payment_ = paymentFor[loan_];

        uint256 platformManagementFee_ = _getRatedAmount(interest_, payment_.platformManagementFeeRate);

        // TODO: Consider doing the same logic for service fees as well.
        uint256 delegateManagementFee_ = IPoolManagerLike(poolManager).hasSufficientCover()
            ? _getRatedAmount(interest_, payment_.delegateManagementFeeRate)
            : 0;

        uint256 netInterest_ = interest_ - (platformManagementFee_ + delegateManagementFee_);
        uint256 delegateFee_ = delegateServiceFee_ + delegateManagementFee_;
        uint256 platformFee_ = platformServiceFee_ + platformManagementFee_;

        principal_ = principal_ > int256(0) ? principal_ : int256(0);

        emit ManagementFeesPaid(loan_, delegateFee_, platformManagementFee_);
        emit FundsDistributed(loan_, uint256(principal_), netInterest_);

        uint256 toPool_ = uint256(principal_) + netInterest_;

        address fundsAsset_ = fundsAsset;
        address pool_       = pool();

        require(pool_ != address(0),                                               "LM:DCF:ZERO_ADDRESS_POOL");
        require(toPool_ == 0 || ERC20Helper.transfer(fundsAsset_, pool_, toPool_), "LM:DCF:TRANSFER_POOL");

        address poolDelegate_ = poolDelegate();

        require(poolDelegate_ != address(0),                                                         "LM:DCF:ZERO_ADDRESS_PD");
        require(delegateFee_ == 0 || ERC20Helper.transfer(fundsAsset_, poolDelegate_, delegateFee_), "LM:DCF:TRANSFER_PD");

        address treasury_ = mapleTreasury();

        require(treasury_ != address(0),                                                         "LM:DCF:ZERO_ADDRESS_MT");
        require(platformFee_ == 0 || ERC20Helper.transfer(fundsAsset_, treasury_, platformFee_), "LM:DCF:TRANSFER_MT");
    }

    function _distributeLiquidationFunds(address loan_, uint256 recoveredFunds_, uint256 platformFees_, uint256 unrealizedLosses_)
        internal returns (uint256 remainingLosses_)
    {
        uint256 toTreasury_ = _min(recoveredFunds_, platformFees_);

        recoveredFunds_ -= toTreasury_;

        uint256 toPool_ = _min(recoveredFunds_, unrealizedLosses_);

        recoveredFunds_ -= toPool_;

        address fundsAsset_ = fundsAsset;
        address pool_       = pool();

        require(pool_ != address(0),                                               "LM:DLF:ZERO_ADDRESS_POOL");
        require(toPool_ == 0 || ERC20Helper.transfer(fundsAsset_, pool_, toPool_), "LM:DLF:TRANSFER_POOL");

        address treasury_ = mapleTreasury();

        require(treasury_ != address(0),                                                       "LM:DLF:ZERO_ADDRESS_MT");
        require(toTreasury_ == 0 || ERC20Helper.transfer(fundsAsset_, treasury_, toTreasury_), "LM:DLF:TRANSFER_MT");

        address borrower_ = IMapleLoanLike(loan_).borrower();

        require(borrower_ != address(0),                                                               "LM:DLF:ZERO_ADDRESS_B");
        require(recoveredFunds_ == 0 || ERC20Helper.transfer(fundsAsset_, borrower_, recoveredFunds_), "LM:DLF:TRANSFER_B");

        remainingLosses_ = unrealizedLosses_ + (toTreasury_ - platformFees_) - toPool_;
    }

    function _prepareFundsForLoan(address loan_, uint256 amount_) internal {
        // Request funds from pool manager.
        IPoolManagerLike(poolManager).requestFunds(address(this), amount_);

        // Approve the loan to use this funds.
        require(ERC20Helper.approve(fundsAsset, loan_, amount_), "LM:PFFL:APPROVE_FAILED");
    }

    function _removePayment(address loan_) internal returns (Payment memory payment_) {
        payment_ = paymentFor[loan_];

        delete paymentFor[loan_];

        emit PaymentRemoved(loan_);
    }

    function _updateAccountingState(int256 interestAdjustment_, int256 issuanceRateAdjustment_) internal {
        // NOTE: Order of operations is important as `accruedInterest()` depends on the pre-adjusted `issuanceRate` and `domainStart`.
        // TODO: Underflow protection in case more interest or `issuanceRate` is adjusted down, clamping to 0.
        accountedInterest = _uint112(_int256(accountedInterest + accruedInterest()) + interestAdjustment_);
        domainStart       = _uint40(block.timestamp);
        issuanceRate      = _uint256(_int256(issuanceRate) + issuanceRateAdjustment_);

        emit AccountingStateUpdated(issuanceRate, accountedInterest);
    }

    function _updatePrincipalOut(int256 principalOutAdjustment_) internal {
        // TODO: Underflow protection in case more principal is returned, clamping to 0.
        emit PrincipalOutUpdated(principalOut = _uint128(_int256(principalOut) + principalOutAdjustment_));
    }

    function _updateUnrealizedLosses(int256 losesAdjustment_) internal {
        // TODO: Underflow protection in case more unrealized losses are reverted, clamping to 0.
        emit UnrealizedLossesUpdated(unrealizedLosses = _uint128(_int256(unrealizedLosses) + losesAdjustment_));
    }

    /**************************************************************************************************************************************/
    /*** Internal Loan Accounting Helper Functions                                                                                      ***/
    /**************************************************************************************************************************************/

    function _getIssuance(uint256 issuanceRate_, uint256 interval_) internal pure returns (uint256 issuance_) {
        issuance_ = (issuanceRate_ * interval_) / PRECISION;
    }

    function _getNetInterest(address loan_, uint256 timestamp_, uint256 managementFeeRate_) internal view returns (uint256 netInterest_) {
        ( , uint256 interest_, , , ) = IMapleLoanLike(loan_).paymentBreakdown(timestamp_);

        netInterest_ = _getNetInterest(interest_, managementFeeRate_);
    }

    function _getNetInterest(uint256 interest_, uint256 feeRate_) internal pure returns (uint256 netInterest_) {
        // NOTE: This ensures that `netInterest_ == interest_ + fee_`, since absolutes are subtracted, not rates.
        netInterest_ = interest_ - _getRatedAmount(interest_, feeRate_);
    }

    function _getRatedAmount(uint256 amount_, uint256 rate_) internal pure returns (uint256 ratedAmount_) {
        ratedAmount_ = (amount_ * rate_) / HUNDRED_PERCENT;
    }

    /**************************************************************************************************************************************/
    /*** Loan Manager View Functions                                                                                                    ***/
    /**************************************************************************************************************************************/

    function accruedInterest() public view override returns (uint256 accruedInterest_) {
        uint256 issuanceRate_ = issuanceRate;

        accruedInterest_ = issuanceRate_ == 0 ? 0 : _getIssuance(issuanceRate_, block.timestamp - domainStart);
    }

    function assetsUnderManagement() public view virtual override returns (uint256 assetsUnderManagement_) {
        assetsUnderManagement_ = principalOut + accountedInterest + accruedInterest();
    }

    /**************************************************************************************************************************************/
    /*** Protocol Address View Functions                                                                                                ***/
    /**************************************************************************************************************************************/

    function factory() external view override returns (address factory_) {
        factory_ = _factory();
    }

    function globals() public view override returns (address globals_) {
        globals_ = IMapleProxyFactory(_factory()).mapleGlobals();
    }

    function governor() public view override returns (address governor_) {
        governor_ = IMapleGlobalsLike(globals()).governor();
    }

    function implementation() external view override returns (address implementation_) {
        implementation_ = _implementation();
    }

    function mapleTreasury() public view override returns (address treasury_) {
        treasury_ = IMapleGlobalsLike(globals()).mapleTreasury();
    }

    function pool() public view override returns (address pool_) {
        pool_ = IPoolManagerLike(poolManager).pool();
    }

    function poolDelegate() public view override returns (address poolDelegate_) {
        poolDelegate_ = IPoolManagerLike(poolManager).poolDelegate();
    }

    /**************************************************************************************************************************************/
    /*** Internal Pure Utility Functions                                                                                                ***/
    /**************************************************************************************************************************************/

    function _int256(uint256 input_) internal pure returns (int256 output_) {
        require(input_ <= uint256(type(int256).max), "LM:UINT256_OOB_FOR_INT256");
        output_ = int256(input_);
    }

    function _min(uint256 a_, uint256 b_) internal pure returns (uint256 minimum_) {
        minimum_ = a_ < b_ ? a_ : b_;
    }

    function _uint24(uint256 input_) internal pure returns (uint24 output_) {
        require(input_ <= type(uint24).max, "LM:UINT256_OOB_FOR_UINT24");
        output_ = uint24(input_);
    }

    function _uint40(uint256 input_) internal pure returns (uint40 output_) {
        require(input_ <= type(uint40).max, "LM:UINT256_OOB_FOR_UINT40");
        output_ = uint40(input_);
    }

    function _uint112(int256 input_) internal pure returns (uint112 output_) {
        require(input_ <= int256(uint256(type(uint112).max)) && input_ >= 0, "LM:INT256_OOB_FOR_UINT112");
        output_ = uint112(uint256(input_));
    }

    function _uint128(int256 input_) internal pure returns (uint128 output_) {
        require(input_ <= int256(uint256(type(uint128).max)) && input_ >= 0, "LM:INT256_OOB_FOR_UINT128");
        output_ = uint128(uint256(input_));
    }

    function _uint168(uint256 input_) internal pure returns (uint168 output_) {
        require(input_ <= type(uint168).max, "LM:UINT256_OOB_FOR_UINT168");
        output_ = uint168(input_);
    }

    function _uint168(int256 input_) internal pure returns (uint168 output_) {
        require(input_ <= int256(uint256(type(uint168).max)) && input_ >= 0, "LM:INT256_OOB_FOR_UINT168");
        output_ = uint168(uint256(input_));
    }

    function _uint256(int256 input_) internal pure returns (uint256 output_) {
        require(input_ >= 0, "LM:INT256_OOB_FOR_UINT256");
        output_ = uint256(uint256(input_));
    }

}
