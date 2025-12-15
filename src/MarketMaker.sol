// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Owned}  from "solmate/auth/Owned.sol";

import {ConditionalTokens} from "./ConditionalTokens.sol";
import {ConditionId}       from "./interfaces/IConditionalTokens.sol";
import { Stage }           from "./interfaces/IMarketMaker.sol";

contract MarketMaker is Owned(msg.sender) {
    ConditionalTokens public conditionalTokens;
    IERC20            public collateralToken;
    uint              public fee;
    uint              public funding;
    ConditionId       public conditionId;

    function changeFunding(int fundingChange) 
        public 
    {
        require(fundingChange != 0);
        // adding funding
        if (fundingChange > 0) {
            require(
                collateralToken.transferFrom(
                    msg.sender,
                    address(this),
                    uint(fundingChange)
                )
            );
            require(
                collateralToken.approve(
                    address(conditionalTokens),
                    uint(fundingChange)
                )
            );
            conditionalTokens.split(
                conditionId,
                collateralToken,
                uint(fundingChange)
            );
            funding += uint(fundingChange);
        // removing funding
        } else {
            conditionalTokens.merge(
                conditionId,
                collateralToken,
                uint(-fundingChange)
            );
            funding -= uint(-fundingChange);
            require(
                collateralToken.transfer(
                    owner,
                    uint(-fundingChange)
                )
            );
        }
    } 

    function trade(
        uint[] memory outcomeTokenAmounts,
        int           collateralLimit
    )
        public
        returns (int netCost)
    {
        return 0;
    }
}