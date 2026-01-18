# JcampForexTrader - CSM Architecture

**Purpose:** Production forex trading system using Currency Strength Meter (CSM) architecture

**Status:** In Development - Extracting strategies from BacktestEA

---

## 🏗️ Architecture Overview

```
MT5 Terminal
├── Jcamp_CSM_AnalysisEA.mq5 (1 instance)
│   └─→ Writes: csm_current.txt
│
├── Jcamp_Strategy_AnalysisEA.mq5 (Per-pair instances)
│   ├─→ EURUSD chart → EURUSD_signals.json
│   ├─→ GBPUSD chart → GBPUSD_signals.json
│   └─→ GBPNZD chart → GBPNZD_signals.json
│
└── Jcamp_MainTradingEA.mq5 (1 instance)
    ├─→ Reads: *_signals.json files
    ├─→ Executes trades
    └─→ Writes: trade_history.json, positions.txt, performance.txt
          ↓
    CSMMonitor.exe (C# WPF App)
    └─→ Reads all files, displays dashboard
```

---

## 📁 Project Structure

```
D:\JcampForexTrader\
├── MT5_EAs/                    # MQ5 Expert Advisors
│   ├── Experts/               # Main EA files
│   └── Include/               # Strategy modules (.mqh)
│       └── JcampStrategies/
│           ├── Indicators/    # EMA, ATR, ADX, RSI
│           ├── Strategies/    # Trend Rider, Range Rider
│           └── RegimeDetector.mqh
│
├── CSMMonitor/                # C# WPF Dashboard
│
├── Documentation/             # Architecture & guides
│
└── Reference/                 # Reference implementations
    └── Jcamp_BacktestEA.mq5  # Source for strategy extraction
```

---

## 🎯 Development Phases

### Phase 1: Strategy Extraction (Current)
- [ ] Extract indicators from BacktestEA
- [ ] Extract regime detection logic
- [ ] Extract Trend Rider strategy
- [ ] Extract Range Rider strategy
- [ ] Create modular .mqh files

### Phase 2: Strategy_AnalysisEA Update
- [ ] Update to use modular strategies
- [ ] Implement JSON export
- [ ] Test signal generation

### Phase 3: Local Testing
- [ ] Deploy on local MT5 (demo account)
- [ ] Validate signals vs backtest results
- [ ] Manual trading based on signals

### Phase 4: VPS Deployment
- [ ] Setup Forex VPS
- [ ] Deploy CSM architecture
- [ ] Setup file sync for monitoring

### Phase 5: Live Trading
- [ ] Start with micro lots
- [ ] Monitor performance
- [ ] Gradual position sizing

---

## 🔗 Related Projects

**D:\Jcamp_TradingApp** - Phase 8 multi-pair backtesting (Python + C#)
- Status: Complete, on hold for future development
- Purpose: Advanced backtesting & visualization

---

## 📊 Key Design Principles

1. **Modular Strategies**: Separate .mqh files for each component
2. **CSM Integration**: Currency strength confirmation for all signals
3. **Multi-Pair Support**: Independent strategy instances per pair
4. **24/7 Operation**: Designed for VPS hosting
5. **Risk Management**: Position sizing, stop losses, trailing stops

---

*Last Updated: January 18, 2026*
