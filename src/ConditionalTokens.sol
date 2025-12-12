// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC6909} from "solmate/tokens/ERC6909.sol";

import {ConditionParamsLib} from "./libraries/ConditionParamsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {
    ConditionParams, 
    ConditionId
} from "./interfaces/IConditionalTokens.sol";

contract ConditionalTokens is ERC6909 {
    using ConditionParamsLib for ConditionParams;

    mapping(ConditionId => uint[]) public payoutNumerators;
    mapping(ConditionId => uint)   public payoutDenominator;

    function prepare(ConditionParams memory params) external {
        require(params.outcomeSlotCount <= 256);
        require(params.outcomeSlotCount  > 1);
        ConditionId conditionId = params.id();
        require(payoutNumerators[conditionId].length == 0);
        payoutNumerators[conditionId] = new uint[](params.outcomeSlotCount);
        emit EventsLib.ConditionPreparation(
            conditionId, 
            params.oracle, 
            params.questionId, 
            params.outcomeSlotCount
        );
    }

    // function resolve(bytes32 )
}