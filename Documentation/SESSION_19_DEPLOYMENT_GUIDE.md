# Session 19: Deployment Guide - Replace Gold with USDJPY + USDCHF

**Date:** February 10, 2026
**Status:** Ready for Deployment
**Objective:** Replace Gold (XAUUSD) with USDJPY + USDCHF to respect 3% risk on $500 account

---

## Summary of Changes

### Problem Identified
- **Gold SL:** $50 (Session 18 setting)
- **Account size:** $500
- **Actual risk:** $50 / $500 = **10% per trade** ❌
- **Minimum lot size:** 0.01 (broker constraint)
- **Required account for 3% risk:** $1,667+

**Solution:** Replace Gold with lower volatility pairs (USDJPY + USDCHF) that respect 3% risk at 0.01 lot.

---

## New System Configuration

### **Conservative 5-Pair System** ✅

| Pair | Function | SL Range | Loss at 0.01 Lot | Risk % ($500) |
|------|----------|----------|------------------|---------------|
| **EURUSD.r** | EUR/USD strength | 20-60 pips | $2-6 | 0.4-1.2% ✅ |
| **GBPUSD.r** | GBP/USD strength | 25-80 pips | $2.50-8 | 0.5-1.6% ✅ |
| **AUDJPY.r** | AUD/JPY risk gauge | 25-70 pips | $1.60-4.50 | 0.3-0.9% ✅ |
| **USDJPY.r** | USD/JPY safe haven | 25-70 pips | $2.25-6.30 | 0.5-1.3% ✅ |
| **USDCHF.r** | USD/CHF safe haven | 20-60 pips | $2-6 | 0.4-1.2% ✅ |

**Gold (XAUUSD.r):** Removed (resume when account reaches $1,000+)

---

## CSM Coverage Analysis

### 9-Currency System Coverage

| Currency | Pairs Trading | Coverage Status |
|----------|---------------|-----------------|
| **USD** | 4 pairs (EUR, GBP, JPY, CHF) | ✅ Excellent |
| **EUR** | 1 pair (USD) | ✅ Good |
| **GBP** | 1 pair (USD) | ✅ Good |
| **JPY** | 2 pairs (AUD, USD) | ✅ Excellent |
| **CHF** | 1 pair (USD) | ✅ NEW! |
| **AUD** | 1 pair (JPY) | ✅ Good |
| **CAD** | 0 pairs | ⚠️ Not critical |
| **NZD** | 0 pairs | ⚠️ Not critical |
| **XAU (Gold)** | 0 pairs | ⚠️ Disabled (resume at $1000+) |

**Result:** CHF (Swiss franc) safe haven coverage added!

---

## Code Changes Summary

### 1. Strategy_AnalysisEA.mq5 (3 sections modified)

#### Added USDJPY + USDCHF Parameters
```mql5
input group "═══ USDJPY BOUNDS ═══"
input double   USDJPY_MinSL = 25.0;                       // Min SL (pips)
input double   USDJPY_MaxSL = 70.0;                       // Max SL (pips)
input double   USDJPY_ATRMultiplier = 0.5;                // ATR multiplier

input group "═══ USDCHF BOUNDS ═══"
input double   USDCHF_MinSL = 20.0;                       // Min SL (pips)
input double   USDCHF_MaxSL = 60.0;                       // Max SL (pips)
input double   USDCHF_ATRMultiplier = 0.5;                // ATR multiplier
```

#### Commented Out Gold Parameters
```mql5
// ⚠️ SESSION 19: XAUUSD (Gold) parameters disabled (resume when account > $1000)
// input group "═══ XAUUSD (GOLD) BOUNDS ═══"
// input double   XAUUSD_MinSL = 50.0;
// input double   XAUUSD_MaxSL = 200.0;
// input double   XAUUSD_ATRMultiplier = 0.6;
// input ENUM_TIMEFRAMES XAUUSD_ATRTimeframe = PERIOD_H4;
```

#### Updated 3 Helper Functions
- `GetSymbolATRMultiplier()` - Added USDJPY/USDCHF, commented Gold
- `GetSymbolMinSL()` - Added USDJPY/USDCHF, commented Gold
- `GetSymbolMaxSL()` - Added USDJPY/USDCHF, commented Gold

---

### 2. MainTradingEA.mq5 (3 sections modified)

#### Updated Version & Description
```mql5
#property version   "2.10"
#property description "CSM Alpha Main Trading EA - 5 Asset System (Session 19)"
#property description "Trades: EURUSD.r, GBPUSD.r, AUDJPY.r, USDJPY.r, USDCHF.r"
```

