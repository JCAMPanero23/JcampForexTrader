# Backtest Findings - February 1, 2026

**Session:** CSM_Backtester Initial Testing
**Status:** ✅ Trades executing after regime detection fix
**Tester:** User
**Symbols Tested:** EURUSD, GBPUSD on H1

---

## 🎉 SUCCESS: Bug Fixed!

### Critical Bug Resolved
**Issue:** Regime was always TRANSITIONAL → No trades executing
**Root Cause:** DetectMarketRegime() called with wrong parameters
- Was passing: `(symbol, PERIOD_H1, verbose)` where PERIOD_H1 = 16385
- Should be: `(symbol, trendingThreshold, rangingThreshold, minADX, verbose)`
- PERIOD_H1 enum value was treated as threshold → impossibly high → always TRANSITIONAL

**Fix Applied:**
```mql5
// Before (WRONG):
currentRegime = DetectMarketRegime(currentSymbol, PERIOD_H1, VerboseLogging);

// After (CORRECT):
currentRegime = DetectMarketRegime(currentSymbol, TrendingThreshold, RangingThreshold, MinADXForTrending, VerboseLogging);
```

**New Inputs Added:**
- TrendingThreshold: 55.0%
- RangingThreshold: 40.0%
- MinADXForTrending: 20.0 (lowered from 30.0 for better sensitivity)

**Result:** Regime detection now works → TrendRider executes → **TRADES HAPPENING!** ✅

---

## ⚠️ ISSUES FOUND (To Fix Next Session)

### 1. No Trade Cooldown
**Observed Behavior:**
- When a trade closes, EA immediately opens another trade
- No minimum time gap between consecutive trades

**Current Code:**
```mql5
// Prevent rapid-fire trades (min 1 hour between trades)
if(TimeCurrent() - lastTradeTime < 3600)
   return;
```

**Problem:**
- Cooldown exists in code but may not be working correctly
- Need to verify `lastTradeTime` is being updated on trade close (not just trade open)

**Recommendation:**
- Add cooldown after trade CLOSE, not just trade OPEN
- Consider separate cooldowns for wins vs losses (e.g., 1 hour after win, 30 min after loss)

---

### 2. Stop Loss Too Aggressive
**Observed Behavior:**
- SL movement happens too quickly
- Doesn't allow room for normal price retracement
- Positions getting stopped out prematurely

**Current Implementation:**
```mql5
// Fixed SL/TP
- Forex: 50 pips SL, 100 pips TP (1:2 RR)
- Gold: $50 SL, $100 TP

// Trailing Stop
- Starts after 30 pips profit
- Trails by 20 pips
```

**Problem:**
- Fixed SL doesn't adapt to volatility
- Trailing stop starts too early (30 pips) and is too tight (20 pips)
- Should follow OLD BacktestEA behavior (9,063 lines reference file)

**Recommendation:**
- Use **ATR-based SL** instead of fixed pips
  - Example: SL = 2.5 * ATR(14)
  - Adapts to market volatility automatically
- Delay trailing stop start:
  - Start trailing after 1.5x SL distance (not fixed 30 pips)
  - Trail at 0.5x ATR (tighter as price moves in favor)
- Reference: `Reference/Jcamp_BacktestEA.mq5` lines 4500-4800 (ATR-based risk management)

---

### 3. Take Profit is Fixed (Not Dynamic)
**Observed Behavior:**
- TP always at 100 pips (forex) or $100 (gold)
- Doesn't adapt to trend strength or volatility
- May be exiting too early in strong trends or too late in weak trends

**Current Implementation:**
```mql5
double tpDistance = 100.0 * pipSize;  // Always 100 pips
```

**Problem:**
- Fixed TP misses opportunity in strong trends
- Holds too long in weak trends (should exit earlier)
- No dynamic adjustment based on market conditions

**Recommendation Options:**

**Option A: ATR-Based TP (Conservative)**
```mql5
double atr = GetATR(symbol, PERIOD_H1, 14);
double tp = entry + (4.0 * atr);  // 4x ATR target (adapts to volatility)
```

**Option B: Multiple TP Levels (Scalp + Runner)**
```mql5
// Partial close strategy:
- Close 50% at 1.5x SL (lock profit)
- Close 30% at 3x SL (target)
- Leave 20% as runner (trail until stopped)
```

**Option C: Indicator-Based TP (Advanced)**
Use proven indicators to set dynamic TP:
- **Bollinger Bands:** TP at upper/lower band (2 StdDev)
- **Fibonacci Extensions:** TP at 1.618 extension level
- **ATR Channels:** TP at outer channel boundary
- **Parabolic SAR:** TP when SAR flips

