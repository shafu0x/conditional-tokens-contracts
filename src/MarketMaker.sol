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

    function buyYes(
        uint amount,
        uint maxCost
    )
        external 
        returns (uint cost) 
    {
        int netCost = calcNetCost(int(amount), 0);
        require(netCost > 0);
        cost = _addFee(uint(netCost));
        require(cost <= maxCost);
        collateralToken.transferFrom(msg.sender, address(this), cost);
        collateralToken.approve(address(conditionalTokens), uint(netCost));
        conditionalTokens.split(conditionId, collateralToken, uint(netCost));
        conditionalTokens.transfer(
            msg.sender,
            PositionLib.yesId(collateralToken, conditionId),
            uint(amount)
        );
    }

    function buyNo(
        uint amount,
        uint maxCost
    )
        external
        returns (uint cost)
    {
        int netCost = calcNetCost(0, int(amount));
        require(netCost > 0);
        cost = _addFee(uint(netCost));
        require(cost <= maxCost);
        collateralToken.transferFrom(msg.sender, address(this), cost);
        collateralToken.approve(address(conditionalTokens), uint(netCost));
        conditionalTokens.split(conditionId, collateralToken, uint(netCost));
        conditionalTokens.transfer(
            msg.sender,
            PositionLib.noId(collateralToken, conditionId),
            uint(amount)
        );
    }

    function sellYes(
        uint amount,
        uint minPayout
    )
        external
        returns (uint payout)
    {
        int netCost = calcNetCost(-int(amount), 0);
        require(netCost < 0);
        payout = _subFee(uint(-netCost));
        require(payout >= minPayout);
        conditionalTokens.transferFrom(
            msg.sender,
            address(this), 
            PositionLib.yesId(collateralToken, conditionId), 
            uint(amount)
        );
        conditionalTokens.merge(conditionId, collateralToken, uint(-netCost));
        collateralToken.transfer(msg.sender, payout);
    }

    function sellNo(
        uint amount, 
        uint minPayout
    ) 
        external 
        returns (uint payout) 
    {
        int netCost = calcNetCost(0, -int(amount));
        require(netCost < 0);
        payout = _subFee(uint(-netCost));
        require(payout >= minPayout);
        conditionalTokens.transferFrom(
            msg.sender, 
            address(this), 
            PositionLib.noId(collateralToken, conditionId), 
            amount
        );
        conditionalTokens.merge(conditionId, collateralToken, uint(-netCost));
        collateralToken.transfer(msg.sender, payout);
    }

    function _addFee(uint amount)
        internal
        view 
        returns (uint)
    {
        return amount + (amount * fee / 1e18);
    }

    function _subFee(uint amount)
        internal
        view 
        returns (uint)
    {
        return amount - (amount * fee / 1e18);
    }

    function calcNetCost(int yesAmount, int noAmount) public virtual returns (int netCost);
}