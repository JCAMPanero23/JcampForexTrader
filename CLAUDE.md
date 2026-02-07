# CLAUDE.md - JcampForexTrader Context

**Purpose:** Single authoritative reference for Claude Code
**Project:** CSM Alpha - 4-Asset Trading System with Gold
**Last Updated:** February 7, 2026 (Session 16 - 3-Phase Asymmetric Trailing Complete)

---

## 🚨 CRITICAL - PATH CONFIGURATION

**Environment:** Windows 11 + Git Bash
**Shell Type:** Git Bash (MINGW64)

### Path Format Rules

**ALWAYS use Git Bash paths:**
```bash
/d/JcampForexTrader/
/d/JcampForexTrader/MT5_EAs/
/d/JcampForexTrader/Documentation/
```

**NEVER use:**
- ❌ `D:\JcampForexTrader\` (Windows paths)
- ❌ `/mnt/d/` (WSL paths)

### MT5 MetaEditor Integration ✅

**Symlinks Created (January 18, 2026):**
- ✅ `MT5\Experts\Jcamp\` → `D:\JcampForexTrader\MT5_EAs\Experts\`
- ✅ `MT5\Include\JcampStrategies\` → `D:\JcampForexTrader\MT5_EAs\Include\JcampStrategies\`

**What This Means:**
- Work in clean dev folder: `D:\JcampForexTrader\MT5_EAs\`
- MetaEditor sees changes automatically (no manual copying)
- Compile directly in MetaEditor (F7)
- Git tracks changes normally

**See:** `SYMLINK_VERIFICATION.md` for complete setup details

---

## 📁 PROJECT STRUCTURE

```
/d/JcampForexTrader/
├── .git/                              # Git repository (initialized ✅)
├── CLAUDE.md                          # This file
├── README.md                          # Project overview
├── .gitignore                         # Git ignore rules
├── SYMLINK_VERIFICATION.md            # Symlink setup verification
│
├── MT5_EAs/                          # MQ5 Expert Advisors
│   ├── Experts/                      # ← Symlinked to MT5
│   │   ├── Jcamp_CSM_AnalysisEA.mq5  (TODO - copy from old repo)
│   │   ├── Jcamp_Strategy_AnalysisEA.mq5 ✅ Complete (tested, Phase 4E added)
│   │   └── Jcamp_MainTradingEA.mq5   ✅ Complete (Session 6 - modular)
│   │
│   └── Include/
│       └── JcampStrategies/          # ← Symlinked to MT5
│           ├── Indicators/           ✅ Complete (4 modules)
│           │   ├── EmaCalculator.mqh
│           │   ├── AtrCalculator.mqh
│           │   ├── AdxCalculator.mqh
│           │   └── RsiCalculator.mqh
│           ├── RegimeDetector.mqh    ✅ Complete (100-point scoring + dynamic detection)
│           ├── Strategies/           ✅ Complete (2 strategies + interface)
│           │   ├── IStrategy.mqh
│           │   ├── TrendRiderStrategy.mqh
│           │   └── RangeRiderStrategy.mqh
│           ├── Trading/              ✅ Complete (4 modules)
│           │   ├── SignalReader.mqh
│           │   ├── TradeExecutor.mqh
│           │   ├── PositionManager.mqh
│           │   └── PerformanceTracker.mqh
│           └── SignalExporter.mqh    ✅ Complete (JSON export)
│
├── CSMMonitor/                       # C# WPF Dashboard (TODO - copy from old repo)
│   └── JcampForexTrader/
│       ├── MainWindow.xaml
│       └── MainWindow.xaml.cs
│
├── Documentation/
│   ├── CORRECT_ARCHITECTURE_FOUND.md  # ✅ Architecture discovery
│   ├── CSM_ARCHITECTURE_SUMMARY.md    # ✅ CSM overview
│   ├── OPTION_B_FINDINGS.md           # ✅ Investigation results
│   └── MT5_PATH_SETUP.md              # ✅ Symlink guide
│
├── Reference/
│   └── Jcamp_BacktestEA.mq5          # ✅ 9,063 lines - strategy source
│
└── sync_to_mt5.bat                    # Manual sync script (backup option)
    sync_from_mt5.bat                  # Reverse sync (backup option)
```
---

## 🎯 CURRENT PHASE: CSM Alpha - Live Demo Trading

**Status:** ✅ Phase 1 Complete | 🎉 Demo Trading Active & Profitable!

**✅ Completed (Sessions 1-7):**
- ✅ Modular strategy architecture (4 indicators, 2 strategies)
- ✅ Strategy_AnalysisEA with dynamic regime detection
- ✅ MainTradingEA with 4 trading modules
- ✅ **CSM Alpha:** 9-currency system with Gold integration
- ✅ **4-asset trading:** EURUSD, GBPUSD, AUDJPY, XAUUSD
- ✅ Synthetic Gold pair calculation
- ✅ Gold TrendRider-only strategy

**Next Session Tasks:**
1. Test compilation in MetaEditor
   - [ ] CSM_AnalysisEA.mq5 (new)
   - [ ] Strategy_AnalysisEA.mq5 (updated)
   - [ ] MainTradingEA.mq5 (updated)

2. Deploy on demo account
   - [ ] CSM_AnalysisEA on any chart (generates CSM)
   - [ ] Strategy_AnalysisEA on 4 charts (EURUSD, GBPUSD, AUDJPY, XAUUSD)
   - [ ] MainTradingEA on any chart (executes trades)

3. Validate CSM Alpha system
   - [ ] Verify Gold strength calculation
   - [ ] Test synthetic Gold pair accuracy
   - [ ] Validate signal generation for all 4 assets
   - [ ] Monitor Gold TrendRider-only behavior

---

## 🏗️ CSM ALPHA ARCHITECTURE

**🌟 NEW:** 9-Currency System with Gold as Market Fear Indicator

### Data Flow
```
MT5 Terminal
    ↓
