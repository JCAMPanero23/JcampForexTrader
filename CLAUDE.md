# CLAUDE.md - JcampForexTrader Context

**Purpose:** Single authoritative reference for Claude Code
**Project:** CSM-based forex trading system with modular strategies
**Last Updated:** January 22, 2026 (Session 6 Complete - MainTradingEA Modular Implementation)

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

## 🎯 CURRENT PHASE: Strategy Extraction (Phase 1)

**Status:** ✅ Repository Setup Complete | 🚀 Ready to Extract Strategies

**Session 1 Completed (January 18, 2026):**
- ✅ New repository created at `/d/JcampForexTrader/`
- ✅ Clean folder structure created
- ✅ BacktestEA.mq5 copied as reference (9,063 lines)
- ✅ Documentation migrated from old project
- ✅ Symlinks created and verified (MetaEditor integration working)
- ✅ Git repository initialized (3 commits)
- ✅ MT5 path integration complete

**Next Session Tasks:**
1. Extract indicators from BacktestEA.mq5 (4-6 hours)
   - [ ] EmaCalculator.mqh
   - [ ] AtrCalculator.mqh
   - [ ] AdxCalculator.mqh
   - [ ] RsiCalculator.mqh

2. Extract regime detection logic (3-4 hours)
   - [ ] RegimeDetector.mqh (100-point scoring)

3. Extract strategies (6-8 hours)
   - [ ] TrendRiderStrategy.mqh (135-point system)
   - [ ] RangeRiderStrategy.mqh

---

## 🏗️ CSM ARCHITECTURE

### Data Flow
```
MT5 Terminal
    ↓
Jcamp_CSM_AnalysisEA.mq5
    ↓ (writes every 15 min)
csm_current.txt (currency strengths)
    ↓
Jcamp_Strategy_AnalysisEA.mq5 (per pair)
    ↓ (writes every 15 min)
EURUSD_signals.json, GBPUSD_signals.json, etc.
    ↓
Jcamp_MainTradingEA.mq5
    ↓ (executes trades)
trade_history.json, positions.txt, performance.txt
    ↓ (reads every 5 sec)
CSMMonitor.exe (C# Dashboard)
```

### Key Components

**1. Jcamp_CSM_AnalysisEA.mq5**
- Calculates currency strengths (8 currencies)
- Exports to csm_current.txt
- Runs once (any chart)
- **Status:** Exists in old repo, needs copying

**2. Jcamp_Strategy_AnalysisEA.mq5** (MODULAR VERSION)
- Evaluates strategies per pair
- Uses modular .mqh includes
- Exports to {SYMBOL}_signals.json
- Runs per pair (EURUSD, GBPUSD, GBPNZD charts)
- **Status:** ✅ Complete with Phase 4E dynamic regime detection

**3. Jcamp_MainTradingEA.mq5** (MODULAR VERSION)
- Reads all signal files
- Executes trades with risk management
- Manages positions & trailing stops
- Exports history/performance
- **Status:** ✅ Complete with 4 core trading modules

**4. CSMMonitor.exe**
- Reads all exported files
- Displays live dashboard
- 5-second auto-refresh
- **Status:** Revert to commit 567d05c from old repo

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

### Phase 1: Local Development (CURRENT - Weeks 1-2)
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
- [ ] Copy CSM_AnalysisEA from old repo (Session 7 - ~1 hour)
- [ ] Test complete CSM architecture on demo (Session 7 - ~2 hours)
- [ ] Create BacktestEA_v2 for module validation (4-6 hours - DEFERRED)

**Total Estimated Time:** 20-29 hours
**Completed:** ~16.5 hours | **Remaining:** ~3.5-12.5 hours (Phase 1 nearly complete!)
### Phase 2: Local Testing (Weeks 3-4)
- [ ] Copy CSM_AnalysisEA from old repo
- [ ] Deploy CSM architecture on local MT5 demo
- [ ] Validate signals vs backtest results
- [ ] Manual trading based on signals (1-2 weeks)
- [ ] Fine-tune confidence thresholds

