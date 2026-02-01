# Quick Test EA - Usage Guide

**Purpose:** Automated testing tool for validating trade history export, CSMMonitor updates, and performance tracking without waiting for real trading signals.

**Version:** 1.00
**Created:** February 1, 2026
**EA File:** `Jcamp_QuickTestEA.mq5`

---

## 🎯 What It Does

The Quick Test EA automatically opens test trades at regular intervals to generate trade history data for validation purposes:

- **Auto-trades** every 5 minutes (configurable)
- **Rotates through all 4 symbols** (EURUSD → GBPUSD → AUDJPY → XAUUSD)
- **Alternates BUY/SELL** directions
- **Auto-closes positions** after 3 minutes for rapid history generation
- **Exports trade history** using same system as MainTradingEA
- **Uses micro lots** (0.01) for minimal risk

---

## ⚙️ Settings

### Testing Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `EnableTestTrading` | true | Master switch - set to false to stop all testing |
| `TestIntervalMinutes` | 5 | Trade every X minutes |
| `TestAllSymbols` | true | Rotate through all 4 symbols (false = current chart only) |
| `AlternateBuySell` | true | Alternate BUY/SELL directions (false = always BUY) |

### Position Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `TestLotSize` | 0.01 | Lot size (use micro lots only!) |
| `StopLossPips` | 30 | Stop loss distance in pips |
| `TakeProfitPips` | 60 | Take profit distance (2R) |
| `EnableAutoClose` | true | Auto-close positions after X minutes |
| `AutoCloseMinutes` | 3 | Minutes before auto-close triggers |

### Safety Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `MaxTestPositions` | 4 | Maximum total test positions |
| `MaxPositionsPerSymbol` | 1 | Max positions per symbol |
| `VerboseLogging` | true | Detailed logging in Experts tab |

---

## 🚀 How to Use

### Step 1: Install

1. Copy `Jcamp_QuickTestEA.mq5` to MetaEditor (already in symlinked folder)
2. Compile (F7) - should compile with 0 errors
3. Refresh Navigator in MT5 (F5)

### Step 2: Deploy

