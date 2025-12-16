// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Owned}  from "solmate/auth/Owned.sol";

import {PositionLib}       from "./libraries/PositionLib.sol";
import {ConditionalTokens} from "./ConditionalTokens.sol";
import {ConditionId}       from "./interfaces/IConditionalTokens.sol";

// TODO: function to seed
abstract contract MarketMaker is Owned(msg.sender) {
    ConditionalTokens public conditionalTokens;
    IERC20            public collateralToken;
    uint              public fee;
    ConditionId       public conditionId;
    uint              public accumulatedFees;
    int               public qYes;
    int               public qNo;
    uint              public bank;

    constructor(
        ConditionalTokens _conditionalTokens,
        IERC20            _collateralToken,
        ConditionId       _conditionId
    ) {
        conditionalTokens = _conditionalTokens;
        collateralToken   = _collateralToken;
        conditionId       = _conditionId;
    }

    function addFunding(uint amount) 
        external 
        onlyOwner
    {
        require(amount > 0);
        collateralToken.transferFrom(msg.sender, address(this), amount);
        collateralToken.approve(address(conditionalTokens), amount);
        conditionalTokens.split(conditionId, collateralToken, amount);
        bank += amount;
    }

    function removeFunding(uint amount) 
        external 
        onlyOwner
    {
        require(amount > 0);
        require(amount <= bank);
        
        conditionalTokens.merge(conditionId, collateralToken, amount);
        bank -= amount;
        collateralToken.transfer(msg.sender, amount);
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
        
        qYes += int(amount);
        
        collateralToken.transferFrom(msg.sender, address(this), cost);
        collateralToken.approve(address(conditionalTokens), uint(netCost));
        conditionalTokens.split(conditionId, collateralToken, uint(netCost));
        conditionalTokens.transfer(
            msg.sender,
            PositionLib.yesId(collateralToken, conditionId),
            amount
        );
        bank += uint(netCost);
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
        
        qNo += int(amount);
        
        collateralToken.transferFrom(msg.sender, address(this), cost);
        collateralToken.approve(address(conditionalTokens), uint(netCost));
        conditionalTokens.split(conditionId, collateralToken, uint(netCost));
        conditionalTokens.transfer(
            msg.sender,
            PositionLib.noId(collateralToken, conditionId),
            amount
        );
        bank += uint(netCost);
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
        
        qYes -= int(amount);
        
        conditionalTokens.transferFrom(
            msg.sender,
            address(this), 
            PositionLib.yesId(collateralToken, conditionId), 
            amount
        );
        conditionalTokens.merge(conditionId, collateralToken, uint(-netCost));
        collateralToken.transfer(msg.sender, payout);
        bank -= uint(-netCost);
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
        
        qNo -= int(amount);
        
        conditionalTokens.transferFrom(
            msg.sender, 
            address(this), 
            PositionLib.noId(collateralToken, conditionId), 
            amount
        );
        conditionalTokens.merge(conditionId, collateralToken, uint(-netCost));
        collateralToken.transfer(msg.sender, payout);
        bank -= uint(-netCost);
    }

    function setFee(uint _fee) 
        external 
        onlyOwner 
    {
        require(_fee <= 0.1e18); // max 10%
        fee = _fee;
    }

    function claimFees() 
        external 
        onlyOwner 
    {
        uint amount = accumulatedFees;
        accumulatedFees = 0;
        collateralToken.transfer(owner, amount);
    }

    function _addFee(uint amount)
        internal
        returns (uint)
    {
        uint feeAmount = amount * fee / 1e18;
        accumulatedFees += feeAmount;
        return amount + feeAmount;
    }

    function _subFee(uint amount)
        internal
        returns (uint)
    {
        uint feeAmount = amount * fee / 1e18;
        accumulatedFees += feeAmount;
        return amount - feeAmount;
    }

    function calcNetCost(int yesAmount, int noAmount) public view virtual returns (int netCost);
}