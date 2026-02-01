# Timeframe Optimization Guide - CSM Backtester
**Date:** February 2, 2026
**Purpose:** Align backtester with live system architecture

---

## 🎯 The Question

**Should CSM_Backtester attach to H1 or M15 chart?**

**Answer:** ✅ **M15 Chart** (for better accuracy and live system alignment)

---

## 📐 Architecture Comparison

### Live System (Current)
```
CSM_AnalysisEA:
  - Chart: H1 (recommended)
  - CSM Calculation: Uses H1 data
  - Update Frequency: Every 60 minutes
  ✅ Matches: Once per H1 bar close

Strategy_AnalysisEA:
  - Chart: M15 (recommended)
  - Indicator Data: Uses H1 data (EMA, ADX, ATR, RSI)
  - Signal Export: Every 15 minutes
  ✅ Matches: Once per M15 bar close
```

### Backtester (Current - NEEDS FIX)
```
CSM_Backtester:
  - Chart: H1 ❌
  - CSM Calculation: Every tick ❌
  - Strategy Evaluation: Every tick ❌
  - Position Management: Every tick ✅

Problems:
1. Recalculates CSM unnecessarily (every tick vs hourly)
2. Evaluates strategies more frequently than live (every tick vs 15 min)
3. Attached to H1 means only 1 evaluation per hour (vs 4 in live)
```

---

## ✅ Recommended Backtester Architecture

### Attach to M15 Chart

**Why?**
1. **Matches execution frequency** - Live system exports signals every 15 minutes
2. **More evaluation points** - 4x more opportunities per hour (vs H1)
3. **Realistic simulation** - Same signal frequency as production
4. **Better entry timing** - Can catch mid-hour signals

### Implementation Pattern

```mql5
//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
datetime lastM15Bar = 0;  // Track M15 bar changes
datetime lastH1Bar = 0;   // Track H1 bar changes

//+------------------------------------------------------------------+
//| Helper: Detect New Bar                                           |
//+------------------------------------------------------------------+
bool isNewBar(ENUM_TIMEFRAMES tf)
{
   datetime currentBar = iTime(_Symbol, tf, 0);

   if (tf == PERIOD_M15 && currentBar != lastM15Bar)
   {
      lastM15Bar = currentBar;
      return true;
   }

   if (tf == PERIOD_H1 && currentBar != lastH1Bar)
   {
      lastH1Bar = currentBar;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| OnTick - Optimized Execution Flow                                |
//+------------------------------------------------------------------+
void OnTick()
{
   //═══════════════════════════════════════════════════════════════
   // STEP 1: Check for M15 new bar (signal evaluation)
   //═══════════════════════════════════════════════════════════════
   if (isNewBar(PERIOD_M15))
   {
      //────────────────────────────────────────────────────────────
      // STEP 2: Update CSM only on H1 bar close (expensive operation)
      //────────────────────────────────────────────────────────────
      if (isNewBar(PERIOD_H1))
      {
         CalculateCSM();  // 9 currencies + synthetic Gold pairs

         if (VerboseLogging)
            Print("CSM Updated (H1 bar close)");
      }

      //────────────────────────────────────────────────────────────
      // STEP 3: Evaluate strategies every M15 bar
      //────────────────────────────────────────────────────────────
      EvaluateStrategies();  // TrendRider/RangeRider analysis

      if (VerboseLogging)
         Print("Strategies Evaluated (M15 bar close)");
   }

   //═══════════════════════════════════════════════════════════════
   // STEP 4: Manage open positions on every tick (precise execution)
   //═══════════════════════════════════════════════════════════════
   ManagePositions();  // Trailing stops, SL/TP updates
}
```

---

## 📊 Comparison: H1 vs M15 Chart

| Aspect | H1 Chart | M15 Chart (Recommended) |
|--------|----------|-------------------------|
| **CSM Updates** | Every H1 bar (✅ correct) | Every H1 bar (✅ correct) |
| **Signal Evaluations** | 1x per hour | **4x per hour** (matches live) |
| **Entry Timing** | Hour close only | Every 15 min (better fills) |
| **Live System Match** | ❌ No (1 vs 4 evals) | ✅ Yes (4 vs 4 evals) |
| **CPU Efficiency** | Same (H1 CSM) | Same (H1 CSM) |
| **Backtest Accuracy** | Lower (misses signals) | **Higher (realistic)** |

---

## 🔧 Implementation Checklist

### Priority 0: Timeframe Optimization (FOUNDATIONAL)
- [ ] Add `isNewBar()` helper function
  - Tracks last bar time for PERIOD_M15
  - Tracks last bar time for PERIOD_H1
  - Returns true only when bar changes

- [ ] Refactor `OnTick()` logic
  - Move CSM calculation inside `if (isNewBar(PERIOD_H1))`
  - Move strategy evaluation inside `if (isNewBar(PERIOD_M15))`
  - Keep position management outside (every tick)

- [ ] Update MT5 tester settings
  - Change chart timeframe from H1 → M15
  - Keep "Every tick" mode (for position management)
  - Verify CSM updates only 24 times per day (H1)
  - Verify strategy evaluations 96 times per day (M15)

- [ ] Add logging to verify behavior
  ```mql5
  // CSM calculation
  Print("CSM Updated at ", TimeToString(TimeCurrent()));

  // Strategy evaluation
  Print("Strategy Evaluated at ", TimeToString(TimeCurrent()));
  ```

---

## 💡 Why This Matters

### Current H1 Approach Problems

**Example Scenario:**
- Time: 10:45 (mid-hour)
- CSM shows strong USD trend
- Strategy confidence hits 95% (strong signal)
- **H1 Backtester:** Ignores signal (waits until 11:00)
- **M15 Backtester:** Takes trade at 10:45 ✅
- **Live System:** Takes trade at 10:45 ✅

**Result:**
- H1 backtest misses 15-45 minute head start
- Performance metrics don't match live trading
- False sense of system behavior

### M15 Approach Benefits

1. **Realistic Entry Timing**
   - Catches signals as they appear (every 15 min)
   - Matches live system behavior exactly
   - Better fill prices

2. **Accurate Performance Metrics**
   - Same number of trades as live
   - Same entry/exit timing
   - Realistic drawdown/profit curves

3. **Efficient Resource Usage**
   - CSM still calculates once per hour (H1 data)
   - Only strategy evaluation increases (acceptable cost)
   - Position management unchanged

---

## 🎯 Summary

**Recommendation:** Attach CSM_Backtester to **M15 chart**

**Changes Required:**
1. Add `isNewBar()` function
2. Wrap CSM calculation in `if (isNewBar(PERIOD_H1))`
3. Wrap strategy evaluation in `if (isNewBar(PERIOD_M15))`
4. Keep position management on every tick

**Benefits:**
- ✅ Matches live system (15-min signal frequency)
- ✅ More accurate backtests (4x evaluation points)
- ✅ Better entry timing (mid-hour signals)
- ✅ Same CPU efficiency (H1 CSM calculation)

**This is a foundational fix that should be implemented before SL/TP optimization.**

---

*Guide created: February 2, 2026*
*Related: BACKTEST_FINDINGS_2026-02-01.md*