1. **Attach to ANY chart** (doesn't matter which symbol)
2. **Recommended chart:** EURUSD H1 (easy to monitor)
3. **Settings:** Use defaults for first test
4. **Click OK**

### Step 3: Verify

Check Experts tab for initialization message:
```
═══════════════════════════════════════════════════════════
🧪 QUICK TEST EA - Trade History Testing Tool
═══════════════════════════════════════════════════════════
Version: 1.00
Symbol: EURUSD
Magic Number: 999999

Settings:
  - Test Trading: ENABLED
  - Test Interval: 5 minutes
  - Test All Symbols: YES
  - Alternate Buy/Sell: YES
  - Lot Size: 0.01
  - SL/TP: 30/60 pips
  - Auto-close: YES (3 min)

🚨 WARNING: This EA will automatically trade every 5 minutes!
🚨 Use MICRO LOTS only for testing purposes!
═══════════════════════════════════════════════════════════
```

### Step 4: Monitor

Watch for test trades (every 5 minutes):
```
🧪 TEST TRADE OPENED:
   Symbol: EURUSD.sml
   Type: BUY
   Ticket: #12345678
   Price: 1.08234
   SL: 1.07934 | TP: 1.08834
   Lot: 0.01
   Strategy: QUICK_TEST
   ✓ Trade exported to history
```

Auto-close messages (after 3 minutes):
```
🧪 TEST POSITION AUTO-CLOSED:
   Ticket: #12345678
   Symbol: EURUSD.sml
   Reason: 3 minutes elapsed
   ✓ History updated
```

---

## 📊 Trading Cycle

**Default 5-Minute Rotation:**
```
00:00 → EURUSD BUY    (opens)
00:03 → EURUSD BUY    (auto-closes)
00:05 → GBPUSD SELL   (opens)
00:08 → GBPUSD SELL   (auto-closes)
00:10 → AUDJPY BUY    (opens)
00:13 → AUDJPY BUY    (auto-closes)
00:15 → XAUUSD SELL   (opens)
00:18 → XAUUSD SELL   (auto-closes)
00:20 → EURUSD SELL   (opens, cycle repeats)
...
```

**Result:** 12 trades per hour, 3 trades per symbol per hour

---

## ✅ What to Validate

### 1. Trade History JSON Export

**File:** `Terminal_Data/MQL5/Files/CSM_Data/trade_history.json`

**Check:**
- ✅ Contains QUICK_TEST trades
- ✅ Strategy field = "QUICK_TEST" (not "UNKNOWN")
- ✅ Confidence field = 100
- ✅ All 4 symbols present
- ✅ No duplicate tickets
- ✅ JSON format valid

**Example trade:**
```json
{
  "ticket": "12345678",
  "symbol": "EURUSD.sml",
  "strategy": "QUICK_TEST",
  "confidence": 100,
  "type": "BUY",
  "open_time": "2026.02.01 10:00:00",
  "close_time": "2026.02.01 10:03:15",
  "profit": "+1.50",
  "pips": "+5.0",
  "comment": "QUICK_TEST BUY @100 conf"
}
```

---

### 2. Real-Time CSMMonitor Updates

**Test Process:**
1. Open CSMMonitor.exe
2. Go to "LIVE DASHBOARD" tab
3. Watch Trade History panel
4. When test trade opens (every 5 min), panel should update **within 5 seconds**

**Validation:**
- ✅ New trade appears immediately (5-second real-time export)
- ✅ Trade details correct (symbol, type, entry price)
- ✅ Trade closes after 3 minutes, panel updates again
- ✅ P&L calculated correctly

---

### 3. Persistent History

**Test Process:**
1. Let EA run for 30 minutes (6 trades)
2. Check `trade_history.json` has 6 trades
3. **Restart MT5** (or remove/reattach EA)
4. Let EA run another 30 minutes (6 more trades)
5. Check `trade_history.json` now has 12 trades (no duplicates)

**Validation:**
- ✅ History persists across restarts
- ✅ No duplicate tickets
- ✅ Merge logic works correctly

---

### 4. Multi-Symbol Support

**Test Process:**
1. Let EA run for 20 minutes (one full symbol cycle)
2. Check `trade_history.json`

**Validation:**
- ✅ EURUSD trade exists
- ✅ GBPUSD trade exists
- ✅ AUDJPY trade exists
- ✅ XAUUSD trade exists (with .sml suffix handling)

---

### 5. Strategy Performance Grid

**In CSMMonitor:**
1. Go to "PERFORMANCE" tab
2. Check Strategy Performance grid

**Validation:**
```
Strategy          Trades  Win%   Avg R   Profit
TREND_RIDER       2       50%    1.2     +$9.50
QUICK_TEST        12      58%    0.8     +$15.20  ← Should appear
```

- ✅ QUICK_TEST appears as separate strategy
- ✅ Stats calculate correctly
- ✅ Easy to distinguish from real trades

---

## 🛡️ Safety Features

### Magic Number
- **999999** - Easy to identify test trades
- Different from MainTradingEA (123456)
- Won't interfere with real trades

### Position Limits
- Max 4 total test positions (1 per symbol)
- Won't flood account with test trades

### Micro Lots
- Default 0.01 lots
- ~$0.10/pip for forex
- Minimal risk even if SL hit

### Auto-Close
- Positions close after 3 minutes
- Fast history generation
- Limits exposure

### Easy Disable
- Set `EnableTestTrading = false`
- Stops all new trades immediately
- Can also remove EA from chart

---

## 🔧 Troubleshooting

### "Symbol EURUSD not found"
**Problem:** Broker uses suffix (.sml, .ecn, .raw)
**Solution:** EA auto-detects and uses correct suffix
**Check logs:** Should show "EURUSD.sml" if suffix present

### "Max test positions reached"
**Problem:** Previous test positions still open
**Solution:** Close manually or wait for auto-close (3 min)
**Or:** Increase `MaxTestPositions` setting

### "Trade failed: Invalid stops"
**Problem:** SL/TP too close for broker
**Solution:** Increase `StopLossPips` to 50+
**For Gold:** System handles dollar-based stops automatically

### "No trades opening"
**Problem:** `EnableTestTrading = false` or interval not reached
**Solution:** Check settings, wait for next 5-minute mark
**Check logs:** Should show countdown messages

### "Trade history not exporting"
**Problem:** File permissions or path issue
**Solution:** Check MT5 has write access to `MQL5/Files/CSM_Data/`
**Manual check:** Look for `trade_history.json` in Terminal Data folder

---

## 📈 Recommended Test Scenarios

### Quick Test (20 minutes)
- **Goal:** Verify basic functionality
- **Duration:** 20 minutes
- **Expected:** 4 trades (1 per symbol)
- **Validates:** Multi-symbol support, real-time export

### Full Cycle Test (1 hour)
- **Goal:** Test persistent history
- **Duration:** 60 minutes
- **Expected:** 12 trades
- **Validates:** Merge logic, no duplicates, CSMMonitor updates

### Restart Test (30 min + restart + 30 min)
- **Goal:** Verify history persists
- **Duration:** 60 minutes (split)
- **Expected:** 12 trades total after restart
- **Validates:** JSON import, merge on reload

### Stress Test (4 hours)
- **Goal:** Long-running stability
- **Duration:** 4 hours
- **Expected:** 48 trades
- **Validates:** Performance, memory, file handling

---

## 🗑️ Cleanup

### Remove Test Trades from History
1. **Manual:** Delete `trade_history.json` (fresh start)
2. **Selective:** Edit JSON to remove QUICK_TEST entries
3. **Filter in CSMMonitor:** Strategy filter shows only real trades

### Stop Testing
1. Set `EnableTestTrading = false`
2. Or remove EA from chart
3. Wait for open positions to auto-close (3 min)

---

## 📝 Notes

- **Not for live trading** - Testing tool only!
- **Use demo account** - Never on live account
- **Micro lots only** - Even 0.01 can lose money
- **Monitor first hour** - Ensure it works as expected
- **Markets closed?** - Will attempt trades but may fail (expected)
- **Broker compatibility** - Works with all MT5 brokers
- **Symbol availability** - All 4 symbols must be in Market Watch

---

## 🆚 Comparison with MainTradingEA

| Feature | MainTradingEA | Quick Test EA |
|---------|---------------|---------------|
| **Purpose** | Real trading | Testing only |
| **Signal source** | Strategy_AnalysisEA JSON files | Auto-generated (timer) |
| **Frequency** | 1-2 trades/day | 12 trades/hour |
| **Magic number** | 123456 | 999999 |
| **Strategy name** | TREND_RIDER, RANGE_RIDER, GOLD_TREND_RIDER | QUICK_TEST |
| **Export system** | PerformanceTracker.mqh | PerformanceTracker.mqh (same) |
| **Real capital** | Yes | Yes (but micro lots) |
| **CSMMonitor compatible** | Yes | Yes |

---

## ✅ Success Criteria

After running Quick Test EA for 1 hour, you should have:

- ✅ 12 test trades in MT5 history
- ✅ `trade_history.json` contains 12 QUICK_TEST entries
- ✅ CSMMonitor shows trades in real-time (5-second updates)
- ✅ All 4 symbols tested (EURUSD, GBPUSD, AUDJPY, XAUUSD)
- ✅ No duplicate tickets in JSON
- ✅ Strategy Performance grid shows "QUICK_TEST" row
- ✅ Trade Details panel updates when selecting assets
- ✅ History persists after MT5 restart
- ✅ No errors in Experts tab

**If all criteria met:** Trade history system is working perfectly! ✨

---

**Created by:** Claude Sonnet 4.5
**Date:** February 1, 2026
**Session:** Trade History Validation Tools
