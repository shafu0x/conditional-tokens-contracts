// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {
    ConditionId, 
    QuestionId
} from "../interfaces/IConditionalTokens.sol";

library EventsLib {
    event Prepared(
        ConditionId indexed conditionId,
        address     indexed oracle,
        QuestionId  indexed questionId
    );

    event Resolved(
        ConditionId indexed conditionId,
        address     indexed oracle,
        QuestionId  indexed questionId,
        bool                outcome
    );
}