// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {
    ConditionParams, 
    ConditionId
} from "../interfaces/IConditionalTokens.sol";

library ConditionParamsLib {
    uint internal constant CONDITION_PARAMS_LENGTH = 2 * 32;

    function id(ConditionParams memory params) 
        internal 
        pure 
        returns (ConditionId conditionId) 
    {
        assembly("memory-safe") {
            conditionId := keccak256(
                params,
                CONDITION_PARAMS_LENGTH
            )
        }
    }
}