### Phase 3: VPS Deployment (Week 5)
- [ ] Setup Forex VPS (Vultr recommended, $12/month)
- [ ] Install Windows Server 2022
- [ ] Install MT5 on VPS
- [ ] Deploy CSM architecture remotely
- [ ] Setup file sync for C# Monitor
- [ ] Verify 24/7 operation

### Phase 4: Live Trading (Weeks 6+)
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

### D:\Jcamp_TradingApp (Phase 8 - Paused)
- **Status:** Complete, on hold for CSM focus
- **Content:** Phase 8 multi-pair backtesting (Python + C#)
- **Purpose:** Advanced backtesting & visualization
- **When to Resume:** After CSM live trading validated (2-4 months)

**Phase 8 Work Preserved:**
- Python backtesting engine (30/31 tests passing)
- C# chart viewer with playback
- Multi-pair support (EURUSD, GBPUSD, GBPNZD)
- All bugs documented for future fixes

### Relationship Between Projects
```
JcampForexTrader (Current)          Jcamp_TradingApp (Future)
├── CSM live trading                ├── Multi-pair backtesting
├── VPS deployment                  ├── Python strategy brain
├── Real-time signals               ├── Advanced visualization
└── 24/7 operation                  └── Strategy optimization

Flow: Test strategies in CSM → Refine in backtesting → Deploy live
```

---

## 📖 KEY DOCUMENTATION

### Setup & Configuration
- **SYMLINK_VERIFICATION.md** - MT5 path integration guide
- **MT5_PATH_SETUP.md** - Detailed symlink setup instructions
- **README.md** - Project overview

### Architecture & Design
- **CORRECT_ARCHITECTURE_FOUND.md** - CSM architecture discovery
- **CSM_ARCHITECTURE_SUMMARY.md** - CSM overview
- **OPTION_B_FINDINGS.md** - MainTradingEA investigation
- **MAINTRADING_EA_ARCHITECTURE_ANALYSIS.md** - Session 6 modular MainTradingEA analysis (Score: 8.2/10)

### Reference
- **Reference/Jcamp_BacktestEA.mq5** - Strategy source (9,063 lines)

---

## 🎯 CURRENT SESSION STATUS

**Session:** 7 (CSM Integration & Testing)
**Date:** January 22, 2026
**Duration:** Not Started
**Status:** 📋 Ready to Begin

**Objective:**
Complete Phase 1 by integrating CSM_AnalysisEA and testing the full architecture

**Planned Tasks:**
1. Copy Jcamp_CSM_AnalysisEA.mq5 from old repository
2. Test compilation and verify it works with new architecture
3. Deploy complete CSM architecture on demo account:
   - CSM_AnalysisEA on any chart (generates csm_current.txt)
   - Strategy_AnalysisEA on EURUSD, GBPUSD, GBPNZD charts
   - MainTradingEA on any chart (reads signals, executes trades)
4. Verify data flow: CSM → Strategies → Signals → Trades → Exports
5. Validate file exports for C# Monitor integration

**Next Steps:**
- Locate CSM_AnalysisEA in old repo
- Copy and test CSM_AnalysisEA
- Full system integration test
- Phase 1 completion!


## 📜 SESSION HISTORY

### Session 1: Setup & Configuration (January 18, 2026)
**Duration:** ~2 hours | **Status:** ✅ Complete

**Accomplished:**
- Created new clean repository
- Setup folder structure
- Migrated documentation
- Created MT5 symlinks (verified working)
- Git initialized

**Commits:** `a9d15ce`, `621d1d2`, `25f2f10`

### Session 2: Indicator & Regime Extraction (January 19, 2026)
**Duration:** ~2.5 hours | **Status:** ✅ Complete

**Accomplished:**
- Extracted 4 indicator modules (EMA, ATR, ADX, RSI)
- Extracted regime detection module (100-point scoring)
- Created modular .mqh architecture
- Designed stateless multi-pair support

**Commits:** `d82731c`, `1571276`

### Session 3: Strategy Extraction (January 19, 2026)
**Duration:** ~3 hours | **Status:** ✅ Complete

**Accomplished:**
- Created IStrategy interface for polymorphic strategy support
- Extracted TrendRiderStrategy (135-point confidence system)
- Extracted RangeRiderStrategy (100-point confidence system)
- Created SignalExporter for JSON signal export
- All modules support multi-pair analysis

**Commit:** `5f03464`

### Session 4: Strategy Analysis EA - Modular Implementation (January 19, 2026)
**Duration:** ~2.5 hours | **Status:** ✅ Complete

**Accomplished:**
- Created Jcamp_Strategy_AnalysisEA.mq5 (750 lines)
- Embedded BacktestEA's exact CSM calculation logic
- Integrated all modular components (Indicators, RegimeDetector, Strategies)
- Fixed compilation issues (functions vs classes)
- Successfully compiled (0 errors, 3 warnings)
- CSM export for C# monitoring implemented

**Files:** `MT5_EAs/Experts/Jcamp_Strategy_AnalysisEA.mq5`
**Commits:** `4fdb2ea`, `c3d1f73`, `7603530`, `43ea5c3` (includes Session 5 enhancements)

### Session 5: Testing & Phase 4E Dynamic Regime Detection (January 21, 2026)
**Duration:** ~2.5 hours | **Status:** ✅ Complete

**Accomplished:**
- Tested Jcamp_Strategy_AnalysisEA on live EURUSD H1 chart
- Verified signal generation and file exports working
- Added Phase 4E dynamic regime detection (5-120 min adaptive intervals)
- Implemented verbose logging for regime change tracking
- Fixed dynamic check timing logic (moved before analysis throttle)
- Validated CSM calculations and strategy scoring

**Commits:** `4fdb2ea`, `c3d1f73`, `7603530`, `43ea5c3`

**Key Features Added:**
- Dynamic regime detection with DynamicRegimeMinIntervalMinutes (default: 5)
- Verbose logging mode (`VerboseLogging=true`) for debugging
- Timer-based dynamic checks independent of 15-min analysis throttle
- Clear log messages showing ADX values and regime transitions

### Session 6: MainTradingEA - Modular Implementation (January 21-22, 2026)
**Duration:** ~3 hours | **Status:** ✅ Complete

**Accomplished:**
- Created modular Jcamp_MainTradingEA.mq5 (267 lines)
- Built 4 core trading modules:
  - **SignalReader.mqh** - Multi-symbol JSON signal parsing
  - **TradeExecutor.mqh** - Risk-managed trade execution
  - **PositionManager.mqh** - Position tracking & trailing stops
  - **PerformanceTracker.mqh** - Trade history & performance export
- Implemented complete signal-to-trade pipeline
- Added comprehensive risk management (position limits, spread checks, confidence filters)
- Created performance export system for C# Monitor integration
- Successfully compiled with 0 errors
- **Generated comprehensive architecture analysis** (MAINTRADING_EA_ARCHITECTURE_ANALYSIS.md)
  - Overall score: 8.2/10
  - Identified critical issue: Fixed SL/TP needs dynamic ATR-based calculation
  - Validated all 4 trading modules
  - Provided demo testing checklist

**Commits:** `e5d8d7b`, `d478c14`

**Key Features:**
- Multi-symbol signal reading (EURUSD, GBPUSD, GBPNZD)
- Configurable risk management (1% per trade default)
- Position limits (per symbol & total)
- Trailing stop management
- JSON exports: trade_history.json, positions.txt, performance.txt
- Verbose logging for debugging

**Critical Finding:**
- 🚨 Must implement dynamic SL/TP before live trading (currently fixed at 50/100 pips)

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
*Updated: Session 6 Complete - January 22, 2026*
