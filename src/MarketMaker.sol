// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Owned}  from "solmate/auth/Owned.sol";

import {PositionLib}       from "./libraries/PositionLib.sol";
import {ConditionalTokens} from "./ConditionalTokens.sol";
import {ConditionId}       from "./interfaces/IConditionalTokens.sol";
import { Stage }           from "./interfaces/IMarketMaker.sol";

abstract contract MarketMaker is Owned(msg.sender) {
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
        int yesAmount,
        int noAmount,
        int collateralLimit
    )
        public
        returns (int netCost)
    {
        int outcomeTokenNetCost = calcNetCost(yesAmount, noAmount);

        // TODO: use lib
        uint absCost = outcomeTokenNetCost >= 0 
            ? uint(outcomeTokenNetCost)
            : uint(-outcomeTokenNetCost);

        // TODO: use lib
        int fees = int(absCost * fee / 1e18);

        netCost = outcomeTokenNetCost + fees;

        // slippage check
        require(
            collateralLimit == 0 || netCost <= int(collateralLimit)
        );

        uint yesPositionId = PositionLib.yesId(collateralToken, conditionId);
        uint noPositionId  = PositionLib.noId (collateralToken, conditionId);

        // If buying, pull collateral and split
        if (outcomeTokenNetCost > 0) {
            require(
                collateralToken.transferFrom(
                    msg.sender,
                    address(this),
                    uint(outcomeTokenNetCost)
                )
            );
            collateralToken.approve(
                address(conditionalTokens),
                uint   (outcomeTokenNetCost)
            );
            conditionalTokens.split(
                conditionId,
                collateralToken,
                uint(outcomeTokenNetCost)
            );
        }

        if (yesAmount < 0 ) {
            conditionalTokens.transferFrom(
                msg.sender,
                address(this),
                yesPositionId,
                uint(-yesAmount)
            );
        }
        if (noAmount < 0) {
            conditionalTokens.transferFrom(
                msg.sender,
                address(this),
                noPositionId,
                uint(-noAmount)
            );
        }

        if (outcomeTokenNetCost < 0) {
            conditionalTokens.merge(
                conditionId,
                collateralToken,
                uint(-outcomeTokenNetCost)
            );
        }

        if (yesAmount > 0) {
            conditionalTokens.transfer(
                msg.sender,
                yesPositionId,
                uint(yesAmount)
            );
        }
        if (noAmount > 0) {
            conditionalTokens.transfer(
                msg.sender,
                noPositionId,
                uint(noAmount)
            );
        }

        if (netCost < 0) {
            require(
                collateralToken.transfer(
                    msg.sender,
                    uint(-netCost)
                )
            );
        }
    }

    function calcNetCost(int yesAmount, int noAmount) public virtual returns (int netCost);
}