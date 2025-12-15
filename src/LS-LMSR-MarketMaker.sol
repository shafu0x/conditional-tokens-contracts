// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {
    wadExp,
    wadLn,
    wadMul,
    wadDiv
} from "solmate/utils/SignedWadMath.sol";

import {PositionLib} from "./libraries/PositionLib.sol";
import {MarketMaker} from "./MarketMaker.sol";

contract LS_LMSR_MarketMaker is MarketMaker {

    int constant WAD = 1e18;

    // b = alpha * funding. Higher alpha more liquid market
    uint public alpha;

    // Cost = b * ln(exp(yesAmount / b) + exp(noAmount / b))
    // NetCost = Cost(after) - Cost(before)
    function calcNetCost(
        int yesAmount, 
        int noAmount
    ) 
        public 
        view 
        override 
        returns (int netCost) 
    {
        int b = int(alpha * funding / 1e18);
        require(b > 0);

        int qYes = -int(conditionalTokens.balanceOf(
            address(this),
            PositionLib.yesId(collateralToken, conditionId)
        ));
        int qNo  = -int(conditionalTokens.balanceOf(
            address(this),
            PositionLib.noId(collateralToken, conditionId)
        ));

        int costBefore = _costFunction(qYes, qNo, b);
        int costAfter  = _costFunction(qYes + yesAmount, qNo + noAmount, b);

        return costAfter - costBefore;
    }

    function _costFunction(
        int qYes,
        int qNo,
        int b
    ) 
        internal
        pure 
        returns (int)
    {
        int maxQ   = qYes > qNo ? qYes : qNo;
        int offset = wadDiv(maxQ, b);

        int expYes = wadExp(wadDiv(qYes, b) - offset);
        int expNo  = wadExp(wadDiv(qNo,  b) - offset);

        int sum = expYes + expNo;
        return wadMul(b, wadLn(sum) + offset);
    }

    function priceYes() 
        public 
        view 
        returns (uint)
    {
        int b = int(alpha * funding / 1e18);
        if (b <= 0) return 0.5e18; // default to 50%

        int qYes = -int(conditionalTokens.balanceOf(
            address(this),
            PositionLib.yesId(collateralToken, conditionId)
        ));

        int qNo = -int(conditionalTokens.balanceOf(
            address(this),
            PositionLib.noId(collateralToken, conditionId)
        ));

        int maxQ   = qYes > qNo ? qYes : qNo;
        int offset = wadDiv(maxQ, b);

        int expYes = wadExp(wadDiv(qYes, b) - offset);
        int expNo  = wadExp(wadDiv(qNo,  b) - offset);

        return uint(wadDiv(expYes, expYes + expNo));
    }

    function priceNo()
        public
        view
        returns (uint)
    {
        return 1e18 - priceYes();
    }
}