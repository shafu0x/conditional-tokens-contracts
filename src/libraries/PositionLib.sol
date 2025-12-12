// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {ConditionId} from "../interfaces/IConditionalTokens.sol";

library PositionLib {
    function id(IERC20 collateralToken, ConditionId conditionId) internal pure returns (uint positionId) {
        assembly("memory-safe") {
            positionId := keccak256(collateralToken, conditionId)
        }
    }
}