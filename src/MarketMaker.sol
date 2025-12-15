// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Owned}  from "solmate/auth/Owned.sol";

import {ConditionalTokens} from "./ConditionalTokens.sol";
import {Stage} from "./interfaces/IMarketMaker.sol";

contract MarketMaker is Owned(msg.sender) {
    ConditionalTokens public conditionalTokens;
    IERC20            public collateralToken;
    uint              public fee;
    uint              public funding;

    function changeFunding(uint fundingChange) 
        public 
    {

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