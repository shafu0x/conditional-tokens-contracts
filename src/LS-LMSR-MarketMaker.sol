// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {wadExp, wadLn, wadMul, wadDiv} from "solmate/utils/SignedWadMath.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {MarketMaker}       from "./MarketMaker.sol";
import {ConditionalTokens} from "./ConditionalTokens.sol";
import {ConditionId}       from "./interfaces/IConditionalTokens.sol";

contract LS_LMSR_MarketMaker is MarketMaker {
    // b = b0 + alphaWad * bank
    // alphaWad is WAD-scaled (1e18 means b increases 1:1 with bank)
    uint256 public alphaWad;
    uint256 public b0;    // MUST be > 0 so the first trade can happen

    constructor(
        uint256           _alphaWad,
        uint256           _b0,
        ConditionalTokens _conditionalTokens,
        IERC20            _collateralToken,
        ConditionId       _conditionId
    ) MarketMaker(_conditionalTokens, _collateralToken, _conditionId) {
        require(_b0 > 0, "b0=0");
        alphaWad = _alphaWad;
        b0       = _b0;
    }

    function _b() internal view returns (int256) {
        // b = b0 + (alphaWad * bank) / 1e18
        uint256 b = b0 + (alphaWad * bank) / 1e18;
        return int256(b);
    }

    function calcNetCost(int256 yesAmount, int256 noAmount)
        public
        view
        override
        returns (int256)
    {
        int256 b = _b(); // IMPORTANT: constant for the whole quote
        int256 beforeC = _cost(qYes, qNo, b);
        int256 afterC  = _cost(qYes + yesAmount, qNo + noAmount, b);
        return afterC - beforeC;
    }

    function _cost(int256 qY, int256 qN, int256 b) internal pure returns (int256) {
        int256 maxQ   = qY > qN ? qY : qN;
        int256 offset = wadDiv(maxQ, b);

        int256 expY = wadExp(wadDiv(qY, b) - offset);
        int256 expN = wadExp(wadDiv(qN, b) - offset);

        return wadMul(b, wadLn(expY + expN) + offset);
    }

    function priceYes() public view returns (uint256) {
        int256 b = _b();

        int256 maxQ   = qYes > qNo ? qYes : qNo;
        int256 offset = wadDiv(maxQ, b);

        int256 expY = wadExp(wadDiv(qYes, b) - offset);
        int256 expN = wadExp(wadDiv(qNo,  b) - offset);

        return uint256(wadDiv(expY, expY + expN)); // WAD in [0,1e18]
    }

    function priceNo() public view returns (uint256) {
        return 1e18 - priceYes();
    }
}
