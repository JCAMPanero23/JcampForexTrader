# Original CSM Architecture Summary

**Date:** January 18, 2026
**Status:** Ready to revert from Phase 8 multi-pair backtesting

---

## ARCHITECTURE CONFIRMED ✅

### Original CSM Data Flow (Sep-Oct 2025)

```
MT5 Terminal (Demo or Live)
    ↓
Jcamp_CSM_AnalysisEA.mq5 (running on chart)
    ↓ (writes every 15/30/60 minutes)
%APPDATA%\MetaQuotes\Terminal\[ID]\MQL5\Files\CSM_Data\
├── csm_current.txt (currency strength data)
├── EURUSD_signals.json (strategy signals) [if implemented]
├── GBPUSD_signals.json
├── GBPNZD_signals.json
└── account_info.json [if implemented]
    ↓ (reads every 5 seconds)
CSMMonitor.exe (C# WPF app)
    ↓
Live dashboard display
```

---

## CONFIRMED FILES

### ✅ MT5 EA Files (In Parent Repo)
1. **Jcamp_CSM_AnalysisEA.mq5** ✅
   - Located: JcampFxTrading GitHub repo
   - Function: Currency Strength Meter (8 currencies, 15 pairs)
   - Output: `csm_current.txt` in CSM_Data folder
   - Update frequency: 15/30/60 min (configurable)

2. **Jcamp_BacktestEA.mq5** ✅
   - Located: `/d/Jcamp_TradingApp/Jcamp_BacktestEA.mq5` (743KB)
   - Function: Strategy backtesting EA
   - May also write trade/signal data

3. **Jcamp_MainTradingEA.mq5** (in JcampFxTrading repo)
   - Function: Live trading bot
   - May write signal JSON files

### ✅ C# Monitor App (Original Version)
- **Location:** CSMMonitor repo commit `567d05c` (Sep 30, 2025)
- **Project name:** CSMMonitor.sln
- **Files:**
  - `CSMMonitor/MainWindow.xaml` - Dashboard UI
  - `CSMMonitor/MainWindow.xaml.cs` - Data reading logic
  - `CSMMonitor/SignalModels.cs` - Data models

---

## DATA FILES EXPECTED

### File 1: csm_current.txt ✅ CONFIRMED
**Written by:** Jcamp_CSM_AnalysisEA.mq5
**Format:**
```
TIMESTAMP=2026.01.18 14:30
[STRENGTH_VALUES]
EUR=0.75
USD=-0.32
GBP=0.48
JPY=-0.15
AUD=0.22
NZD=-0.08
CAD=0.12
CHF=-0.05

[TREND_DIRECTION]
EUR=UP
USD=DOWN
...

[VOLATILITY_INDEX]
EUR=0.45
USD=0.62
...
```

### File 2: EURUSD_signals.json ⚠️ NEEDS VERIFICATION
**Expected by:** CSMMonitor C# app
**Format:**
```json
{
  "TrendRiderSignal": "BUY",
  "TrendRiderConfidence": 87,
  "TrendRiderReasoning": "Strong uptrend + pullback to EMA20",
  "TrendRiderScores": {
    "ema_alignment": 30,
    "trend_quality": 25,
    "pullback_quality": 32
  },
  "ImpulsePullbackSignal": "HOLD",
  "ImpulsePullbackConfidence": 45,
  "BreakoutRetestSignal": "HOLD",
  "BreakoutRetestConfidence": 30,
  "BestSignal": "BUY",
  "BestConfidence": 87,
  "CsmDifferential": 1.07,
  "CsmTrend": "BULLISH"
}
```

**Question:** Which MT5 EA writes these JSON signal files?
- Option A: Jcamp_MainTradingEA.mq5 (needs verification)
- Option B: Jcamp_BacktestEA.mq5 (needs verification)
- Option C: Needs to be implemented

### File 3: account_info.json ⚠️ NEEDS VERIFICATION
**Expected by:** CSMMonitor C# app
**Format:**
```json
{
  "balance": 10000.00,
  "equity": 10250.00,
  "margin": 200.00,
  "free_margin": 10050.00,
  "margin_level": 5125.00,
  "profit": 250.00
}
```

---

## C# APP FEATURES (Original CSMMonitor)

### Data Loading Functions
```csharp
// In MainWindow.xaml.cs (commit 567d05c)
private void LoadCSMData()
{
    // Reads csm_current.txt
    // Parses currency strengths
}

private void LoadSignalData()
{
    // Reads EURUSD_signals.json
    // Reads GBPUSD_signals.json
    // Reads GBPNZD_signals.json
}

private void LoadAccountInfo()
{
    // Reads account_info.json
}
```

