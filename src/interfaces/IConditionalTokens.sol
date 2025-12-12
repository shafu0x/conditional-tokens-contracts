// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

type Id is bytes32;

struct ConditionParams {
    address oracle;
    bytes32 questionId;
    uint    outcomeSlotCount;
}

interface IConditionalTokens {
    event ConditionPreparation(
        bytes32 indexed conditionId,
        address indexed oracle,
        bytes32 indexed questionId,
        uint            outcomeSlotCount
    );
}