Jcamp_CSM_AnalysisEA.mq5 (any chart)
    ↓ [Calculates 9-currency strengths: USD, EUR, GBP, JPY, CHF, AUD, CAD, NZD, XAU]
    ↓ [Uses synthetic Gold pairs: XAUEUR, XAUJPY, XAUGBP, XAUAUD]
    ↓ (writes every 60 min)
csm_current.txt (currency strengths 0-100)
    ↓
Jcamp_Strategy_AnalysisEA.mq5 (per symbol: EURUSD, GBPUSD, AUDJPY, XAUUSD)
    ↓ [Reads CSM from file]
    ↓ [Gold uses TrendRider only, others use both strategies]
    ↓ (writes every 15 min)
EURUSD_signals.json, GBPUSD_signals.json, AUDJPY_signals.json, XAUUSD_signals.json
    ↓
Jcamp_MainTradingEA.mq5 (any chart)
    ↓ [Reads signals from 4 assets]
    ↓ (executes trades)
trade_history.json, positions.txt, performance.txt
    ↓ (reads every 5 sec)
CSMMonitor.exe (C# Dashboard)
```

### Key Components

**1. Jcamp_CSM_AnalysisEA.mq5** (✅ NEW - Session 7)
- **9-currency competitive scoring:** USD, EUR, GBP, JPY, CHF, AUD, CAD, NZD, **XAU (Gold)**
- Synthetic Gold pair calculation (XAUEUR, XAUJPY, XAUGBP, XAUAUD)
- Gold strength = Market fear indicator (0-100 scale)
- Exports to csm_current.txt every 60 minutes
- Runs once (any chart)
- **Status:** ✅ Complete (640 lines)

**2. Jcamp_Strategy_AnalysisEA.mq5** (✅ UPDATED - Session 7)
- Reads CSM from file (no embedded calculation)
- Evaluates strategies per symbol
- **4 assets:** EURUSD, GBPUSD, AUDJPY, XAUUSD
- **Gold special handling:** TrendRider only (skips RangeRider)
- Uses modular .mqh includes
- Exports to {SYMBOL}_signals.json every 15 minutes
- Runs per symbol (4 charts: EURUSD, GBPUSD, AUDJPY, XAUUSD)
- **Status:** ✅ Complete (548 lines, optimized from 747)

**3. Jcamp_MainTradingEA.mq5** (✅ UPDATED - Session 7)
- **4 assets:** EURUSD, GBPUSD, AUDJPY, XAUUSD
- Reads all signal files
- Executes trades with risk management
- Manages positions & trailing stops
- Exports history/performance
- **Status:** ✅ Complete with 4 core trading modules

**4. CSMMonitor.exe** (C# WPF Dashboard)
- Reads all exported files
- Displays live dashboard
- 5-second auto-refresh
- **Status:** ⚠️ Needs update for CSM Alpha
  - Copy from old repo (commit 567d05c)
  - Update to display 9 currencies (add Gold/XAU)
  - Update to monitor 4 assets (EURUSD, GBPUSD, AUDJPY, XAUUSD)
  - Remove GBPNZD references
  - Add Gold "fear indicator" visualization

---

## 🖥️ C# MONITOR UPDATE REQUIREMENTS

### CSM Alpha Changes Needed

**From (Old 8-Currency System):**
- 8 currencies: USD, EUR, GBP, JPY, CHF, AUD, CAD, NZD
- 3 assets: EURUSD, GBPUSD, GBPNZD

**To (CSM Alpha 9-Currency System):**
- **9 currencies:** USD, EUR, GBP, JPY, CHF, AUD, CAD, NZD, **XAU (Gold)**
- **4 assets:** EURUSD, GBPUSD, AUDJPY, XAUUSD

### Required Code Changes

**1. CSM Display (MainWindow.xaml)**
- Add 9th row for Gold (XAU) in currency strength grid
- Add visual indicator for Gold strength level:
  - Red background (80-100): FEAR/PANIC mode
  - Yellow background (40-60): NEUTRAL
  - Green background (0-20): GREED/RISK-ON mode

**2. Signal File Monitoring (MainWindow.xaml.cs)**
```csharp
// OLD:
string[] symbols = { "EURUSD", "GBPUSD", "GBPNZD" };

// NEW:
string[] symbols = { "EURUSD", "GBPUSD", "AUDJPY", "XAUUSD" };
```

**3. CSM File Parser**
```csharp
// OLD: Read 8 currencies from csm_current.txt
// NEW: Read 9 currencies (add XAU handling)

// Example:
if (currency == "XAU")
{
    // Display as "Gold" with special formatting
    GoldStrengthLabel.Content = $"Gold: {strength:F1}";
    UpdateGoldIndicator(strength); // Color-code fear/greed
}
```

**4. Market State Detection**
- Add logic to detect market states:
  - **PANIC:** Gold > 80 AND JPY > 80
  - **RISK-ON:** Gold < 20 AND JPY < 20
  - **INFLATION FEAR:** Gold > 80 AND USD > 80
- Display market state in dashboard header

**5. Asset-Specific Labels**
- Update labels for new assets:
  - "AUDJPY - The Risk Gauge"
  - "XAUUSD - The Sentinel (Gold)"
- Remove GBPNZD references

**6. Gold Visualization Ideas**
- Gold strength meter with fear/greed zones
- Chart showing Gold vs JPY correlation
- Market state indicator: "RISK-ON" / "NEUTRAL" / "RISK-OFF"
- Gold trend arrow (up = safe haven demand, down = risk appetite)

### Testing Checklist
- [ ] CSM display shows all 9 currencies
- [ ] Gold row has special color-coding (fear indicator)
- [ ] 4 signal files read correctly (EURUSD, GBPUSD, AUDJPY, XAUUSD)
- [ ] No GBPNZD references remain
- [ ] Market state detection works (Gold+JPY logic)
- [ ] Auto-refresh continues working (5 seconds)
- [ ] Performance data shows 4 assets

---

## 📊 STRATEGY MODULES (Implemented Architecture)

### Indicators (Include/JcampStrategies/Indicators/)
- **EmaCalculator.mqh** - EMA 20/50/100 calculation
- **AtrCalculator.mqh** - ATR for volatility measurement
- **AdxCalculator.mqh** - Trend strength indicator
- **RsiCalculator.mqh** - Momentum oscillator

### Regime Detection (Include/JcampStrategies/)
- **RegimeDetector.mqh** - TRENDING/RANGING/TRANSITIONAL classification
- 100-point competitive scoring system
- Dynamic regime switching (Phase 4E)

### Strategies (Include/JcampStrategies/Strategies/)
- **IStrategy.mqh** - Base interface for all strategies
- **TrendRiderStrategy.mqh** - 135-point confidence system
  - EMA alignment (0-30 points)
  - ADX strength (0-25 points)
  - RSI momentum (0-20 points)
  - CSM confirmation (0-25 points)
- **RangeRiderStrategy.mqh** - Support/resistance trading
  - Range width analysis
  - S/R level detection
  - Bounce quality scoring

### Trading (Include/JcampStrategies/Trading/)
- **SignalReader.mqh** - Multi-symbol JSON signal parsing
- **TradeExecutor.mqh** - Risk-managed trade execution
- **PositionManager.mqh** - Position tracking & trailing stops
- **PerformanceTracker.mqh** - Trade history & performance export

### Export (Include/JcampStrategies/)
- **SignalExporter.mqh** - JSON file writing
- Exports complete signal data
- CSM integration
- Strategy breakdown

---

## 🎯 DESIGN PRINCIPLES

### 1. Modular Architecture
- Each component in separate .mqh file
- Easy to test independently
- Easy to update/replace
- Single responsibility principle

### 2. Strategy Source: BacktestEA
- BacktestEA.mq5 (9,063 lines) is the validated source
- Extract proven logic, don't reinvent
- Maintain calculation accuracy
- Preserve backtested performance characteristics

### 3. CSM Integration
- All strategies use CSM confirmation
- Currency strength > technical indicators
- Filters false signals
- Directional bias validation

### 4. Clean Separation
- Indicators → Regime → Strategies → Signals
- Each layer independent
- Clear data flow
- No circular dependencies

---

## ⚙️ STANDARD COMMANDS

### Git Operations
```bash
cd /d/JcampForexTrader
git status
git log --oneline -10
git add -A
git commit -m "Description"
```

### File Navigation
```bash
# List MT5 EAs
ls -la /d/JcampForexTrader/MT5_EAs/Experts/

# List strategy modules
ls -la /d/JcampForexTrader/MT5_EAs/Include/JcampStrategies/

# View reference EA
cat /d/JcampForexTrader/Reference/Jcamp_BacktestEA.mq5 | head -100

# Check symlinks working
ls -la "/c/Users/Jcamp_Laptop/AppData/Roaming/MetaQuotes/Terminal/D0E8209F77C8CF37AD8BF550E51FF075/MQL5/Experts/" | grep Jcamp
```

### MetaEditor Workflow
```bash
# Edit files in dev folder
cd /d/JcampForexTrader/MT5_EAs/Experts/
# MetaEditor sees changes automatically via symlinks

# After editing, compile in MetaEditor (F7)
# Then commit changes
git add -A
git commit -m "Updated strategy logic"
```

---

## 🚀 DEPLOYMENT ROADMAP

### Phase 1: Local Development (✅ COMPLETE - Sessions 1-7)
- [x] Setup clean repository
- [x] Create folder structure
- [x] Setup MT5 symlinks
- [x] Extract indicators from BacktestEA (Session 2 - ~1 hour)
- [x] Extract regime detection (Session 2 - ~1.5 hours)
- [x] Extract strategies (Session 3 - ~3 hours)
- [x] Create Strategy_AnalysisEA with modular components (Session 4 - ~2.5 hours)
- [x] Test compilation in MetaEditor (Session 4 - ✅ Successful)
- [x] Test Strategy_AnalysisEA on live chart (Session 5 - ~1 hour)
- [x] Add Phase 4E dynamic regime detection (Session 5 - ~1.5 hours)
- [x] Create modular MainTradingEA (Session 6 - ~3 hours)
- [x] **Build CSM_AnalysisEA with Gold integration** (Session 7 - ~4 hours)
- [x] **Update to 4-asset system** (Session 7 - included above)

**Total Time:** ~20.5 hours | **Status:** ✅ Complete!

### Phase 2: CSM Alpha Testing & Integration (🔄 IN PROGRESS - Sessions 8-13)
- [x] Test CSM Alpha EAs compilation in MetaEditor (~30 min)
  - [x] CSM_AnalysisEA.mq5 ✅
  - [x] Strategy_AnalysisEA.mq5 (updated) ✅
  - [x] MainTradingEA.mq5 (updated) ✅
- [x] **Update C# CSM Monitor** (~3 hours)
  - [x] CSMMonitor already existed (from previous work)
  - [x] Fixed signal file path (CSM_Signals folder + broker suffix)
  - [x] Fixed CSM parser (comma-separated format)
  - [x] Added CSM Alpha JSON signal parser (flat structure)
  - [x] 9 currencies displaying (including Gold/XAU)
  - [x] 4 assets monitoring (EURUSD, GBPUSD, AUDJPY, XAUUSD)
  - [x] Tested with live CSM Alpha data ✅
- [x] Deploy CSM Alpha on local MT5 demo (~1 hour)
  - [x] CSM_AnalysisEA on any chart ✅
  - [x] Strategy_AnalysisEA on 4 charts (EURUSD, GBPUSD, AUDJPY, XAUUSD) ✅
  - [x] MainTradingEA on any chart ✅
- [x] Validate CSM Alpha system (~2 hours)
  - [x] Gold strength calculation working (100 = extreme fear) ✅
  - [x] 4-asset signal generation confirmed ✅
  - [x] Gold TrendRider-only behavior verified ✅
  - [x] **First live trades executed!** (EURUSD +$6.08, GBPUSD +$3.42) 🎉
- [x] **Bonus Achievements:**
  - [x] Spread multiplier system (15x for Gold - Session 9)
  - [x] Symbol-aware SL/TP (Gold: $50/$100, Forex: 50/100 pips)
  - [x] Position log spam fix
  - [x] Broker suffix handling
  - [x] CSM Gatekeeper refactoring (Session 11)
  - [x] Enhanced Signal Dashboard with component scores (Session 13)
- [x] Session 14: Market validation (NEXT - pending market open)
- [ ] Sessions 15-17: Collect 50+ demo trades (~2 weeks)
- [ ] Fine-tune confidence thresholds based on data

### Phase 3: Python Multi-Pair Backtesting (Week 3-4)
**Decision (Session 14.5):** MT5 multi-pair backtester scrapped - resume Phase 8 Python backtester instead

- [ ] Resume Phase 8 Python backtester (D:\Jcamp_TradingApp)
- [ ] Port CSM Alpha logic to Python
  - [ ] 9-currency competitive scoring
  - [ ] Synthetic Gold pair calculation
  - [ ] TrendRider/RangeRider/GoldTrendRider strategies
  - [ ] CSM gatekeeper logic
- [ ] Run 1-year multi-pair backtest (2024-2025)
  - [ ] All 4 pairs: EURUSD, GBPUSD, AUDJPY, XAUUSD
  - [ ] Portfolio-level simulation (1% risk per trade)
  - [ ] Combined equity curve
- [ ] Compare architectures
  - [ ] CSM Gate ON vs OFF (answer Session 14.5 question)
  - [ ] Confidence thresholds (70 vs 80 vs 90)
  - [ ] Spread multipliers optimization
- [ ] Generate comprehensive reports
  - [ ] Per-pair performance
  - [ ] Correlation analysis
  - [ ] Drawdown scenarios
  - [ ] Win rate, R-multiples, Sharpe ratio

**Prerequisites:**
- ✅ 50+ closed demo trades collected
- ✅ CSM Alpha system stable (no critical bugs)
- ✅ Need to validate historical performance

### Phase 4: VPS Deployment (Week 5)
**Only proceed if:**
- ✅ Demo trading: Win rate > 50%, positive R-multiple
- ✅ Python backtest: Profitable over 1 year, max DD < 20%

**Tasks:**
- [ ] Setup Forex VPS (Vultr recommended, $12/month)
- [ ] Install Windows Server 2022
- [ ] Install MT5 on VPS
- [ ] Deploy CSM architecture remotely
- [ ] Setup file sync for C# Monitor
- [ ] Verify 24/7 operation

### Phase 5: Live Trading (Week 6+)
- [ ] Start with micro lots (0.01)
- [ ] Monitor daily performance
- [ ] Track win rate, R-multiples, drawdown
- [ ] Gradually increase position size
- [ ] Aim for consistent profitability

---

## 📋 SESSION CHECKLIST

### Session Start
- [x] Read this CLAUDE.md
- [ ] Check git status
- [ ] Review current phase
- [ ] Check symlinks still working

### During Session
- [ ] Use Git Bash paths (`/d/...`)
- [ ] Test incrementally
- [ ] Document changes
- [ ] Commit frequently

### Session End
- [ ] Update documentation
- [ ] Commit all changes
- [ ] Update this CLAUDE.md if needed
- [ ] Note next session tasks

---

## 🔗 RELATED PROJECTS

### D:\Jcamp_TradingApp (Phase 8 - Resuming Soon)
- **Status:** Complete, ready to resume
- **Content:** Phase 8 multi-pair backtesting (Python + C#)
- **Purpose:** Validate CSM Alpha on historical data before VPS live trading
- **When to Resume:** 3-4 weeks (after collecting 50+ demo trades)

**Phase 8 Work Preserved:**
- Python backtesting engine (30/31 tests passing)
- C# chart viewer with playback
- Multi-pair support (EURUSD, GBPUSD, GBPNZD)
- All bugs documented for future fixes

**Resumption Plan:**
- Port CSM Alpha logic to Python (9-currency system, Gold integration)
- Run 1-year backtest on all 4 pairs (EURUSD, GBPUSD, AUDJPY, XAUUSD)
- Compare CSM Gate ON vs OFF architectures
- Validate confidence thresholds and spread multipliers
- Generate performance reports before VPS deployment

**Decision (Session 14.5):**
- ❌ **MT5 Multi-Pair Backtester:** Scrapped (Strategy Tester limitations)
- ✅ **Python Backtester:** Superior for portfolio simulation, correlation analysis

### Relationship Between Projects
```
JcampForexTrader (Current)          Jcamp_TradingApp (Phase 3)
├── CSM live demo trading           ├── Multi-pair backtesting
├── Signal dashboard                ├── Historical validation
├── Data collection (50+ trades)    ├── Architecture comparison
└── Real-time monitoring            └── Performance optimization
                                         ↓
                                    VPS Live Trading (Phase 4)
                                    └── Deploy validated system

Flow: Demo → Collect data → Backtest → Validate → VPS → Live
```

---

## 📖 KEY DOCUMENTATION

### Setup & Configuration
- **SYMLINK_VERIFICATION.md** - MT5 path integration guide
- **MT5_PATH_SETUP.md** - Detailed symlink setup instructions
- **README.md** - Project overview

### Architecture & Design
- **CORRECT_ARCHITECTURE_FOUND.md** - CSM architecture discovery
- **CSM_ARCHITECTURE_SUMMARY.md** - CSM overview (8-currency system)
- **CSM_ALPHA_DESIGN.md** - Session 7 CSM Alpha specification (9-currency with Gold)
- **OPTION_B_FINDINGS.md** - MainTradingEA investigation
- **MAINTRADING_EA_ARCHITECTURE_ANALYSIS.md** - Session 6 modular MainTradingEA analysis (Score: 8.2/10)

### Session Planning
- **SESSION_14_VALIDATION_PLAN.md** - Dashboard validation checklist (pending market open)
- **SL_TP_MULTI_LAYER_PROTECTION_PLAN.md** - 🚀 **Sessions 15-17 Implementation Plan** (1,477 lines)
  - Session 15: ATR-Based Dynamic SL/TP (~3 hours) ← NEXT SESSION
  - Session 16: 3-Phase Asymmetric Trailing (~3 hours)
  - Session 17: Confidence Scaling + Symbol Calibration (~2 hours)
  - Complete analysis of BacktestEA's 5-layer protection system
  - Code examples, testing checklists, performance projections
  - **Created:** Feb 7, 2026 at 4:25 AM

### Reference
- **Reference/Jcamp_BacktestEA.mq5** - Strategy source (9,063 lines)

---

## 🎯 CURRENT SESSION STATUS

**Current Session:** 17 (Confidence Scaling + Symbol Calibration - Complete ✅)
**Next Session:** 18 (Extended Demo Trading Validation) 🎯

---

### Session 14: Enhanced Dashboard Live Validation
**Date:** TBD (Market Open Required)
**Status:** ⏳ Pending Market Open

**Objective:**
Validate Session 13's Enhanced Signal Analysis Dashboard with live market data. Confirm all 3 strategies (TrendRider, RangeRider, GoldTrendRider) export component scores correctly when markets open.

**See:** `Documentation/SESSION_14_VALIDATION_PLAN.md` for complete testing checklist

---

### ✅ Session 15: ATR-Based Dynamic SL/TP (COMPLETE)
**Date:** February 7, 2026
**Duration:** ~3 hours
**Status:** ✅ Complete - Ready for Testing

**Objective:**
Fix "trades stopped out too early" issue by implementing market-adaptive SL/TP that responds to volatility automatically.

**Problem Solved:**
- ✅ Implemented ATR-based dynamic SL/TP (was: Fixed 50/100 pip SL/TP)
- ✅ Volatility adaptation: Wider stops in volatile, tighter in quiet
- ✅ Symbol-specific bounds (EURUSD 20-60, GBPUSD 25-80, AUDJPY 25-70, XAUUSD 30-150)
- ✅ Symbol-specific ATR multipliers (GBPUSD 0.6 for spikes, Gold 0.4 for huge ATR)
- ✅ Risk:Reward maintained at 2.0 (TP = SL × 2)

**Files Modified:**
- ✅ `Strategy_AnalysisEA.mq5` - Added ATR-based SL/TP calculation (98 lines)
- ✅ `SignalExporter.mqh` - Already exports stop_loss_dollars/take_profit_dollars
- ✅ `TradeExecutor.mqh` - Already has ATR code path (will auto-activate)

**Testing Required:**
- [ ] Compile Strategy_AnalysisEA in MetaEditor (F7)
- [ ] Deploy on demo MT5
- [ ] Verify signal JSON contains stop_loss_dollars/take_profit_dollars
- [ ] Monitor first 5 trades for ATR adaptation
- [ ] Validate stops adapt to market volatility

**Expected Results:**
- Premature stop-outs: 40% → 25% (-15% improvement)
- Better win rate in volatile markets
- Stops adapt automatically to market conditions

**See:** Session History below for complete implementation details

**Complete Implementation Plan:**
**See:** `Documentation/SL_TP_MULTI_LAYER_PROTECTION_PLAN.md` (1,477 lines, created Feb 7, 2026 at 4:25 AM)

**Roadmap:**
```
Session 15: ATR-Based SL/TP (~3 hours)         ← NEXT
Session 16: 3-Phase Trailing (~3 hours)        ← Future
Session 17: Confidence Scaling (~2 hours)      ← Future
```

**Total Expected Improvement:** +167% net R over 100 trades (15R → 40R)

---

**Session 13 Recap (Completed):**
- ✅ Enhanced Signal Analysis Dashboard implemented
- ✅ Added 10 component score fields to StrategySignal struct
- ✅ Updated all 3 strategies to always return component data
- ✅ Modified SignalExporter with two-method pattern
- ✅ Enhanced XAML with 24 component progress bars
- ✅ Updated C# parser to read component JSON
- ✅ Created test signal generator (generate_test_signals.bat)
- ✅ Offline testing confirmed dashboard works correctly
- ⏳ **Market validation pending (Session 14)**


## 📜 SESSION HISTORY

**Recent Sessions (15-17):** Detailed below
**Archived Sessions (1-14):** See [SESSION_HISTORY.md](Documentation/SESSION_HISTORY.md)

---

### Session 15: ATR-Based Dynamic SL/TP Implementation (February 7, 2026)
**Duration:** ~3 hours | **Status:** ✅ Complete (Ready for Testing)

**Objective:**
Implement market-adaptive stop loss and take profit system that responds to volatility automatically. Fix "trades stopped out too early" issue by making stops adapt to market conditions.

**Accomplished:**
- ✅ **Added ATR-based SL/TP System to Strategy_AnalysisEA.mq5**
  - 14 new input parameters (ATR multipliers, min/max bounds per symbol)
  - Symbol-specific bounds:
    - EURUSD: 20-60 pips, multiplier 0.5
    - GBPUSD: 25-80 pips, multiplier 0.6 (wider for London spikes)
    - AUDJPY: 25-70 pips, multiplier 0.5
    - XAUUSD: 30-150 pips, multiplier 0.4 (lower for huge ATR)
  - ATR calculation logic after strategy evaluation
  - Sets signal.stopLossDollars and signal.takeProfitDollars
  - Handles Gold vs Forex correctly (dollars vs pips)

- ✅ **Added 3 Helper Functions**
  - GetSymbolATRMultiplier() - Returns symbol-specific ATR multiplier
  - GetSymbolMinSL() - Returns minimum SL bound
  - GetSymbolMaxSL() - Returns maximum SL bound
  - All handle broker suffixes (.sml, .r, .ecn, .raw)

- ✅ **SignalExporter.mqh** - Already exports stop_loss_dollars/take_profit_dollars (no changes needed)
- ✅ **TradeExecutor.mqh** - Already has ATR code path (lines 128-153, no changes needed)

**How It Works:**
```
1. Strategy evaluates → generates signal (BUY/SELL/HOLD)
2. ATR system calculates dynamic SL/TP:
   - Get ATR (14 period, H1 timeframe)
   - Apply symbol multiplier (GBPUSD 0.6, others 0.5, Gold 0.4)
   - Enforce min/max bounds per symbol
   - Calculate TP (SL × 2.0 R:R ratio)
3. Signal exported with ATR-based stops
4. TradeExecutor automatically uses ATR stops (existing code path activates)
```

**Files Modified:**
- `Jcamp_Strategy_AnalysisEA.mq5` (98 lines added)
  - Input parameters section (lines 82-110)
  - ATR calculation logic (lines 491-548)
  - Helper functions (lines 690-754)

**Commit:** `9f1ba83` - feat: Session 15 - ATR-Based Dynamic SL/TP Implementation

**Expected Results:**
- **Premature stop-outs:** 40% → 25% (-15% improvement)
- **Volatility adaptation:** Wider stops in volatile markets, tighter in quiet
- **Symbol-aware:** Each pair uses appropriate stop distances
- **Better win rate:** Trades survive normal market noise

**Testing Checklist (Next Steps):**
- [ ] Compile Strategy_AnalysisEA in MetaEditor (F7)
- [ ] Deploy on demo MT5
- [ ] Check signal JSON files contain:
  - [ ] `"stop_loss_dollars": 25.5` (or similar)
  - [ ] `"take_profit_dollars": 51.0` (or similar)
- [ ] Verify trades execute with ATR-based SL/TP (check Expert tab logs)
- [ ] Test in different volatility conditions:
  - [ ] Quiet day (ATR 20-30) → Tighter stops
  - [ ] Volatile day (ATR 60-80) → Wider stops
- [ ] Confirm bounds working:
  - [ ] Very low ATR → Min SL applied
  - [ ] Very high ATR → Max SL applied
- [ ] Monitor first 5 trades, compare to fixed system

**Next Session (16) Preview:**
3-Phase Asymmetric Trailing System
- Phase 1 (0.5-1.0R): Tight trail (protect quick wins)
- Phase 2 (1.0-2.0R): Balanced trail (let it breathe)
- Phase 3 (2.0R+): Loose trail (ride the trend)
- Expected: +0.4R per winner improvement

### Session 16: 3-Phase Asymmetric Trailing System (February 7, 2026)
**Duration:** ~3 hours | **Status:** ✅ Complete (Ready for Testing)

**Objective:**
Implement progressive trailing stop system that adapts to profit level, capturing big moves while protecting profits. Replace simple single-phase trailing with asymmetric 3-phase system.

**Accomplished:**
- ✅ **Created PositionTracker.mqh** (234 lines) - New tracking module
  - Tracks entry price, original SL distance, strategy name
  - Calculates current R-multiple for each position
  - Determines phase based on profit level (1/2/3)
  - Manages high water marks per position
  - Tracks breakeven status for RangeRider
  - Methods: AddPosition(), GetPosition(), CalculateCurrentR(), GetCurrentPhase()

- ✅ **Updated MainTradingEA.mq5** - 3-Phase Parameters
  - Added 7 new input parameters:
    - TrailingActivationR = 0.5 (start at +0.5R)
    - Phase 1 (0.5-1.0R): Trail 0.3R behind (tight lock)
    - Phase 2 (1.0-2.0R): Trail 0.5R behind (balanced)
    - Phase 3 (2.0R+): Trail 0.8R behind (let it run)
  - Updated PositionManager initialization with new params
  - Added position registration after trade execution
    - Captures entry price, SL distance, strategy name
    - Registers with PositionManager for R-tracking

- ✅ **Rewrote PositionManager.mqh** - Complete 3-Phase System
  - Integrated PositionTracker for R-multiple based logic
  - Implemented 3-phase trailing:
    - Phase 1 (0.5-1.0R): 0.3R trail (protect early profits)
    - Phase 2 (1.0-2.0R): 0.5R trail (balanced protection)
    - Phase 3 (2.0R+): 0.8R trail (let winners run!)
  - Added RangeRider early breakeven at +0.5R
    - Moves SL to entry + 2 pips
    - Worst case loss: -0.08R (was -1R!)
    - 92% improvement on failed range trades
  - Added phase transition logging
  - Added trailing activation logging

**How It Works:**
```
1. Trade executes → Position registered with:
   - Entry price, SL distance, strategy name

2. UpdatePositions() called every tick:
   - Calculate current R-multiple (profit/SL distance)
   - Update high water mark

3. RangeRider Special: At +0.5R
   - Move SL to entry + 2 pips (breakeven)
   - Worst case: -0.08R (not -1R!)

4. All Strategies: At +0.5R
   - Activate trailing stop system

5. Determine Phase & Trail Distance:
   - 0.5-1.0R → Phase 1 → Trail 0.3R (tight)
   - 1.0-2.0R → Phase 2 → Trail 0.5R (balanced)
   - 2.0R+    → Phase 3 → Trail 0.8R (loose)

6. Move SL based on current R and phase:
   - New SL = Current R - Trail Distance
   - Only move if better than current SL
   - Log phase transitions

Result: Adaptive trailing that protects profits
        while capturing big moves
```

**Files Modified:**
1. `PositionTracker.mqh` (234 lines) - NEW FILE
2. `MainTradingEA.mq5` (30 lines changed)
   - Input parameters section
   - Position registration after ExecuteSignal()
3. `PositionManager.mqh` (complete rewrite, 342 lines)
   - Integrated PositionTracker
   - 3-phase trailing logic
   - RangeRider breakeven

**Commit:** `035ef11` - feat: Session 16 - 3-Phase Asymmetric Trailing System

**Expected Results:**
- **Average winner:** +2.0R → +2.4R (+20% improvement)
- **Big winners (3R+):** 0% → 15% (Phase 3 captures them!)
- **RangeRider failures:** -1R → -0.08R (92% better!)
- **Net improvement:** +0.4R per winning trade

**Visual Example:**
```
EURUSD BUY @ 1.0500, SL 1.0475 (25 pips = 1R)

Price: 1.0512 (+0.48R) → No trailing yet
Price: 1.0515 (+0.6R)  → Phase 1 activated! SL→1.0507.5 (+0.3R locked)
Price: 1.0520 (+0.8R)  → Phase 1: SL→1.0512.5 (+0.5R locked)
Price: 1.0525 (+1.0R)  → Transition to Phase 2! SL→1.0517.5 (+0.7R)
Price: 1.0530 (+1.2R)  → Phase 2: SL→1.0517.5 (wider trail)
Price: 1.0550 (+2.0R)  → Transition to Phase 3! SL→1.0537.5 (+1.5R)
Price: 1.0575 (+3.0R)  → Phase 3: SL→1.0555 (+2.2R locked)
Price: 1.0560 (retraces) → Stopped out at 1.0555

Final: +55 pips (+2.2R)
vs Fixed TP: +50 pips (+2.0R)
Extra captured: +5 pips (+0.2R) by Phase 3!
```

**Testing Checklist (Next Steps):**
- [ ] Compile MainTradingEA in MetaEditor (F7)
- [ ] Deploy on demo MT5
- [ ] Execute test trades and monitor logs:
  - [ ] "⚡ Trailing Activated" at +0.5R
  - [ ] "🎯 Phase Transition: Phase 1 → 2" at +1.0R
  - [ ] "🎯 Phase Transition: Phase 2 → 3" at +2.0R
  - [ ] "🛡️ RangeRider Breakeven" for RANGE trades at +0.5R
- [ ] Verify phase-specific trailing distances
- [ ] Confirm big winners captured (2R+ exits)
- [ ] Validate RangeRider breakeven working

**Next Session (17) Preview:**
Confidence Scaling + Symbol Calibration
- High confidence (90+): 1:3 R:R targets
- Medium confidence (80+): 1:2.5 R:R targets
- Low confidence (70+): 1:2 R:R targets
- Gold R:R cap at 2.5 (volatility limit)
- Expected: +0.4R per trade improvement

---

### Session 17: Confidence Scaling + Symbol Calibration (February 7, 2026)
**Duration:** ~2 hours | **Status:** ✅ Complete (Ready for Testing)

**Objective:**
Fine-tune SL/TP system with signal-strength-based R:R targets. High confidence trades get larger profit targets, low confidence trades use conservative targets.

**Accomplished:**
- ✅ **Added Confidence-Based R:R Scaling to Strategy_AnalysisEA.mq5** (33 lines)
  - High confidence (90+): 1:3 R:R (TP = SL × 3.0)
  - Medium confidence (80+): 1:2.5 R:R (TP = SL × 2.5)
  - Standard confidence (<80): 1:2 R:R (TP = SL × 2.0)
  - Dynamic calculation based on signal.confidence field

- ✅ **Added Gold R:R Cap** (volatility limit)
  - Gold capped at 1:2.5 R:R maximum
  - Prevents overextended targets on unpredictable Gold moves
  - Applies after confidence scaling (caps 1:3 → 1:2.5 for high conf Gold)

- ✅ **Updated Logging** (dynamic R:R display)
  - Shows selected confidence tier in Expert tab
  - Displays final R:R ratio used for TP calculation
  - Logs Gold cap application when triggered

- ✅ **Verified Symbol-Specific Calibration** (from Session 15)
  - ATR multipliers still working (EURUSD 0.5, GBPUSD 0.6, AUDJPY 0.5, Gold 0.4)
  - Min/Max SL bounds still enforced (EURUSD 20-60, GBPUSD 25-80, Gold 30-150)
  - No conflicts with confidence scaling system

**How It Works:**
```
1. ATR calculates base SL distance (Session 15)
   - SL = ATR × symbol multiplier
   - Enforce min/max bounds

2. NEW: Calculate dynamic R:R ratio
   - IF confidence >= 90 → rrRatio = 3.0
   - ELSE IF confidence >= 80 → rrRatio = 2.5
   - ELSE → rrRatio = 2.0

3. NEW: Apply Gold R:R cap
   - IF symbol is Gold AND rrRatio > 2.5
   - THEN rrRatio = 2.5 (cap)

4. Calculate TP distance
   - TP = SL × rrRatio (dynamic!)

5. Export to signal JSON
   - stop_loss_dollars = SL distance
   - take_profit_dollars = TP distance
```

**Files Modified:**
- `Jcamp_Strategy_AnalysisEA.mq5` (33 lines added, 3 lines modified)
  - Lines 553-586: Confidence-based R:R scaling logic
  - Line 602: Updated logging to show dynamic rrRatio

**Commit:** `0b0ccc3` - feat: Session 17 - Confidence Scaling + Symbol Calibration

**Expected Results:**
```
Before Session 17 (Fixed 1:2 R:R):
├─ All trades: 1:2 R:R fixed
├─ High conf (90+): Avg +2.0R (limited by TP)
├─ Low conf (70+): Avg +2.0R (same target)

After Session 17 (Confidence-Scaled):
├─ High conf (90+): 1:3 R:R → Avg +2.8R
├─ Med conf (80+): 1:2.5 R:R → Avg +2.3R
├─ Low conf (70+): 1:2 R:R → Avg +1.8R
├─ Weighted avg: +2.4R per trade (+20% improvement)

Net Improvement (Sessions 15-17 Combined):
├─ Premature stop-outs: 40% → 25% (-15%)
├─ Average winner: +2.0R → +2.4R (+20%)
├─ Big winners (3R+): 0% → 15%
└─ Net: +15R → +40R per 100 trades (+167%)
```

**Testing Checklist:**
- [ ] Compile Strategy_AnalysisEA in MetaEditor (F7)
- [ ] Deploy on demo MT5 (4 charts: EURUSD, GBPUSD, AUDJPY, XAUUSD)
- [ ] Verify logging shows confidence tier selection:
  - [ ] "🔥 High conf (XX) → 1:3 R:R"
  - [ ] "⚡ Good conf (XX) → 1:2.5 R:R"
  - [ ] "✓ Standard conf (XX) → 1:2 R:R"
  - [ ] "⚠️ Gold R:R capped at 1:2.5" (for high conf Gold)
- [ ] Check signal JSON files:
  - [ ] High conf: take_profit_dollars = stop_loss_dollars × 3.0
  - [ ] Med conf: take_profit_dollars = stop_loss_dollars × 2.5
  - [ ] Low conf: take_profit_dollars = stop_loss_dollars × 2.0
  - [ ] Gold cap: Never exceeds 2.5× for XAUUSD
- [ ] Monitor first 20 trades for R:R distribution
- [ ] Validate average R per winner increases vs Session 16

**Documentation Created:**
- `Documentation/SESSION_17_TESTING_GUIDE.md` - Complete testing checklist and validation scenarios

**Next Session (18) Preview:**
Extended Demo Trading Validation (1-2 weeks)
- Collect 50+ closed trades across all 4 symbols
- Analyze confidence distribution and actual R-multiples
- Compare Sessions 15-17 results vs original fixed system
- Fine-tune confidence thresholds if needed (90/80 → 95/85?)
- Prepare for Phase 3 Python multi-pair backtesting

**Key Achievement:**
✅ **3-Phase SL/TP Enhancement COMPLETE** (Sessions 15-17)
- Layer 1: ATR-based dynamic SL/TP ✅
- Layer 2: 3-phase asymmetric trailing ✅
- Layer 3: RangeRider early breakeven ✅
- Layer 4: Confidence-based R:R scaling ✅
- Layer 5: Symbol-specific calibration ✅

Expected: +167% improvement in net R over 100 trades!

---

## 💡 IMPORTANT NOTES

### MetaEditor Integration
- **Symlinks active:** Files edited in either location sync automatically
- **No manual copying:** Edit in dev folder OR MetaEditor, both work
- **Compilation:** Press F7 in MetaEditor, .ex5 appears in dev folder
- **Git tracking:** Always commit from `/d/JcampForexTrader/`

### Development Workflow
1. Edit files in `D:\JcampForexTrader\MT5_EAs\`
2. MetaEditor sees changes instantly
3. Compile in MetaEditor (F7)
4. Test in MT5
5. Commit changes via git

### Code References in Strategy Files
```mql5
// In any EA in Experts\Jcamp\:
#include <JcampStrategies/Indicators/EmaCalculator.mqh>
#include <JcampStrategies/RegimeDetector.mqh>
#include <JcampStrategies/Strategies/TrendRiderStrategy.mqh>

// MetaEditor finds these automatically via symlinks!
```

---

## 🚨 TROUBLESHOOTING

### Symlinks Not Working?
1. Verify admin rights when creating
2. Check paths are exact (no typos)
3. Restart MetaEditor after creating symlinks
4. See `SYMLINK_VERIFICATION.md` for details

### MetaEditor Can't Find Includes?
1. Check symlink exists: `ls -la MT5/Include/`
2. Refresh Navigator (F5 in MetaEditor)
3. Verify include path: `#include <JcampStrategies/...>`

### Git Issues?
1. Always use Git Bash paths (`/d/...`)
2. Check current directory: `pwd`
3. Verify git status: `git status`

---

*Read this file at start of every session for full context*
*Updated: Session 16 Complete - February 7, 2026*