### Auto-Refresh Timer
```csharp
private void InitializeTimer()
{
    refreshTimer = new DispatcherTimer();
    refreshTimer.Interval = TimeSpan.FromSeconds(5);
    refreshTimer.Tick += RefreshTimer_Tick;
    refreshTimer.Start();
}
```

### Auto-Detect MT5 Path
```csharp
string userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
csmDataPath = Path.Combine(userProfile, "AppData", "Roaming", "MetaQuotes", "Terminal");

// Searches for: Terminal\[ID]\MQL5\Files\CSM_Data\
```

---

## REVERSION ROADMAP

### Phase 1: Preserve Phase 8 Work ✅
```bash
# Create archive branches
cd /d/Jcamp_TradingApp
git checkout -b archive/phase8-complete-2026-01-18
git push origin archive/phase8-complete-2026-01-18

cd CSMMonitor
git checkout -b archive/phase8-chartviewer
git push origin archive/phase8-chartviewer

cd ../jcamp-python-backtesting
git checkout -b archive/phase8-python-api
git push origin archive/phase8-python-api
```

### Phase 2: Revert C# App ✅
```bash
cd /d/Jcamp_TradingApp/CSMMonitor
git checkout -b revert/csm-json-monitoring

# Option A: Clean revert to commit 567d05c
git reset --hard 567d05c

# Option B: Cherry-pick original files
git checkout 567d05c -- CSMMonitor/
git checkout 567d05c -- CSMMonitor.sln
```

### Phase 3: Setup MT5 EAs ⚠️
**Need to determine:**
1. Which EA writes signal JSON files?
2. Does Jcamp_BacktestEA.mq5 export signals?
3. Does Jcamp_MainTradingEA.mq5 export signals?
4. Or do we need to add JSON export to existing EAs?

**Action Items:**
- [ ] Clone JcampFxTrading repo: `git clone https://github.com/JCAMPanero23/JcampFxTrading.git`
- [ ] Review Jcamp_MainTradingEA.mq5 source code
- [ ] Check if signal export exists
- [ ] Add JSON export if needed

### Phase 4: Test End-to-End ✅
```
1. Install MT5 EAs
2. Configure data export paths
3. Run CSMMonitor app
4. Verify 5-second refresh
5. Confirm data display
```

---

## NEXT STEPS

### Immediate Actions Needed:
1. **Verify Signal Export** - Which MT5 EA writes EURUSD_signals.json?
   - Check Jcamp_MainTradingEA.mq5
   - Check Jcamp_BacktestEA.mq5
   - May need to add JSON export functionality

2. **Clone JcampFxTrading Repo**
   ```bash
   cd /d/
   git clone https://github.com/JCAMPanero23/JcampFxTrading.git
   ```

3. **Review MT5 EA Code** - Determine which EAs we need

4. **Execute Reversion** - Follow 5-phase plan in REVERT_TO_CSM_PLAN.md

---

## ARCHITECTURE COMPARISON

| Feature | Original CSM | Current Phase 8 |
|---------|-------------|-----------------|
| Backend | MT5 EA (MQ5) | Python FastAPI |
| Data Format | JSON files | HTTP API |
| Refresh Rate | 5 seconds | On-demand |
| Strategy Logic | MT5 EA | Python engine |
| C# Role | Monitor/Display | Configuration + Playback |
| Use Case | Live monitoring | Historical backtesting |
| Complexity | Simple | Complex |
| Dependencies | MT5 only | Python + MT5 + C# |

---

## QUESTIONS TO ANSWER

1. **Which EA exports signal JSON files?**
   - Jcamp_MainTradingEA.mq5?
   - Jcamp_BacktestEA.mq5?
   - Need to add to Jcamp_CSM_AnalysisEA.mq5?

2. **What pairs were monitored?**
   - Original C# app: EURUSD, GBPUSD, GBPNZD
   - Can we add more pairs?

3. **What strategies were implemented?**
   - Trend Rider
   - Impulse Pullback
   - Breakout Retest

4. **Do we need all 3 data files?**
   - csm_current.txt ✅ Confirmed
   - signals JSON ⚠️ Need to verify
   - account_info.json ⚠️ Need to verify

---

Ready to proceed? Next steps:
1. Clone JcampFxTrading repo to review MT5 EAs
2. Verify signal export functionality
3. Execute Phase 1 (preservation) if ready to revert
