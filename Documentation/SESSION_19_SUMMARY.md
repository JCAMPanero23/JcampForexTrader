# Session 19: StrategyEngine Refactoring + CSM Backtest Mode

**Date:** February 11, 2026
**Duration:** ~3 hours
**Status:** ✅ Complete (Ready for Testing)

---

## 🎯 Objective

Create reusable **StrategyEngine.mqh** module and enable multi-symbol backtesting with portfolio simulation in Python (replaces MT5 multi-pair backtester architecture from Phase 8 planning).

---

## ✅ Accomplished

### 1. **Created StrategyEngine.mqh** (420 lines)

**Purpose:** Single source of truth for strategy evaluation logic

**Features:**
- CSM Gatekeeper check
- Regime detection (TRENDING/RANGING/TRANSITIONAL)
- Strategy selection (TrendRider/RangeRider/GoldTrendRider)
- ATR-based dynamic SL/TP calculation (Session 15)
- Confidence-based R:R scaling (Session 17)
- Symbol-specific calibration (5 forex + Gold support)

**Benefits:**
- ✅ DRY principle - no duplicate evaluation logic
- ✅ Reusable across Strategy_AnalysisEA and CSM_AnalysisEA
- ✅ Easy to modify (one place to update)
- ✅ Cleaner architecture

**Location:** `MT5_EAs/Include/JcampStrategies/StrategyEngine.mqh`

---

### 2. **Refactored Strategy_AnalysisEA.mq5** (870 → 525 lines, -40%)

**Before:**
- 870 lines of code
- Evaluation logic embedded in OnTick()
- Duplicate helper functions

**After:**
- 525 lines of code (-345 lines)
- Clean separation: StrategyEngine handles evaluation
- Simple OnTick(): `engine.EvaluateSymbol()` → Export signal

**Benefits:**
- ✅ Much easier to read and maintain
- ✅ Faster development (no duplicate code)
- ✅ Identical evaluation logic for live & backtest

**Status:** Ready for compilation testing (tonight)

---

### 3. **Modified CSM_AnalysisEA.mq5** - Backtest Mode Added (568 → 922 lines)

**Dual-Mode Operation:**

#### **LIVE MODE** (BacktestMode = false)
- Calculates CSM every 60 minutes (H1)
- Exports to `csm_current.txt`
- Same behavior as before (no changes)

#### **BACKTEST MODE** (BacktestMode = true) ✨ NEW
- Uses StrategyEngine for signal generation
- Generates signals for **ALL 5 assets:**
  - EURUSD.r
  - GBPUSD.r
  - AUDJPY.r
  - USDJPY.r (replaces XAUUSD)
  - USDCHF.r (5th asset)
- Signal generation every 15 minutes (M15 interval)
- CSM updates every 60 minutes (H1, same as live)
- **Buffers in memory:**
  - 200,000 signals (all 5 symbols)
  - 10,000 trades (attached symbol only)
- **Executes trades for ATTACHED SYMBOL only**
- **Exports complete JSON on backtest completion**

**Key Features:**
```mql5
// Backtest parameters
BacktestMode = true                    // Enable backtest
SignalTimeframe = PERIOD_H1            // Strategy evaluation (H1)
SignalCheckIntervalMinutes = 15        // Signal generation (M15)
UpdateIntervalMinutes = 60             // CSM updates (H1)

// Symbols
Symbol1 = "EURUSD"
Symbol2 = "GBPUSD"
Symbol3 = "AUDJPY"
Symbol4 = "USDJPY"  // Replaces XAUUSD (Gold removed)
Symbol5 = "USDCHF"  // 5-asset system
```

**JSON Export Format:**
```json
{
  "backtest_info": {
    "symbol": "EURUSD.r",
    "total_signals": 175200,
    "total_trades": 347,
    "timeframe": "PERIOD_H1"
  },
  "signals": [
    {
      "timestamp": "2024-01-01 00:15:00",
      "symbol": "EURUSD.r",
      "signal": 1,
      "confidence": 85,
      "csm_diff": 23.5,
      "regime": "REGIME_TRENDING",
      "sl": 0.00025,
      "tp": 0.00050
    }
  ],
  "trades": [
    {
      "entry_time": "2024-01-01 08:15:00",
      "symbol": "EURUSD.r",
      "direction": 1,
      "entry_price": 1.05123,
      "sl_price": 1.04873,
      "tp_price": 1.05623
    }
  ]
}
```

**Status:** Ready for 1-month backtest validation

---

## 📊 Data Flow (Backtest Mode)

```
CSM_AnalysisEA (Backtest Mode - M15 bars)
├── Calculate CSM every 60 min (H1 interval)
│   └── 9-currency competitive scoring (USD, EUR, GBP, JPY, CHF, AUD, CAD, NZD, XAU)
│
├── Generate signals every 15 min (M15 interval)
│   ├── For EACH of 5 assets:
│   │   ├── engine.InitializeStrategiesForSymbol(symbol)
│   │   ├── engine.EvaluateSymbol(symbol, H1, signal, regime, failureReason)
│   │   └── Buffer signal in memory (SignalRecord array)
│   │
│   └── Execute trade IF:
│       ├── Signal is BUY or SELL (not HOLD)
│       └── Symbol == _Symbol (attached symbol only)
│
└── OnDeinit: Export JSON file
    ├── All signals (175k for 1 year, all 5 symbols)
    └── All trades (attached symbol only)
```

---

## 🔧 Architecture Decisions

### Why This Approach vs MT5 Multi-Pair Backtester?

