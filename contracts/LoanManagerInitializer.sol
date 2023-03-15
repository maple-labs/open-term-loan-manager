// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { ILoanManagerInitializer } from "./interfaces/ILoanManagerInitializer.sol";
import { IPoolManagerLike }        from "./interfaces/Interfaces.sol";

import { LoanManagerStorage } from "./LoanManagerStorage.sol";

// TODO: Better to take just the `poolManager` as an argument. `pool` is property of `poolManager`, as is `poolDelegate`.

contract LoanManagerInitializer is ILoanManagerInitializer, LoanManagerStorage {

    function decodeArguments(bytes calldata calldata_) public pure override returns (address poolManager_) {
        poolManager_ = abi.decode(calldata_, (address));
    }

    function encodeArguments(address poolManager_) external pure override returns (bytes memory calldata_) {
        calldata_ = abi.encode(poolManager_);
    }

    function _initialize(address poolManager_) internal {
        _locked = 1;

        fundsAsset = IPoolManagerLike(
            poolManager = poolManager_
        ).asset();

        emit Initialized(poolManager);
    }

    fallback() external {
        _initialize(decodeArguments(msg.data));
    }

}
