// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC6909} from "solmate/tokens/ERC6909.sol";
import {IERC20}  from "forge-std/interfaces/IERC20.sol";

import {ConditionLib} from "./libraries/ConditionLib.sol";
import {PositionLib}  from "./libraries/PositionLib.sol";
import {EventsLib}    from "./libraries/EventsLib.sol";
import {
    ConditionParams, 
    ConditionId,
    QuestionId
} from "./interfaces/IConditionalTokens.sol";

contract ConditionalTokens is ERC6909 {
    using ConditionLib for ConditionParams;

    mapping(ConditionId => bool) public prepared;
    mapping(ConditionId => bool) public resolved;
    mapping(ConditionId => bool) public yesWins;

    function prepare(ConditionParams memory params) external {
        ConditionId conditionId = params.id();
        require(!prepared[conditionId]);
        prepared[conditionId] = true;
        emit EventsLib.Prepare(
            conditionId, 
            params.oracle, 
            params.questionId
        );
    }

    function resolve(
        QuestionId questionId, 
        bool       outcome
    ) external {
        ConditionId conditionId = ConditionParams(
            msg.sender,
            questionId
        ).id();
        require( prepared[conditionId]);
        require(!resolved[conditionId]);

        resolved[conditionId] = true;
        yesWins [conditionId] = outcome;

        emit EventsLib.Resolve(
            conditionId,
            msg.sender,
            questionId,
            outcome
        );
    }

    function split(
        ConditionId conditionId,
        IERC20      collateralToken,
        uint        amount
    ) external {
        require(prepared[conditionId]);
        require(collateralToken.transferFrom(
                msg.sender, 
                address(this), 
                amount
            )
        );

        _mint(msg.sender, PositionLib.yesId(collateralToken, conditionId), amount);
        _mint(msg.sender, PositionLib.noId (collateralToken, conditionId), amount);

        emit EventsLib.Split(
            msg.sender,
            conditionId,
            collateralToken,
            amount
        );
    }

    function merge(
        ConditionId conditionId,
        IERC20      collateralToken,
        uint        amount
    ) external {
        require(prepared[conditionId]);

        _burn(msg.sender, PositionLib.yesId(collateralToken, conditionId), amount);
        _burn(msg.sender, PositionLib.noId (collateralToken, conditionId), amount);

        require(collateralToken.transfer(msg.sender, amount));

        emit EventsLib.Merge(
            msg.sender,
            conditionId,
            collateralToken,
            amount
        );
    }

    function redeem(
        ConditionId conditionId,
        IERC20      collateralToken,
        uint        amount
    ) external {
        require(prepared[conditionId]);
        require(resolved[conditionId]);

        uint winningId = yesWins[conditionId]
            ? PositionLib.yesId(collateralToken, conditionId)
            : PositionLib.noId(collateralToken, conditionId);

        _burn(msg.sender, winningId, amount);

        require(collateralToken.transfer(msg.sender, amount));

        emit EventsLib.Redeem(
            msg.sender,
            conditionId,
            collateralToken,
            amount
        );
    }
}