# Future Enhancements - JcampForexTrader

## Session 20 - Identified Improvements

### 1. RangeRider: Buffer Zones for Range Detection

**Issue:** RANGING regime often shows "No active range detected"

**Current Behavior:**
- RangeRider requires perfect range conditions
- If no clear range exists, strategy returns HOLD
- May miss valid range trading opportunities

**Proposed Solution:**
- Add buffer zones for range detection
- Allow range trading when conditions are "close enough"
- Reference: Check `Reference/Jcamp_BacktestEA.mq5` for buffer zone logic

**Implementation Ideas:**
1. **Range Width Buffer:**
   - Current: Requires exact range width (e.g., 30-80 pips)
   - Proposed: Allow ±10% tolerance (27-88 pips acceptable)

2. **S/R Level Buffer:**
   - Current: Price must be AT support/resistance
   - Proposed: Allow ±5 pips from S/R level

3. **Regime Threshold Buffer:**
   - Current: Hard cutoffs for RANGING classification
   - Proposed: Transition zone (e.g., 35-45% = "weak range")

**Expected Benefits:**
- Higher RangeRider execution rate
- Better utilization of range market conditions
- Smoother transitions between regimes

**Priority:** Medium (after Session 21-23 completion)

**Reference File:** `Reference/Jcamp_BacktestEA.mq5` lines ~3500-4000 (range detection logic)

---

## Other Future Enhancements

### 2. Dynamic Pending Order Thresholds
- Make `maxSwingDistancePips` (30 pips) adaptive based on volatility
- High volatility (ATR > 50) → Allow 50+ pips
- Low volatility (ATR < 20) → Restrict to 20 pips

### 3. Multi-Timeframe Swing Detection
- Current: Uses H1 only
- Proposed: Check H1, H4, Daily for stronger swing levels
- Confluence = higher confidence pending orders

### 4. Pending Order Priority System
- If both retracement + breakout valid, choose better one
- Prioritize based on:
  - Distance to level (closer = better)
  - Regime alignment (trending = breakout, ranging = retracement)
  - Historical success rate per strategy

---

*Created: Session 20*
*Last Updated: February 13, 2026*
