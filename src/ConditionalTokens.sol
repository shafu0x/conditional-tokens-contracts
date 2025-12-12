// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC6909} from "solmate/tokens/ERC6909.sol";

import {ConditionParamsLib} from "./libraries/ConditionParamsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {
    ConditionParams, 
    ConditionId,
    QuestionId
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
        emit EventsLib.Prepared(
            conditionId, 
            params.oracle, 
            params.questionId, 
            params.outcomeSlotCount
        );
    }

    function resolve(
        QuestionId questionId, 
        uint[]     calldata payouts
    ) external {
        uint outcomeSlotCount = payouts.length;
        require(outcomeSlotCount > 1);
        ConditionId conditionId = ConditionParams(
            msg.sender, 
            questionId, 
            outcomeSlotCount)
        .id();
        require(payoutNumerators [conditionId].length == outcomeSlotCount);
        require(payoutDenominator[conditionId]        == 0);
        uint den = 0;
        for (uint i = 0; i < outcomeSlotCount; i++) {
            uint num = payouts[i];
            den += num;
            require(payoutNumerators[conditionId][i] == 0);
            payoutNumerators[conditionId][i] = num;
        }
        require(den > 0);
        payoutDenominator[conditionId] = den;
        emit EventsLib.Resolved(
            conditionId,
            msg.sender,
            questionId,
            outcomeSlotCount,
            payoutNumerators[conditionId]
        );
    }
}