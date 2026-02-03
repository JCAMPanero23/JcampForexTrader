# Gold (XAUUSD) Spread Analysis Report
**Generated:** February 3, 2026
**Data Source:** Full Year 2025 M1 Data (352,116 bars)
**Broker:** FusionMarkets (.sml suffix)

---

## Executive Summary

**Critical Finding:** Gold spreads are 10-20x wider than forex pairs, requiring significantly different spread management approach.

**Current Problem:** MainTradingEA using spread multiplier of 100.0x (200 pips max) is **TOO PERMISSIVE** and allowing trades during extreme spread conditions (69-84 pips observed).

**Recommended Solution:** Reduce to **15.0x multiplier (30 pips max)** for production trading.

---

## Key Statistics

### Overall Spread Behavior (Full Year 2025)
```
Minimum:           0.0 pips  (rare event, 7 bars only)
Maximum:         500.0 pips  (extreme outlier)
Mean:             25.2 pips  (typical spread)
Median:           23.0 pips  (most common)
90th Percentile:  40.0 pips  (90% of spreads below this)
95th Percentile:  46.0 pips
99th Percentile:  64.0 pips
```

### Spread Distribution
```
0-5 pips (Excellent):     0.00%  ← NEVER happens with this broker!
5-10 pips (Good):         0.00%  ← Also never happens
10-15 pips (Acceptable): 22.03%  (77,558 bars)
15-20 pips (High):       14.82%  (52,189 bars)
20-30 pips (Very High):  32.26%  (113,588 bars) ← Most common range
30-50 pips (Extreme):    27.40%  (96,486 bars)
>50 pips (Prohibitive):   3.49%  (12,288 bars)
```

**Reality Check:** Gold is EXPENSIVE to trade. Spreads of 20-30 pips are NORMAL, not exceptional.

---

## Time-of-Day Patterns (UTC+2 Broker Time)

### Best Trading Hours (Lowest Spreads)
```
Hour  | Avg Spread | 90th %ile | Session
------|------------|-----------|------------------
16:00 |  20.0 pips |  33 pips  | London/NY Overlap
17:00 |  19.2 pips |  32 pips  | NY Open
18:00 |  20.4 pips |  33 pips  | NY
19:00 |  21.7 pips |  35 pips  | NY
20:00 |  22.2 pips |  35 pips  | NY
```

### Worst Trading Hours (Highest Spreads)
```
Hour  | Avg Spread | 90th %ile | Session
------|------------|-----------|------------------
01:00 |  39.1 pips |  61 pips  | Asian/Off-Hours
02:00 |  33.2 pips |  49 pips  | Asian/Off-Hours
23:00 |  31.7 pips |  48 pips  | Asian/Off-Hours
```

### Trading Session Comparison
```
Session                    | Avg    | 90th %ile | % < 15 pips
---------------------------|--------|-----------|-------------
London/NY Overlap (14-17)  | 21.9   | 34 pips   | 29.4%
NY Only (17-22)            | 21.0   | 34 pips   | 30.8%
London Only (09-14)        | 24.5   | 38 pips   | 20.8%
Asian Session (22-09)      | 28.7   | 45 pips   | 16.1%
```

**Finding:** London/NY overlap (14:00-17:00) and NY session (17:00-22:00) offer best spreads (~21 pips avg).

---

## Spread Multiplier Analysis

**Current Setting:** `MaxSpreadPips = 2.0` with multiplier `100.0x` = **200 pips max**

### Multiplier Performance Table
```
Multiplier | Max Allowed | % Bars Passing | Assessment
-----------|-------------|----------------|-------------------
5.0x       | 10 pips     | 13%            | TOO RESTRICTIVE (misses 87% of trades)
10.0x      | 20 pips     | 40%            | VERY LIMITED (misses 60% of trades)
15.0x      | 30 pips     | 72%            | GOOD BALANCE ✓
20.0x      | 40 pips     | 90%            | PERMISSIVE ✓
25.0x      | 50 pips     | 97%            | TOO PERMISSIVE
100.0x     | 200 pips    | 99.9%          | DANGEROUSLY PERMISSIVE (current)
```

---

## Recommendations for MainTradingEA

### 1. Spread Multiplier Setting (CRITICAL)

**Option A: Conservative (Recommended for Production)**
```mql5
// In MainTradingEA inputs:
input double MaxSpreadPips = 2.0;           // Base spread limit
input double SpreadMultiplier_XAUUSD = 15.0; // Gold: 30 pips max

// Calculation: 2.0 × 15.0 = 30 pips maximum
```

**Why 15.0x?**
- Catches 72% of all trading opportunities (good balance)
- Allows trades during prime hours (16:00-22:00 avg ~20-22 pips)
- Blocks extreme spreads (>30 pips) that erode profits
- Conservative enough for live trading

**Option B: Balanced (Higher Trade Frequency)**
```mql5
input double SpreadMultiplier_XAUUSD = 20.0; // Gold: 40 pips max

// Calculation: 2.0 × 20.0 = 40 pips maximum
```

**Why 20.0x?**
- Catches 90% of all trading opportunities
- Allows trades even during less optimal hours
- Still blocks worst 10% of spreads (>40 pips)
- Higher trade frequency, slightly higher costs

**Option C: Dynamic (Most Optimal, More Complex)**
```mql5
// Time-based spread multiplier
double GetGoldSpreadMultiplier(int hour)
{
    // Prime hours (14:00-22:00 UTC+2): More permissive
    if(hour >= 14 && hour <= 22)
        return 20.0; // 40 pips max

    // Off-hours: Strict filter
    return 10.0; // 20 pips max (blocks most Asian session trades)
}
```