#### Updated Traded Symbols List
```mql5
input string TradedSymbols = "EURUSD.r,GBPUSD.r,AUDJPY.r,USDJPY.r,USDCHF.r";
// Session 19: 5 assets (Gold removed, replaced with USDJPY + USDCHF)
```

#### Updated Spread Multipliers
```mql5
input double SpreadMultiplierUSDJPY = 1.0;  // USDJPY spread multiplier (1x = 2.0 pips) - Session 19
input double SpreadMultiplierUSDCHF = 1.0;  // USDCHF spread multiplier (1x = 2.0 pips) - Session 19
// input double SpreadMultiplierXAUUSD = 15.0;  // XAUUSD (Gold) - Disabled Session 19
```

#### Updated TradeExecutor Initialization
```mql5
tradeExecutor = new TradeExecutor(RiskPercent, MinConfidence, MaxSpreadPips, MagicNumber, VerboseLogging,
                                  SpreadMultiplierEURUSD, SpreadMultiplierGBPUSD,
                                  SpreadMultiplierAUDJPY, SpreadMultiplierUSDJPY, SpreadMultiplierUSDCHF);
```

---

### 3. TradeExecutor.mqh (2 sections modified)

#### Updated Constructor Signature
```mql5
TradeExecutor(double riskPct = 1.0,
              int minConf = 70,
              double maxSpread = 2.0,
              int magicNum = 100001,
              bool verbose = false,
              double eurMultiplier = 1.0,
              double gbpMultiplier = 1.0,
              double audMultiplier = 1.0,
              double usdjpyMultiplier = 1.0,   // Session 19
              double usdchfMultiplier = 1.0)   // Session 19
```

#### Updated Spread Multipliers Array
```mql5
// Initialize spread multipliers for CSM Alpha symbols (Session 19: 5 pairs)
ArrayResize(spreadMultipliers, 5);
spreadMultipliers[0].symbol = "EURUSD";  spreadMultipliers[0].multiplier = eurMultiplier;
spreadMultipliers[1].symbol = "GBPUSD";  spreadMultipliers[1].multiplier = gbpMultiplier;
spreadMultipliers[2].symbol = "AUDJPY";  spreadMultipliers[2].multiplier = audMultiplier;
spreadMultipliers[3].symbol = "USDJPY";  spreadMultipliers[3].multiplier = usdjpyMultiplier;
spreadMultipliers[4].symbol = "USDCHF";  spreadMultipliers[4].multiplier = usdchfMultiplier;
// XAUUSD removed - Session 19 (resume at $1000+ account)
```

---

## Deployment Steps

### Step 1: Close Open Gold Positions ⚠️

**Before deploying, close any open Gold positions manually:**

1. Open MT5 Terminal
2. Go to "Trade" tab
3. Find any XAUUSD.r positions
4. Right-click → Close Position
5. **Reason:** Avoid orphaned positions that MainTradingEA won't manage

---

### Step 2: Compile Updated EAs in MetaEditor

**Compile all 3 modified files:**

1. Open MetaEditor (press F4 in MT5)
2. Navigate to `Experts\Jcamp\`
3. Open `Jcamp_Strategy_AnalysisEA.mq5` → Press **F7** to compile
   - ✅ Check for 0 errors, 0 warnings
4. Open `Jcamp_MainTradingEA.mq5` → Press **F7** to compile
   - ✅ Check for 0 errors, 0 warnings
5. Verify `.ex5` files updated in `MQL5\Experts\Jcamp\`

**Expected result:**
```
Compiling 'Jcamp_Strategy_AnalysisEA.mq5'
0 error(s), 0 warning(s)

