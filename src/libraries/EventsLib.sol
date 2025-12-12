// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {
    ConditionId, 
    QuestionId
} from "../interfaces/IConditionalTokens.sol";

library EventsLib {
    event ConditionPreparation(
        ConditionId indexed conditionId,
        address     indexed oracle,
        QuestionId  indexed questionId,
        uint        outcomeSlotCount
    );
}