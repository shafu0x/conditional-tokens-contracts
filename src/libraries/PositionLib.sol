// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {ConditionId} from "../interfaces/IConditionalTokens.sol";

library PositionLib {
    function yesId(IERC20 collateralToken, ConditionId conditionId) internal pure returns (uint positionId) {
        return uint256(
            keccak256(
                abi.encode(
                    collateralToken, 
                    conditionId, 
                    "yes"
                )
            )
        );
    }

    function noId(IERC20 collateralToken, ConditionId conditionId) internal pure returns (uint positionId) {
        return uint256(
            keccak256(
                abi.encode(
                    collateralToken, 
                    conditionId, 
                    "no"
                )
            )
        );
    }
}