Compiling 'Jcamp_MainTradingEA.mq5'
0 error(s), 0 warning(s)
```

---

### Step 3: Update MT5 Chart Configuration

**Remove Gold chart, add USDJPY + USDCHF:**

#### Remove Gold:
1. Find chart with `XAUUSD.r` and `Jcamp_Strategy_AnalysisEA`
2. Remove EA from chart (drag off or disable)
3. Close XAUUSD.r chart window

#### Add USDJPY:
1. File → New Chart → USDJPY.r (or USDJPY with your broker suffix)
2. Set timeframe to **H1** (1-hour chart)
3. Drag `Jcamp_Strategy_AnalysisEA` EA to chart
4. Configure settings:
   - `AnalysisTimeframe`: PERIOD_H1
   - `AnalysisInterval`: 15 (minutes)
   - `MinConfidenceScore`: 70
   - `EnableTrendRider`: true
   - `EnableRangeRider`: true
   - `VerboseLogging`: true
   - `BrokerSuffix`: ".r" (or your broker's suffix)
5. Click **OK** (allow live trading)

#### Add USDCHF:
1. File → New Chart → USDCHF.r
2. Set timeframe to **H1**
3. Drag `Jcamp_Strategy_AnalysisEA` EA to chart
4. Configure same settings as USDJPY
5. Click **OK**

**Final chart setup:**
```
CSM_AnalysisEA   → Any chart (e.g., EURUSD.r) - Generates CSM
Strategy_AnalysisEA → EURUSD.r (H1) - Generates signals
Strategy_AnalysisEA → GBPUSD.r (H1) - Generates signals
Strategy_AnalysisEA → AUDJPY.r (H1) - Generates signals
Strategy_AnalysisEA → USDJPY.r (H1) - Generates signals ✅ NEW
Strategy_AnalysisEA → USDCHF.r (H1) - Generates signals ✅ NEW
MainTradingEA    → Any chart - Executes trades (reads all 5 signal files)
```

---

### Step 4: Restart MainTradingEA

**Apply updated MainTradingEA:**

1. Find chart with `Jcamp_MainTradingEA`
2. Remove EA from chart
3. Drag `Jcamp_MainTradingEA` EA back to chart
4. Configure settings:
   - `TradedSymbols`: "EURUSD.r,GBPUSD.r,AUDJPY.r,USDJPY.r,USDCHF.r"
   - `RiskPercent`: 1.0 (or 3.0 if you want 3% risk)
   - `MinConfidence`: 70
   - `MaxTotalPositions`: 3 (or 4-5 for more exposure)
   - `UseAdvancedTrailing`: true
   - `VerboseLogging`: true
5. Click **OK**

**Verify initialization logs:**
```
========================================
Jcamp MainTradingEA - Initializing
========================================
Traded Symbols: EURUSD.r,GBPUSD.r,AUDJPY.r,USDJPY.r,USDCHF.r
Signal Folder: CSM_Signals
Risk Per Trade: 1.0%
Min Confidence: 70
Magic Number: 100001
========================================
```

---

### Step 5: Verify Signal Generation

**Wait 15 minutes for first signals:**

1. Open `Terminal → Common` (or MQL5 folder)
2. Navigate to `Files\CSM_Signals\`
3. Check for 5 signal files:
   - ✅ `EURUSD.r_signals.json`
   - ✅ `GBPUSD.r_signals.json`
   - ✅ `AUDJPY.r_signals.json`
   - ✅ `USDJPY.r_signals.json` (NEW!)
   - ✅ `USDCHF.r_signals.json` (NEW!)
   - ❌ `XAUUSD.r_signals.json` (should NOT exist after restart)

4. Open any new signal file (e.g., `USDJPY.r_signals.json`):
```json
{
  "symbol": "USDJPY.r",
  "timestamp": "2026.02.10 XX:XX:XX",
  "strategy": "TREND_RIDER" or "RANGE_RIDER",
  "signal": 1 or -1 or 0,
  "confidence": XX,
  "stop_loss_dollars": XX.XX,
  "take_profit_dollars": XX.XX,
  ...
}
```

---

### Step 6: Monitor First Trades

**Validate risk management on new pairs:**

1. Wait for first USDJPY or USDCHF trade
2. Check Expert tab logs:
```
✅ Trade Executed: USDJPY.r BUY
   Lots: 0.01
   Entry: 150.XXX
   SL: 150.XXX (25-70 pips away)
   TP: 150.XXX (50-175 pips away)
   Confidence: XX
