# CLAUDE.md - JcampForexTrader Context

**Purpose:** Single authoritative reference for Claude Code
**Project:** CSM-based forex trading system with modular strategies
**Last Updated:** January 18, 2026

---

## 🚨 CRITICAL - PATH CONFIGURATION

**Environment:** Windows 11 + Git Bash
**Shell Type:** Git Bash (MINGW64)

### Path Format Rules

**ALWAYS use Git Bash paths:**
```bash
/d/JcampForexTrader/
/d/JcampForexTrader/MT5_EAs/
/d/JcampForexTrader/CSMMonitor/
```

**NEVER use:**
- ❌ `D:\JcampForexTrader\` (Windows paths)
- ❌ `/mnt/d/` (WSL paths)

---

## 📁 PROJECT STRUCTURE

```
/d/JcampForexTrader/
├── CLAUDE.md                          # This file
├── README.md                          # Project overview
│
├── MT5_EAs/                          # MQ5 Expert Advisors
│   ├── Experts/
│   │   ├── Jcamp_CSM_AnalysisEA.mq5
│   │   ├── Jcamp_Strategy_AnalysisEA.mq5
│   │   └── Jcamp_MainTradingEA.mq5
│   │
│   └── Include/
│       └── JcampStrategies/
│           ├── Indicators/
│           │   ├── EmaCalculator.mqh
│           │   ├── AtrCalculator.mqh
│           │   ├── AdxCalculator.mqh
│           │   └── RsiCalculator.mqh
│           ├── RegimeDetector.mqh
│           ├── Strategies/
│           │   ├── IStrategy.mqh
│           │   ├── TrendRiderStrategy.mqh
│           │   └── RangeRiderStrategy.mqh
│           └── SignalExporter.mqh
│
├── CSMMonitor/                       # C# WPF Dashboard
│   └── JcampForexTrader/
│       ├── MainWindow.xaml
│       └── MainWindow.xaml.cs
│
├── Documentation/
│   ├── CORRECT_ARCHITECTURE_FOUND.md
│   ├── CSM_ARCHITECTURE_SUMMARY.md
│   └── OPTION_B_FINDINGS.md
│
└── Reference/
    └── Jcamp_BacktestEA.mq5          # 9,063 lines - strategy source
```

---

## 🎯 CURRENT PHASE: Strategy Extraction

**Status:** Setting up clean repository

**Next Steps:**
1. Extract indicators from BacktestEA.mq5
2. Extract regime detection logic
3. Extract Trend Rider strategy (135-point system)
4. Extract Range Rider strategy
5. Create modular .mqh files

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

**2. Jcamp_Strategy_AnalysisEA.mq5** (MODULAR VERSION)
- Evaluates strategies per pair
- Uses modular .mqh includes
- Exports to {SYMBOL}_signals.json
- Runs per pair (EURUSD, GBPUSD, GBPNZD charts)

**3. Jcamp_MainTradingEA.mq5**
- Reads all signal files
- Executes trades
- Manages positions
- Exports history/performance

**4. CSMMonitor.exe**
- Reads all exported files
- Displays live dashboard
- 5-second auto-refresh

---

## 📊 STRATEGY MODULES

### Indicators (Include/JcampStrategies/Indicators/)
- **EmaCalculator.mqh** - EMA 20/50/100
- **AtrCalculator.mqh** - ATR for volatility
- **AdxCalculator.mqh** - Trend strength
- **RsiCalculator.mqh** - Momentum

### Regime Detection (Include/JcampStrategies/)
- **RegimeDetector.mqh** - TRENDING/RANGING/TRANSITIONAL
- 100-point competitive scoring

### Strategies (Include/JcampStrategies/Strategies/)
- **IStrategy.mqh** - Base interface
- **TrendRiderStrategy.mqh** - 135-point confidence system
- **RangeRiderStrategy.mqh** - Support/resistance trading

### Export (Include/JcampStrategies/)
- **SignalExporter.mqh** - JSON file writing

---

## 🎯 DESIGN PRINCIPLES

### 1. Modular Architecture
- Each component in separate .mqh file
- Easy to test independently
- Easy to update/replace

### 2. Strategy Source: BacktestEA
- BacktestEA.mq5 (9,063 lines) is the validated source
- Extract proven logic, don't reinvent
- Maintain calculation accuracy

### 3. CSM Integration
- All strategies use CSM confirmation
- Currency strength > technical indicators
- Filters false signals

### 4. Clean Separation
- Indicators → Regime → Strategies → Signals
- Each layer independent
- Clear data flow

---

## ⚙️ STANDARD COMMANDS

### Git Operations
```bash
cd /d/JcampForexTrader
git status
git log --oneline -5
```

### File Navigation
```bash
# List MT5 EAs
ls -la /d/JcampForexTrader/MT5_EAs/Experts/

# List strategy modules
ls -la /d/JcampForexTrader/MT5_EAs/Include/JcampStrategies/

# View reference EA
cat /d/JcampForexTrader/Reference/Jcamp_BacktestEA.mq5
```

---

## 🚀 DEPLOYMENT PLAN

### Phase 1: Local Development (Current)
- Extract strategies from BacktestEA
- Create modular .mqh files
- Test on local MT5 demo

### Phase 2: Local Testing
- Deploy CSM architecture locally
- Validate signals
- Manual trading based on signals

### Phase 3: VPS Deployment
- Setup Forex VPS (Vultr, $12/month)
- Deploy CSM architecture
- 24/7 operation

### Phase 4: Live Trading
- Start with micro lots (0.01)
- Monitor performance
- Gradual scaling

---

## 📋 SESSION CHECKLIST

### Session Start
- [ ] Read this CLAUDE.md
- [ ] Check git status
- [ ] Review current phase

### During Session
- [ ] Use Git Bash paths
- [ ] Test incrementally
- [ ] Document changes

### Session End
- [ ] Update documentation
- [ ] Commit changes
- [ ] Update this file if needed

---

## 🔗 RELATED PROJECTS

**D:\Jcamp_TradingApp**
- Phase 8 multi-pair backtesting (Python + C#)
- Status: Complete, paused for CSM focus
- Can resume later when CSM is live

---

*Read this file at start of every session for full context*
