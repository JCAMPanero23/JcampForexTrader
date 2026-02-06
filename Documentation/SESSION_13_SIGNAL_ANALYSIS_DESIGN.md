# Session 13 - Enhanced Signal Analysis Dashboard Design

**Objective:** Enhance CSMMonitor SIGNAL ANALYSIS tab to show detailed strategy breakdown

**Reference:** `Debug/Previous Strategy analysis Sample.png`

---

## 🎯 DESIGN REQUIREMENTS

### Current State (Basic)
- Shows signal status: BUY/SELL/HOLD/NOT_TRADABLE
- Shows confidence % (single number)
- Shows CSM differential (single number)
- Shows regime (TRENDING/RANGING/TRANSITIONAL)

### Target State (Detailed - Like Old System)
**Per-Pair Strategy Card showing:**
- Current signal status with color coding
- Confidence progress bar (current / minimum threshold)
- CSM differential progress bar (current / minimum threshold)
- Warning boxes for blocking conditions
- Component-level breakdown:
  - TrendRider: EMA (0-30), ADX (0-25), RSI (0-20), CSM (0-25)
  - RangeRider: Range Width, S/R Quality, Bounce Position
- Visual indicators: ✅ (good), ⚠️ (weak), ❌ (missing)
- Reasoning text explaining current state

---

## 📋 IMPLEMENTATION PHASES

### Phase 1: Signal Export Enhancement (MQ5)

**Files to Modify:**
- `MT5_EAs/Include/JcampStrategies/Strategies/TrendRiderStrategy.mqh`
- `MT5_EAs/Include/JcampStrategies/Strategies/RangeRiderStrategy.mqh`
- `MT5_EAs/Include/JcampStrategies/SignalExporter.mqh`
- `MT5_EAs/Experts/Jcamp_Strategy_AnalysisEA.mq5`

**Enhanced Signal JSON Structure:**
```json
{
  "symbol": "EURUSD.r",
  "signal_text": "HOLD",
  "confidence": 75,
  "csm_diff": 27.68,
  "regime": "REGIME_TRENDING",

  "trend_rider": {
    "evaluated": true,
    "signal": "HOLD",
    "total_confidence": 75,
    "min_confidence": 90,
    "components": {
      "ema_alignment": { "score": 25, "max": 30, "status": "GOOD" },
      "adx_strength": { "score": 20, "max": 25, "status": "GOOD" },
      "rsi_position": { "score": 10, "max": 20, "status": "WEAK" },
      "csm_support": { "score": 20, "max": 25, "status": "GOOD" }
    },
    "reasoning": "Strong trend detected, EMA aligned bullish, but RSI not in ideal zone yet."
  },

  "range_rider": {
    "evaluated": false,
    "reason": "Market in TRENDING regime"
  },

  "blocking_reason": null,
  "needs": "15% more confidence"
}
```

**Changes Required:**

1. **TrendRiderStrategy.mqh:**
   - Return individual component scores (not just total)
   - Add GetComponentBreakdown() method
   - Generate reasoning text based on component states

2. **RangeRiderStrategy.mqh:**
   - Export component breakdown
   - Add reasoning text generation