```

3. Verify position loss if stopped out:
   - USDJPY at 0.01 lot: Max $2.25-6.30 loss ✅
   - USDCHF at 0.01 lot: Max $2-6 loss ✅
   - **Both respect 3% risk on $500 account!**

4. Check `positions.txt`:
```
USDJPY.r BUY | Strategy: TREND_RIDER | Lots: 0.01 | SL: XXX | TP: XXX
USDCHF.r BUY | Strategy: RANGE_RIDER | Lots: 0.01 | SL: XXX | TP: XXX
```

---

## Expected Results

### Risk Profile Comparison

| Metric | Before (4 pairs with Gold) | After (5 pairs, no Gold) | Improvement |
|--------|---------------------------|--------------------------|-------------|
| **Max loss per trade** | $50 (Gold) ❌ | $2-8 (all pairs) ✅ | **84% safer** |
| **Risk per trade** | 10% (Gold) ❌ | 0.4-1.6% (all) ✅ | **91% better** |
| **Worst case 3 losses** | -$150 (-30%) ❌ | -$18 (-3.6%) ✅ | **88% safer** |
| **Pairs trading** | 4 (EURUSD, GBPUSD, AUDJPY, Gold) | 5 (EUR, GBP, AUD, USDJPY, USDCHF) | **+25% more** |
| **CSM coverage** | 8 currencies (missing CHF) | 9 currencies (CHF added!) | **+12% better** |

---

## Rollback Plan (If Issues Occur)

**If you need to revert to Gold system:**

1. Git rollback:
```bash
cd /d/JcampForexTrader
git restore MT5_EAs/Experts/Jcamp_Strategy_AnalysisEA.mq5
git restore MT5_EAs/Experts/Jcamp_MainTradingEA.mq5
git restore MT5_EAs/Include/JcampStrategies/Trading/TradeExecutor.mqh
```

2. Recompile EAs in MetaEditor (F7)
3. Remove USDJPY.r and USDCHF.r charts
4. Add XAUUSD.r chart back with Strategy_AnalysisEA
5. Update MainTradingEA `TradedSymbols` back to original

---

## Resuming Gold Trading (Future)

**When account reaches $1,000+:**

1. Uncomment Gold parameters in `Strategy_AnalysisEA.mq5`:
```mql5
// Change from:
// input double XAUUSD_MinSL = 50.0;

// To:
input double XAUUSD_MinSL = 50.0;
```

2. Update `MainTradingEA.mq5`:
```mql5
// Add Gold back:
input string TradedSymbols = "EURUSD.r,GBPUSD.r,AUDJPY.r,USDJPY.r,USDCHF.r,XAUUSD.r";
input double SpreadMultiplierXAUUSD = 15.0;

// Update TradeExecutor call (add 6th parameter)
tradeExecutor = new TradeExecutor(..., xauMultiplier);
```

3. Update `TradeExecutor.mqh` constructor (add 6th parameter back)
4. Recompile all 3 files
5. Add XAUUSD.r chart with Strategy_AnalysisEA
6. Restart MainTradingEA

**At $1,000 account:**
- Gold $50 SL = 5% risk (acceptable)
- Can trade all 6 pairs comfortably

---

## Troubleshooting

### Issue: "Symbol USDJPY.r not found"
**Solution:** Check your broker's symbol suffix. It might be:
- `USDJPY` (no suffix)
- `USDJPY.r` (FP Markets Raw)
- `USDJPY.ecn` (ECN account)
- `USDJPY.sml` (some brokers)

Update `BrokerSuffix` input parameter in Strategy_AnalysisEA.

---

### Issue: No signal files generated for new pairs
**Solution:**
1. Check Expert tab for errors
2. Verify EA is running (check "AutoTrading" button is ON)
3. Wait 15 minutes (signal export interval)
4. Check `CSM_Signals` folder path is correct

---

### Issue: MainTradingEA not executing new pair trades
**Solution:**
1. Verify `TradedSymbols` includes broker suffix (`.r`)
2. Check signal file name matches: `USDJPY.r_signals.json`
3. Restart MainTradingEA (remove and re-add to chart)
4. Check Expert tab for "Signal validation failed" logs

---

## Testing Checklist

- [ ] All 3 EAs compile with 0 errors
- [ ] 5 signal files generated (EURUSD, GBPUSD, AUDJPY, USDJPY, USDCHF)
- [ ] No XAUUSD signal file exists
- [ ] MainTradingEA logs show 5 symbols monitored
- [ ] First USDJPY trade: Max $6.30 loss at 0.01 lot ✅
- [ ] First USDCHF trade: Max $6 loss at 0.01 lot ✅
- [ ] No Gold trades executed
- [ ] positions.txt shows new pairs correctly
- [ ] CSMMonitor displays all 5 pairs (if updated)
- [ ] Trade history shows proper strategy names for new pairs

---

## Next Session Preview

**Session 20: Extended Demo Trading Validation (1-2 weeks)**

- Collect 50+ closed trades across all 5 pairs
- Analyze per-pair performance:
  - USDJPY vs Gold (was Gold better despite high risk?)
  - USDCHF performance (CHF safe haven effectiveness)
  - Risk-adjusted returns comparison
- Fine-tune confidence thresholds if needed
- Prepare for Phase 3: Python multi-pair backtesting

**Goal:** Validate that 5-pair conservative system is profitable and respects risk management before VPS deployment.

---

**Deployment Date:** February 10, 2026
**Status:** ✅ Ready for Testing
**Next Review:** After 20+ trades on new pairs

---

*This guide is part of Session 19: Replace Gold with USDJPY + USDCHF for proper risk management on small accounts.*