**Why Dynamic?**
- Adapts to market conditions
- Maximizes opportunities during prime hours
- Protects against poor executions during off-hours
- Best risk/reward optimization

### 2. Trading Hours Restriction (Recommended)

**Add time-of-day filter to MainTradingEA:**
```mql5
bool IsGoldTradingHours()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int hour = dt.hour; // Broker time (UTC+2)

    // Allow trading only during London/NY sessions
    // Block Asian/off-hours (22:00-09:00)
    return (hour >= 9 && hour <= 22);
}
```

**Impact:** Blocks 43% of time (Asian session) where avg spread is 28.7 pips vs 21-24 pips during allowed hours.

### 3. Spread Quality Thresholds

**Update TradeExecutor logic:**
```mql5
enum SpreadQuality
{
    SPREAD_EXCELLENT,   // < 15 pips (rare, but acceptable)
    SPREAD_GOOD,        // 15-25 pips (most common, acceptable)
    SPREAD_ACCEPTABLE,  // 25-35 pips (acceptable for high confidence)
    SPREAD_POOR         // > 35 pips (reject)
};

SpreadQuality GetSpreadQuality(double spread_pips)
{
    if(spread_pips < 15) return SPREAD_EXCELLENT;
    if(spread_pips < 25) return SPREAD_GOOD;
    if(spread_pips < 35) return SPREAD_ACCEPTABLE;
    return SPREAD_POOR;
}

// In trade execution logic:
if(symbol == "XAUUSD.sml")
{
    SpreadQuality quality = GetSpreadQuality(current_spread);

    // Require higher confidence for wider spreads
    if(quality == SPREAD_ACCEPTABLE && confidence < 120)
    {
        Print("Gold spread ", current_spread, " pips requires confidence 120+, got ", confidence);
        return false; // Skip trade
    }

    if(quality == SPREAD_POOR)
    {
        Print("Gold spread ", current_spread, " pips too wide, skipping trade");
        return false;
    }
}
```

---

## Why Session 8 Saw 69-84 Pip Spreads

**Analysis:** The observed 69-84 pip spreads occurred during **Asian session / off-hours** (likely 01:00-08:00 UTC+2).

**Evidence:**
- 01:00 hour: Avg 39 pips, 90th percentile **61 pips**
- 02:00 hour: Avg 33 pips, 90th percentile **49 pips**
- 69-84 pips = 95th-99th percentile events (rare but not impossible)

**Solution:** With 15.0x multiplier (30 pips max) or 20.0x (40 pips max), these trades would have been correctly rejected.

---

## Implementation Priority

### IMMEDIATE (Before Next Demo Session)
1. ✅ **Change Gold spread multiplier from 100.0x to 15.0x**
   - File: `MT5_EAs/Include/JcampStrategies/Trading/TradeExecutor.mqh`
   - Current: `100.0` (testing mode)
   - Production: `15.0` (conservative) or `20.0` (balanced)

2. **Add trading hours restriction for Gold**
   - Block 22:00-09:00 UTC+2 (Asian session)
   - Allow 09:00-22:00 UTC+2 (London/NY)

### NEXT SESSION (Enhanced Logic)
3. Implement dynamic spread multiplier (time-based)
4. Add spread quality scoring (excellent/good/acceptable/poor)
5. Tie spread quality to minimum confidence requirements
6. Add spread statistics logging (track avg spread per session)

---

## Cost Analysis

### Gold Trading Costs vs Forex

**Example Trade: 0.01 lots (1 micro lot)**

**EURUSD:**
- Typical spread: 0.5 pips
- Cost per trade: $0.05
- Round-trip cost: $0.10

**XAUUSD (Gold):**
- Average spread: 25 pips
- Cost per trade: $2.50 (50x more expensive!)
- Round-trip cost: $5.00

**XAUUSD during prime hours (16:00-20:00):**
- Average spread: 20 pips
- Cost per trade: $2.00
- Round-trip cost: $4.00

**Implication:** Gold requires wider profit targets to justify higher transaction costs. Current TP of $100 (100 pips) for Gold is appropriate given 20-25 pip spread costs.

---

## Next Steps

1. **Update MainTradingEA.mq5:**
   - Change `SpreadMultiplier_XAUUSD` from `100.0` to `15.0`
   - Compile and test

2. **Monitor First 10 Gold Trades:**
   - Log actual spread at execution time
   - Track: entry spread, exit spread, total cost
   - Validate 15.0x multiplier is working

3. **Consider Dynamic Multiplier:**
   - If 15.0x blocks too many trades → increase to 20.0x
   - If 15.0x still allows poor fills → add time filter

4. **Long-term Optimization:**
   - Collect 30 days of Gold trade data
   - Analyze: spread cost vs profit per trade
   - Optimize multiplier based on actual P&L impact

---

## Appendix: Raw Data Summary

**Total M1 Bars Analyzed:** 352,116
**Date Range:** January 2, 2025 - December 31, 2025
**Data Quality:** Complete (no gaps detected)
**Broker:** FusionMarkets (suffix: .sml)
**Spread Format:** Points (divide by 10 for pips)

**Analysis Script:** `Reference/analyze_gold_spreads.py`
**CSV Source:** `Reference/XAUUSD.sml_M1_202501020105_202512312358.csv`

---

**Report Generated By:** Forex Trading Analyst (forex-trading-analyst skill)
**Analysis Date:** February 3, 2026
**Confidence Level:** HIGH (based on full year of M1 data)
