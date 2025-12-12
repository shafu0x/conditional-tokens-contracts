// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {
    ConditionId, 
    QuestionId
} from "../interfaces/IConditionalTokens.sol";

library EventsLib {
    event Prepare(
        ConditionId indexed conditionId,
        address     indexed oracle,
        QuestionId  indexed questionId
    );

    event Resolve(
        ConditionId indexed conditionId,
        address     indexed oracle,
        QuestionId  indexed questionId,
        bool                outcome
    );

    event Split(
        address     indexed stakeholder,
        ConditionId indexed conditionId,
        IERC20      indexed collateralToken,
        uint                amount
    );

    event Merge(
        address     indexed stakeholder,
        ConditionId indexed conditionId,
        IERC20      indexed collateralToken,
        uint                amount
    );

    event Redeem(
        address     indexed stakeholder,
        ConditionId indexed conditionId,
        IERC20      indexed collateralToken,
        uint                amount
    );
}