3. **SignalExporter.mqh:**
   - Update BuildJSON() to include component data
   - Add blocking_reason field handling
   - Calculate "needs" text (what's missing for valid signal)

4. **Strategy_AnalysisEA.mq5:**
   - Pass component breakdown to SignalExporter
   - Include blocking reason for NOT_TRADABLE signals

---

### Phase 2: Dashboard UI Design (C# XAML)

**File:** `CSMMonitor/JcampForexTrader/MainWindow.xaml`

**New/Enhanced Tab: "SIGNAL ANALYSIS"**

**Layout Structure:**
- Vertical ScrollViewer
- 4 strategy cards (EURUSD, GBPUSD, AUDJPY, XAUUSD)
- Each card contains:
  - Header (symbol name + status)
  - Confidence progress bar
  - CSM differential progress bar
  - Warning box (if applicable)
  - TrendRider expander (component breakdown)
  - RangeRider expander (if evaluated)

**Key UI Elements:**
- Border with colored border (blue for normal, orange for NOT_TRADABLE)
- Progress bars for confidence and CSM diff
- Expander controls for strategy details
- Status icons (✅⚠️❌) for each component
- Reasoning text at bottom (italic, gray)

---

### Phase 3: Dashboard Parser (C# Code-Behind)

**File:** `CSMMonitor/JcampForexTrader/MainWindow.xaml.cs`

**New Data Structures:**

```csharp
public class StrategyComponent
{
    public int Score { get; set; }
    public int MaxScore { get; set; }
    public string Status { get; set; }
    public string Icon => Status == "GOOD" ? "✅" : Status == "WEAK" ? "⚠️" : "❌";
    public string DisplayText => $"{Icon} {Score}/{MaxScore} points ({Status})";
}

public class StrategyBreakdown
{
    public bool Evaluated { get; set; }
    public string Signal { get; set; }
    public int TotalConfidence { get; set; }
    public int MinConfidence { get; set; }
    public StrategyComponent EmaAlignment { get; set; }
    public StrategyComponent AdxStrength { get; set; }
    public StrategyComponent RsiPosition { get; set; }
    public StrategyComponent CsmSupport { get; set; }
    public string Reasoning { get; set; }
}

public class SignalAnalysis
{
    public string Symbol { get; set; }
    public string SignalText { get; set; }
    public int Confidence { get; set; }
    public double CsmDiff { get; set; }
    public string Regime { get; set; }
    public StrategyBreakdown TrendRider { get; set; }
    public StrategyBreakdown RangeRider { get; set; }
    public string BlockingReason { get; set; }
    public string Needs { get; set; }
}
```

**Parser Logic:**
- Read enhanced signal JSON files
- Parse component breakdown for each strategy
- Calculate visual indicators (icons, colors, progress bars)
- Update UI bindings every 5 seconds

---

## 🎨 VISUAL DESIGN GUIDE

### Status Icons
- ✅ Green check: Component score > 80%
- ⚠️ Yellow warning: Component score 50-80%
- ❌ Red X: Component score < 50%

### Signal Colors
- 🟢 BUY: Bright green (#2ecc71)
- 🔴 SELL: Bright red (#e74c3c)
- ⚪ HOLD: Gray (#95a5a6)
- 🟠 NOT_TRADABLE: Orange (#e67e22)

### Progress Bars
- Confidence: Blue (#3498db)
- CSM Diff: Purple (#9b59b6)
- Component Scores: Green (#27ae60)

### Warning Boxes
- BLOCKING: Orange background (#f39c12), white text
- NEEDS: Red background (#e74c3c), white text

---

## ✅ TESTING CHECKLIST

### MQ5 Signal Export
- [ ] TrendRider exports component scores correctly
- [ ] RangeRider exports component scores correctly
- [ ] Blocking reasons exported for NOT_TRADABLE
- [ ] "Needs" text calculated correctly
- [ ] JSON structure valid and parseable

### C# Dashboard
- [ ] Signal analysis tab displays 4 pair cards
- [ ] Component scores display with correct icons
- [ ] Progress bars update in real-time
- [ ] Expanders work (TrendRider/RangeRider details)
- [ ] Warning boxes show/hide correctly
- [ ] Reasoning text displays properly

### Real-Time Updates
- [ ] Dashboard refreshes every 5 seconds
- [ ] Signal changes reflect immediately
- [ ] Component score changes update progress bars
- [ ] Warning boxes appear/disappear dynamically

---

## 📦 DELIVERABLES

1. **Modified MQ5 Files:**
   - TrendRiderStrategy.mqh (component score export)
   - RangeRiderStrategy.mqh (component score export)
   - SignalExporter.mqh (enhanced JSON structure)
   - Strategy_AnalysisEA.mq5 (pass component data to exporter)

2. **Modified C# Files:**
   - MainWindow.xaml (Signal Analysis tab layout)
   - MainWindow.xaml.cs (parser + data binding logic)

3. **Documentation:**
   - Session 13 completion notes in CLAUDE.md
   - Before/after screenshots in Debug/

---

## 🎯 SUCCESS CRITERIA

✅ User can see EXACTLY why each pair is on HOLD
✅ Component-by-component breakdown visible (EMA, ADX, RSI, CSM)
✅ Clear visual indicators (✅⚠️❌) for each component
✅ Reasoning text explains current market state
✅ Warning boxes show blocking reasons for NOT_TRADABLE
✅ Dashboard matches old system's detail level

---

## 💡 IMPLEMENTATION NOTES

### Strategy Component Scoring (Reference)

**TrendRider (max 135 points):**
- EMA Alignment: 0-30 points
  - All 3 EMAs aligned: 30 points
  - 2 EMAs aligned: 15-20 points
  - 1 EMA aligned: 5-10 points
- ADX Strength: 0-25 points
  - ADX > 25: Strong trend (20-25 points)
  - ADX 20-25: Moderate trend (10-15 points)
  - ADX < 20: Weak trend (0-5 points)
- RSI Position: 0-20 points
  - RSI in ideal zone (30-70): 15-20 points
  - RSI near extreme: 5-10 points
  - RSI at extreme: 0-5 points
- CSM Support: 0-25 points
  - Strong CSM diff (>30): 20-25 points
  - Moderate CSM diff (15-30): 10-15 points
  - Weak CSM diff (<15): 0-5 points

**RangeRider (max 100 points):**
- Range Width: 0-35 points
- S/R Quality: 0-35 points
- Bounce Position: 0-30 points

### Blocking Conditions
- CSM_DIFF_TOO_LOW: CSM diff < 15.0
- TRANSITIONAL_REGIME: Regime = TRANSITIONAL
- GOLD_IN_RANGING: XAUUSD + RANGING regime (TrendRider only)

---

*Reference: Debug/Previous Strategy analysis Sample.png*
*Session 13 Design Document - February 6, 2026*
