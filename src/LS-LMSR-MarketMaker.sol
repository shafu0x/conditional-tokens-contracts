// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC6909}                       from "solmate/tokens/ERC6909.sol";
import {Owned}                         from "solmate/auth/Owned.sol";
import {SafeTransferLib}               from "solmate/utils/SafeTransferLib.sol";
import {wadExp, wadLn, wadMul, wadDiv} from "solmate/utils/SignedWadMath.sol";
import {ERC20}                         from "solmate/tokens/ERC20.sol";

/// - Mints its own YES/NO IOU shares (ERC6909 ids 1 and 2)
/// - Holds collateral in `bank`
/// - After resolve(), winning shares redeem 1:1 for collateral from `bank`
contract LS_LMSR_MarketMaker is ERC6909, Owned(msg.sender) {
    using SafeTransferLib for ERC20;

    uint256 internal constant YES_ID = 1;
    uint256 internal constant NO_ID  = 2;

    ERC20 public immutable collateral;

    // Simple oracle
    address public oracle;
    uint64  public resolveAfter; // 0 = anytime
    bool    public resolved;
    bool    public yesWon;

    // Fees
    uint256 public fee;             // WAD (1e18 = 100%)
    uint256 public accumulatedFees; // collateral units

    // Backing
    uint256 public bank; // collateral reserved to back the curve + redemptions

    // Outstanding shares (also equals total supply per id, unless you change mint/burn logic)
    uint256 public qYes;
    uint256 public qNo;

    // Liquidity parameter: b = b0 + alphaWad * bank / 1e18
    uint256 public alphaWad; // WAD multiplier
    uint256 public b0;       // must be > 0

    modifier onlyOracle() {
        require(msg.sender == oracle);
        _;
    }

    constructor(
        ERC20   _collateral,
        address _oracle,
        uint64  _resolveAfter,
        uint256 _alphaWad,
        uint256 _b0
    ) {
        require(_b0 > 0);
        require(_oracle != address(0));
        require(_collateral.decimals() == 18);

        collateral   = _collateral;
        oracle       = _oracle;
        resolveAfter = _resolveAfter;
        alphaWad     = _alphaWad;
        b0           = _b0;
    }

    // ─────────────────────────────────────────────────────────────
    // ORACLE
    // ─────────────────────────────────────────────────────────────

    function resolve(bool _yesWon) external onlyOracle {
        require(!resolved);
        if (resolveAfter != 0) require(block.timestamp >= resolveAfter);

        resolved = true;
        yesWon   = _yesWon;

    }

    function setOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0));
        oracle = _oracle;
    }

    function setResolveAfter(uint64 _resolveAfter) external onlyOwner {
        resolveAfter = _resolveAfter;
    }

    // ─────────────────────────────────────────────────────────────
    // FUNDING (explicit subsidy / bootstrap)
    // ─────────────────────────────────────────────────────────────

    function addFunding(uint256 amount) external onlyOwner {
        require(amount > 0);
        collateral.safeTransferFrom(msg.sender, address(this), amount);
        bank += amount;
    }

    /// @notice Conservative: only allow removing funding when unresolved and no open interest.
    function removeFunding(uint256 amount) external onlyOwner {
        require(!resolved);
        require(qYes == 0 && qNo == 0);
        require(amount > 0);
        require(amount <= bank);

        bank -= amount;
        collateral.safeTransfer(msg.sender, amount);
    }

    // ─────────────────────────────────────────────────────────────
    // TRADING
    // ─────────────────────────────────────────────────────────────

    function buyYes(uint256 amount, uint256 maxCost) external returns (uint256 cost) {
        require(!resolved);
        require(amount > 0);

        int256 netCost = calcNetCost(int256(amount), 0);
        require(netCost > 0);

        cost = _addFee(uint256(netCost));
        require(cost <= maxCost);

        collateral.safeTransferFrom(msg.sender, address(this), cost);

        qYes += amount;
        bank += uint256(netCost);

        _mint(msg.sender, YES_ID, amount);
    }

    function buyNo(uint256 amount, uint256 maxCost) external returns (uint256 cost) {
        require(!resolved);
        require(amount > 0);

        int256 netCost = calcNetCost(0, int256(amount));
        require(netCost > 0);

        cost = _addFee(uint256(netCost));
        require(cost <= maxCost);

        collateral.safeTransferFrom(msg.sender, address(this), cost);

        qNo += amount;
        bank += uint256(netCost);

        _mint(msg.sender, NO_ID, amount);
    }

    function sellYes(uint256 amount, uint256 minPayout) external returns (uint256 payout) {
        require(!resolved);
        require(amount > 0);

        int256 netCost = calcNetCost(-int256(amount), 0);
        require(netCost < 0);

        uint256 gross = uint256(-netCost);
        require(gross <= bank);

        payout = _subFee(gross);
        require(payout >= minPayout);

        _burn(msg.sender, YES_ID, amount);

        qYes -= amount;
        bank -= gross;

        collateral.safeTransfer(msg.sender, payout);
    }

    function sellNo(uint256 amount, uint256 minPayout) external returns (uint256 payout) {
        require(!resolved);
        require(amount > 0);

        int256 netCost = calcNetCost(0, -int256(amount));
        require(netCost < 0);

        uint256 gross = uint256(-netCost);
        require(gross <= bank);

        payout = _subFee(gross);
        require(payout >= minPayout);

        _burn(msg.sender, NO_ID, amount);

        qNo -= amount;
        bank -= gross;

        collateral.safeTransfer(msg.sender, payout);
    }

    // ─────────────────────────────────────────────────────────────
    // SETTLEMENT
    // ─────────────────────────────────────────────────────────────

    function redeem(uint256 amount) external returns (uint256 payout) {
        require(resolved);
        require(amount > 0);
        require(amount <= bank);

        uint256 winId = yesWon ? YES_ID : NO_ID;

        _burn(msg.sender, winId, amount);

        // Decrease open interest for cleanliness
        if (yesWon) qYes -= amount;
        else        qNo  -= amount;

        bank   -= amount;
        payout  = amount;

        collateral.safeTransfer(msg.sender, payout);
    }

    // ─────────────────────────────────────────────────────────────
    // PRICING (LMSR with liquidity b(bank))
    // ─────────────────────────────────────────────────────────────

    function b() public view returns (uint256) {
        return b0 + (alphaWad * bank) / 1e18;
    }

    function calcNetCost(int256 yesAmount, int256 noAmount) public view returns (int256) {
        int256 b_ = int256(b());

        int256 qY = int256(qYes);
        int256 qN = int256(qNo);

        int256 beforeC = _cost(qY, qN, b_);
        int256 afterC  = _cost(qY + yesAmount, qN + noAmount, b_);
        return afterC - beforeC;
    }

    function priceYes() public view returns (uint256) {
        int256 b_ = int256(b());
        int256 qY = int256(qYes);
        int256 qN = int256(qNo);

        int256 maxQ   = qY > qN ? qY : qN;
        int256 offset = wadDiv(maxQ, b_);

        int256 expY = wadExp(wadDiv(qY, b_) - offset);
        int256 expN = wadExp(wadDiv(qN, b_) - offset);

        return uint256(wadDiv(expY, expY + expN)); // WAD in [0, 1e18]
    }

    function priceNo() public view returns (uint256) {
        return 1e18 - priceYes();
    }

    function _cost(int256 qY, int256 qN, int256 b_) internal pure returns (int256) {
        int256 maxQ   = qY > qN ? qY : qN;
        int256 offset = wadDiv(maxQ, b_);

        int256 expY = wadExp(wadDiv(qY, b_) - offset);
        int256 expN = wadExp(wadDiv(qN, b_) - offset);

        return wadMul(b_, wadLn(expY + expN) + offset);
    }

    // ─────────────────────────────────────────────────────────────
    // FEES
    // ─────────────────────────────────────────────────────────────

    function setFee(uint256 _fee) external onlyOwner {
        require(_fee <= 0.1e18);
        fee = _fee;
    }

    /// @notice Claim fees (kept out of `bank`) after resolution for safety.
    function claimFees() external onlyOwner {
        require(resolved);
        uint256 amount = accumulatedFees;
        accumulatedFees = 0;

        // Ensure we never dip into bank
        uint256 freeBal = collateral.balanceOf(address(this)) - bank;
        require(amount <= freeBal);

        collateral.safeTransfer(owner, amount);
    }

    function _addFee(uint256 amount) internal returns (uint256) {
        uint256 feeAmount = amount * fee / 1e18;
        accumulatedFees += feeAmount;
        return amount + feeAmount;
    }

    function _subFee(uint256 amount) internal returns (uint256) {
        uint256 feeAmount = amount * fee / 1e18;
        accumulatedFees += feeAmount;
        return amount - feeAmount;
    }
}