**MT5 Limitations (from Phase 8 investigation):**
- ❌ MT5 Strategy Tester can't run multiple symbols natively
- ❌ No portfolio-level position management (max 3 positions across pairs)
- ❌ No correlation analysis
- ❌ Limited parameter optimization

**Our Approach (Hybrid MT5 + Python):**
- ✅ **MT5:** Generate signals for all 5 assets, execute trades for 1 symbol
- ✅ **Python:** Load all 5 JSON files, merge by timestamp, simulate portfolio
- ✅ **Benefits:**
  - Faster development (~6 hours vs ~2 weeks)
  - Real MT5 tick data (more accurate than interpolated)
  - MT5's built-in slippage/spread modeling
  - Easy parameter testing (rerun MT5 backtest in 1 min)
  - Identical strategy logic to live system (via StrategyEngine.mqh)

---

## 📋 Testing Plan (Next Steps)

### **Tonight:** Compilation Testing
- [ ] Open MetaEditor
- [ ] Compile `StrategyEngine.mqh` (F7)
- [ ] Compile `Jcamp_Strategy_AnalysisEA.mq5` (F7)
- [ ] Compile `Jcamp_CSM_AnalysisEA.mq5` (F7)
- [ ] Fix any errors

### **Session 20:** Run 5 Backtests (~1 hour)
- [ ] **EURUSD.r** backtest (2024-01-01 to 2025-01-01, M15)
  - Attach CSM_AnalysisEA to EURUSD.r chart
  - Set BacktestMode = true
  - Run backtest → `backtest_EURUSD.r_2025-01-01.json`

- [ ] **GBPUSD.r** backtest (same period)
  - Attach to GBPUSD.r chart
  - Run backtest → `backtest_GBPUSD.r_2025-01-01.json`

- [ ] **AUDJPY.r** backtest (same period)
  - Attach to AUDJPY.r chart
  - Run backtest → `backtest_AUDJPY.r_2025-01-01.json`

- [ ] **USDJPY.r** backtest (same period)
  - Attach to USDJPY.r chart
  - Run backtest → `backtest_USDJPY.r_2025-01-01.json`

- [ ] **USDCHF.r** backtest (same period)
  - Attach to USDCHF.r chart
  - Run backtest → `backtest_USDCHF.r_2025-01-01.json`

**Expected Runtime:** ~10-15 minutes per backtest (depends on tick data volume)

### **Session 21:** Python Portfolio Simulator (~2 hours)
- [ ] Create `portfolio_simulator.py`
- [ ] Load all 5 JSON files
- [ ] Merge signals by timestamp
- [ ] Simulate portfolio with:
  - Max 3 positions simultaneously
  - 1% risk per trade
  - R-multiple based PnL calculation
  - Position correlation tracking
- [ ] Generate comparison reports:
  - [ ] CSM Gate ON vs OFF
  - [ ] Confidence thresholds (65 vs 75 vs 85)
  - [ ] Max positions (1 vs 2 vs 3)
  - [ ] Per-pair performance
  - [ ] Win rate, avg R, max DD
- [ ] Export results (CSV + charts)

---

## 📁 Files Modified

### Created:
- `MT5_EAs/Include/JcampStrategies/StrategyEngine.mqh` (420 lines)

### Modified:
- `MT5_EAs/Experts/Jcamp_Strategy_AnalysisEA.mq5` (870 → 525 lines, -345)
- `MT5_EAs/Experts/Jcamp_CSM_AnalysisEA.mq5` (568 → 922 lines, +354)

### Total Code Change:
- **+774 lines added** (StrategyEngine + CSM backtest mode)
- **-345 lines removed** (Strategy_AnalysisEA refactor)
- **Net: +429 lines**

---

## 🎉 Key Achievements

1. ✅ **StrategyEngine.mqh** - Single source of truth for evaluation logic
2. ✅ **Strategy_AnalysisEA** - Cleaner, simpler, more maintainable (-40% code)
3. ✅ **CSM_AnalysisEA** - Dual-mode operation (live + backtest)
4. ✅ **Multi-symbol backtesting** - Generates signals for 5 assets simultaneously
5. ✅ **JSON export** - Complete backtest data for Python analysis
6. ✅ **Identical strategy logic** - Live and backtest use same StrategyEngine

---

## 🔜 Next Session Preview

**Session 20: Run 5 Backtests** (~1 hour)
- Run 1-year backtest on each symbol (EURUSD, GBPUSD, AUDJPY, USDJPY, USDCHF)
- Collect 5 JSON files
- Validate JSON format and data integrity

**Session 21: Python Portfolio Simulator** (~2 hours)
- Load and merge all 5 JSON files
- Implement portfolio-level position management
- Generate performance reports
- Compare CSM Gate ON vs OFF
- Validate system before VPS deployment

---

## 💡 Design Philosophy

> **"Generate signals in MT5, simulate portfolio in Python"**

This hybrid approach gives us:
- ✅ MT5's accurate tick data and spread modeling
- ✅ Python's flexibility for portfolio simulation
- ✅ Easy parameter testing (rerun MT5 in 1 min)
- ✅ Identical strategy logic to live system
- ✅ Complete control over position management

**Expected Timeline:**
- Session 19: ✅ Complete (StrategyEngine + CSM backtest mode)
- Session 20: Run 5 backtests (~1 hour)
- Session 21: Python simulator (~2 hours)
- **Total:** ~6 hours vs ~2 weeks for full Python backtester

---

**Status:** ✅ Ready for testing tonight!

*Generated: February 11, 2026*
*Session Duration: ~3 hours*
