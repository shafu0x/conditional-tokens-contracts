// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {
    wadExp,
    wadLn,
    wadMul,
    wadDiv
} from "solmate/utils/SignedWadMath.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {MarketMaker}       from "./MarketMaker.sol";
import {ConditionalTokens} from "./ConditionalTokens.sol";
import {ConditionId}       from "./interfaces/IConditionalTokens.sol";

contract LS_LMSR_MarketMaker is MarketMaker {
    // LS-LMSR: b = alpha * (qYes + qNo). Liquidity grows with trading.
    uint public alpha;

    constructor(
        uint              _alpha,
        ConditionalTokens _conditionalTokens,
        IERC20            _collateralToken,
        ConditionId       _conditionId
    ) MarketMaker(
        _conditionalTokens, 
        _collateralToken, 
        _conditionId
    ) {
        alpha = _alpha;
    }

    // Cost = b * ln(exp(qYes / b) + exp(qNo / b))
    // NetCost = Cost(after) - Cost(before)
    // LS-LMSR: b = alpha * totalOutstanding (liquidity grows with trading)
    function calcNetCost(
        int yesAmount, 
        int noAmount
    ) 
        public 
        view 
        override 
        returns (int netCost) 
    {
        int b = _b(qYes + yesAmount, qNo + noAmount);
        require(b > 0);

        int costBefore = _costFunction(qYes, qNo, b);
        int costAfter  = _costFunction(qYes + yesAmount, qNo + noAmount, b);

        return costAfter - costBefore;
    }

    function _b(
        int newQYes, 
        int newQNo
    ) 
        internal 
        view 
        returns (int b) 
    {
        int totalQ = newQYes + newQNo;
        
        if (totalQ > 0) {
            b = int(alpha) * totalQ / 1e18;
        } else {
            b = int(alpha * funding / 1e18);
        }
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
        int b = _b(qYes, qNo);
        if (b <= 0) return 0.5e18; // default to 50%

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