**Suggestion:**
- Use **forex-trading-analyst skill** to research best TP method
- Analyze which indicators correlate best with optimal exit points
- Consider combining ATR (for volatility) + Bollinger Bands (for extremes)

---

## 📊 Performance Observations

**Positive:**
- ✅ Trades executing (regime detection fixed)
- ✅ CSM integration working
- ✅ TrendRider strategy analyzing correctly
- ✅ Risk management calculating position sizes

**Issues:**
- ❌ Too aggressive SL (premature exits)
- ❌ Fixed TP (missing profit opportunities)
- ❌ Rapid re-entry (no proper cooldown)

**Net Effect:**
- Likely break-even or slight loss due to:
  - Getting stopped out by normal retracements (tight SL)
  - Re-entering immediately after stop-out (revenge trading pattern)
  - Missing extended moves (fixed TP)

---

## 🔧 Action Items for Next Session

### Priority 1: Fix Stop Loss (CRITICAL)
- [ ] Implement ATR-based SL (replaces fixed 50 pips)
- [ ] Review OLD BacktestEA SL logic (lines 4500-4800)
- [ ] Add minimum SL (e.g., never less than 30 pips)
- [ ] Test: SL = entry ± (2.5 * ATR) for adaptive stops

### Priority 2: Implement Dynamic Take Profit
- [ ] Research best TP method using forex-trading-analyst skill
- [ ] Compare: ATR-based vs Bollinger Bands vs Multiple TPs
- [ ] Implement chosen method
- [ ] Backtest comparison: Fixed TP vs Dynamic TP

### Priority 3: Fix Trade Cooldown
- [ ] Verify lastTradeTime updates on trade close
- [ ] Add post-trade cooldown (separate from pre-trade throttle)
- [ ] Consider: 1 hour after win, 2 hours after loss (prevent revenge trading)

### Priority 4: Backtest Validation
- [ ] Run 1-year backtest on all 4 assets (EURUSD, GBPUSD, AUDJPY, XAUUSD)
- [ ] Compare results: Current vs OLD BacktestEA
- [ ] Target metrics:
  - Profit Factor > 1.5
  - Win Rate > 50%
  - Max Drawdown < 20%
  - Sharpe Ratio > 1.0

---

## 📚 Reference Materials

**OLD BacktestEA Analysis:**
- File: `Reference/Jcamp_BacktestEA.mq5` (9,063 lines)
- Key sections:
  - Lines 4500-4800: ATR-based risk management
  - Lines 5200-5600: Dynamic TP calculation
  - Lines 6100-6400: Trade cooldown & re-entry logic

**Strategy Modules:**
- TrendRiderStrategy: Uses 135-point confidence system (working ✅)
- RangeRiderStrategy: Requires range detection (disabled for now)
- RegimeDetector: Now working correctly after bug fix ✅

**Forex Trading Analyst Skill:**
- Use for: Researching optimal TP indicators
- Questions to ask:
  - "Which indicator best predicts profit target in trending markets?"
  - "Compare ATR vs Bollinger Bands for dynamic TP"
  - "What's the optimal SL multiplier for H1 forex trading?"

---

## 💡 Additional Observations

**CSM Display (Chart):**
- ✅ Shows in top-left corner
- ✅ Updates regime status
- ✅ Shows signal confidence
- ✅ Helps visualize EA decisions

**Verbose Logging:**
- ✅ Shows regime changes
- ✅ Shows strategy analysis
- ✅ Shows why trades rejected
- ⚠️ Can be overwhelming - consider throttling to key events only

**Symbol-Specific Behavior:**
- EURUSD: Good trend detection
- GBPUSD: More volatile - needs wider SL
- AUDJPY: Risk gauge - clean trends expected
- XAUUSD: Gold - separate analysis needed (TrendRider only)

---

## 🎯 Success Criteria for Next Session

1. **ATR-based SL implemented** → Fewer premature stop-outs
2. **Dynamic TP implemented** → Better profit capture
3. **Cooldown fixed** → No rapid re-entry
4. **1-year backtest complete** → Validation metrics achieved

**Target Performance:**
- Profit Factor: > 1.5
- Win Rate: > 50%
- Max Drawdown: < 20%
- Total Trades: > 50 (1 year)

---

**Status:** Ready for next session improvements
**Next Steps:** Implement ATR-based SL/TP + fix cooldown
**Expected Impact:** Significantly improved backtest performance

---

*Document created: February 1, 2026*
*Backtester Version: 2.00*
*Last Commit: 959e312 (regime detection fix)*
