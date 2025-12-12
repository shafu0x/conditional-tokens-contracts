// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

type ConditionId is bytes32;
type QuestionId  is bytes32;

struct ConditionParams {
    address    oracle;
    QuestionId questionId;
}