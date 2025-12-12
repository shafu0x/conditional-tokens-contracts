// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC6909} from "solmate/tokens/ERC6909.sol";

import {ConditionParamsLib} from "./libraries/ConditionParamsLib.sol";
import {
    ConditionParams,
     Id
} from "./interfaces/IConditionalTokens.sol";

contract ConditionalTokens is ERC6909 {
    using ConditionParamsLib for ConditionParams;

    function prepareCondition(ConditionParams memory params) external {
        require(params.outcomeSlotCount <= 256);
        require(params.outcomeSlotCount  > 1);
        Id conditionId = params.id();
    }
}