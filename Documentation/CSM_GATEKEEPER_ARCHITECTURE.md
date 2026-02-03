# CSM Gatekeeper Architecture
**Created:** February 4, 2026
**Purpose:** Define correct signal generation flow with CSM as primary gatekeeper

---

## 🎯 Core Principle

**CSM Differential is the PRIMARY GATEKEEPER** for all trading decisions.
Only pairs with sufficient currency strength difference are tradable.

---

## 📊 Signal Generation Flow (Correct Architecture)

```
┌─────────────────────────────────────────────────────────────┐
│ STEP 1: CSM GATEKEEPER (Primary Filter)                    │
├─────────────────────────────────────────────────────────────┤
│ Calculate: CSM_Diff = |Currency1_Strength - Currency2_Strength|
│                                                               │
│ ├─ CSM_Diff < MinCSMDifferential (15.0)                     │
│ │  └─ Result: NOT_TRADABLE ❌                               │
│ │     Export: signal_text = "NOT_TRADABLE"                  │
│ │     Reason: Weak currency strength difference             │
│ │     Display: Orange color in dashboard                    │
│ │     Action: STOP - Do not proceed to regime/strategy      │
│ │                                                            │
│ └─ CSM_Diff ≥ MinCSMDifferential (15.0)                     │
│    └─ Result: CSM GATE PASSED ✓                             │
│       Action: CONTINUE to Step 2                            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 2: REGIME DETECTION (Strategy Selector)               │
├─────────────────────────────────────────────────────────────┤
│ Analyze market structure to select appropriate strategy     │
│                                                               │
│ ├─ REGIME_TRENDING (ADX > 25, clear directional bias)       │
│ │  └─ Action: Use TrendRider strategy                       │
│ │                                                            │
│ ├─ REGIME_RANGING (ADX < 20, price in consolidation)        │
│ │  └─ Action: Use RangeRider strategy (NOT for Gold)        │
│ │                                                            │
│ └─ REGIME_TRANSITIONAL (mixed signals, unclear structure)   │
│    └─ Action: NO STRATEGY ACTIVE                            │
│       Result: NOT_TRADABLE ❌                                │
│       Reason: Unclear market structure (wait for clarity)   │
│       Display: Orange color in dashboard                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 3: STRATEGY EXECUTION (Signal Generation)             │
├─────────────────────────────────────────────────────────────┤
│ Execute selected strategy with technical analysis           │
│                                                               │
│ TrendRider Checks (135-point confidence system):            │
│ ├─ EMA Alignment (30 pts): EMA20 > EMA50 > EMA100?         │
│ ├─ Price Position (gate): Price above/below EMA20?          │
│ ├─ ADX Strength (0-25 pts): Trend strength measurement      │
│ ├─ RSI Momentum (0-20 pts): Momentum confirmation           │
│ ├─ CSM Confirmation (0-25 pts): Strength differential       │
│ └─ MTF Alignment (0-10 pts): Higher timeframe agreement     │
│                                                               │
│ Results:                                                     │
│ ├─ Confidence ≥ 65 AND Valid Direction                      │
│ │  └─ BUY/SELL signal ✓ (Green/Red in dashboard)           │
│ │                                                            │
│ └─ Confidence < 65 OR No Clear Direction                    │
│    └─ HOLD (Gray in dashboard)                              │
│       Reason: Conditions not met (waiting for better setup) │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚦 Signal Types & Meanings

### 1. **NOT_TRADABLE** 🟠 (Orange)
**Meaning:** Pair is not eligible for trading
**Causes:**
- CSM differential < 15.0 (weak currency strength difference)
- REGIME_TRANSITIONAL (unclear market structure)
- Gold in RANGING market (Gold = TrendRider only)

**Dashboard Display:**
- Signal: "NOT TRADABLE" (orange text)
- Regime: Shows actual regime (TRANSITIONAL/RANGING)
- Confidence: 0%

**Action:** Do nothing - wait for conditions to improve

---

### 2. **HOLD** ⚪ (Gray)
**Meaning:** Pair is tradable, but no valid setup currently
**Causes:**
- CSM differential ≥ 15.0 ✓
- Regime identified (TRENDING/RANGING) ✓
- Strategy ran but conditions not met:
  - EMAs not aligned properly
  - Price on wrong side of EMA20
  - Insufficient confidence score

**Dashboard Display:**
- Signal: "HOLD" (gray text)
- Regime: Shows TRENDING or RANGING
- Confidence: 0-64%

**Action:** Wait for better entry (conditions improving)

---

### 3. **BUY/SELL** 🟢🔴 (Green/Red)
**Meaning:** Valid trading signal generated
**Requirements:**
- CSM differential ≥ 15.0 ✓
- Clear regime (TRENDING/RANGING) ✓
- Strategy confidence ≥ 65 ✓
- Valid directional signal ✓

**Dashboard Display:**
- Signal: "BUY" (green) or "SELL" (red)
- Regime: TRENDING or RANGING
- Confidence: 65-135%

**Action:** Execute trade (if other filters pass)

---

## 🏗️ Implementation Requirements

### Current Issue (Session 10)
❌ **Problem:** `MinCSMDifferential` is under "TREND RIDER STRATEGY" input group
❌ **Impact:** Appears strategy-specific instead of global gatekeeper
❌ **Confusion:** AUDJPY trading with 8.49 CSM diff (below 15.0 threshold)

### Required Changes

**1. Move CSM Gatekeeper Check FIRST**

```mql5
// ═══════════════════════════════════════════════════════════════
// STEP 1: CSM GATEKEEPER CHECK (PRIMARY FILTER)
// ═══════════════════════════════════════════════════════════════
if(csmDiff < MinCSMDifferential)
{
    // CSM Gate Failed - Export NOT_TRADABLE
    signalExporter.ClearSignal(_Symbol, EnumToString(currentRegime), csmDiff, "NOT_TRADABLE");

    if(VerboseLogging)
        Print("✗ NOT TRADABLE - CSM Diff: ", DoubleToString(csmDiff, 2),
              " < ", MinCSMDifferential, " (CSM gate failed)");

    return; // STOP - Do not proceed to regime/strategy
}

// CSM Gate Passed - Continue to regime detection
if(VerboseLogging)
    Print("✓ CSM GATE PASSED - Diff: ", DoubleToString(csmDiff, 2),
          " >= ", MinCSMDifferential);

// ═══════════════════════════════════════════════════════════════
// STEP 2: REGIME DETECTION (STRATEGY SELECTOR)
// ═══════════════════════════════════════════════════════════════
// ... existing regime-based strategy selection ...
```

**2. Reorganize Input Parameters**

```mql5
//═══════════════════════════════════════════════════════════════════
//  CSM GATEKEEPER (Primary Trading Filter)
//═══════════════════════════════════════════════════════════════════
input group "═══ CSM GATEKEEPER ═══"
input double MinCSMDifferential = 15.0;                   // Min CSM diff (PRIMARY GATE)
input string CSM_Folder = "CSM_Data";                     // CSM file folder
input int CSM_MaxAgeMinutes = 120;                        // Max CSM file age

//═══════════════════════════════════════════════════════════════════
//  TREND RIDER STRATEGY
//═══════════════════════════════════════════════════════════════════
input group "═══ TREND RIDER STRATEGY ═══"
input bool EnableTrendRider = true;                       // Enable Trend Rider
input double MinConfidenceScore = 65.0;                   // Min confidence (%)
// ❌ REMOVED: MinCSMDifferential (moved to CSM GATEKEEPER section)
```

**3. Handle TRANSITIONAL Regime**

```mql5
// Strategy selection
if(currentRegime == REGIME_TRENDING && EnableTrendRider)
{
    activeStrategy = trendRider;
}
else if(currentRegime == REGIME_RANGING && EnableRangeRider && !isGold)
{
    activeStrategy = rangeRider;
}
else
{
    // TRANSITIONAL regime or blocked condition
    activeStrategy = NULL;

    string reason = "NOT_TRADABLE";
    string explanation = currentRegime == REGIME_TRANSITIONAL
        ? "Unclear market structure (TRANSITIONAL regime)"
        : "No applicable strategy";

    signalExporter.ClearSignal(_Symbol, EnumToString(currentRegime), csmDiff, reason);

    if(VerboseLogging)
        Print("✗ NOT TRADABLE - ", explanation);

    return;
}
```

**4. Update SignalExporter**

```mql5
bool ClearSignal(string symbol, string regime = "UNKNOWN", double csmDiff = 0, string reason = "No valid signal")
{
    SignalExportData data;
    data.symbol = symbol;
    data.timestamp = TimeCurrent();
    data.strategyName = "NONE";
    data.signal = 0;
    data.confidence = 0;
    data.analysis = reason; // "NOT_TRADABLE" or "No valid signal"
    data.csmDiff = csmDiff;
    data.regime = regime;
    data.dynamicRegimeTriggered = false;

    return ExportSignal(data);
}

string BuildJSON(const SignalExportData &data)
{
    // ...
    string signalText = (data.analysis == "NOT_TRADABLE")
        ? "NOT_TRADABLE"
        : SignalToText(data.signal);
    json += "  \"signal_text\": \"" + signalText + "\",\n";
    // ...
}
```

---

## 📊 Dashboard Display Logic

### CSMMonitor Updates Required

**1. Signal Color Coding**
```csharp
private SolidColorBrush GetSignalColor(string signal)
{
    switch (signal?.ToUpper())
    {
        case "BUY":
            return GetMutedBrush("Green");
        case "SELL":
            return GetMutedBrush("Red");
        case "NOT_TRADABLE":
            return new SolidColorBrush((Color)ColorConverter.ConvertFromString("#FFA500")); // Orange
        case "HOLD":
        default:
            return GetMutedBrush("Gray");
    }
}
```

**2. Signal Text Formatting**
```csharp
private string FormatSignalForDisplay(string signal)
{
    return signal?.Replace("_", " ") ?? "HOLD";
}
```

**3. Load Signal Logic**
```csharp
else
{
    // NONE or NEUTRAL - preserve NOT_TRADABLE if regime blocked
    signalData.BestSignal = (signalText == "NOT_TRADABLE") ? "NOT_TRADABLE" : "HOLD";
    signalData.BestConfidence = 0;
}
```

---

## 🧪 Testing Checklist

### Expected Behavior After Implementation

**Test 1: CSM Differential < 15.0**
- ✅ Should show "NOT TRADABLE" (orange)
- ✅ Should show actual regime (TRENDING/RANGING/TRANSITIONAL)
- ✅ Should NOT attempt strategy evaluation
- ✅ Confidence = 0%

**Test 2: CSM Differential ≥ 15.0 + TRENDING Regime**
- ✅ TrendRider runs
- ✅ Returns BUY/SELL if conditions met (confidence ≥ 65)
- ✅ Returns HOLD if conditions not met (gray)

**Test 3: CSM Differential ≥ 15.0 + RANGING Regime**
- ✅ RangeRider runs (not for Gold)
- ✅ Gold shows "NOT TRADABLE" (orange)
- ✅ Returns BUY/SELL if range setup valid

**Test 4: CSM Differential ≥ 15.0 + TRANSITIONAL Regime**
- ✅ Should show "NOT TRADABLE" (orange)
- ✅ No strategy runs (unclear market structure)
- ✅ Confidence = 0%

---

## 📝 Key Takeaways

1. **CSM is the boss** - First check, primary gatekeeper
2. **NOT_TRADABLE** = Cannot trade (CSM failed OR wrong regime)
3. **HOLD** = Can trade, but waiting for better setup
4. **MinCSMDifferential** should be global setting, not strategy-specific
5. **Orange color** = System blocking trade (not just waiting)
6. **Gray color** = Strategy waiting for better entry

---

## 🔄 Next Session Tasks

1. [ ] Move `MinCSMDifferential` to "CSM GATEKEEPER" input group
2. [ ] Implement CSM check BEFORE regime detection
3. [ ] Export "NOT_TRADABLE" for:
   - CSM diff < 15.0
   - TRANSITIONAL regime
   - Gold in RANGING market
4. [ ] Update CSMMonitor color coding (orange for NOT_TRADABLE)
5. [ ] Test all 4 pairs with different CSM/regime combinations
6. [ ] Validate AUDJPY no longer trades with CSM diff < 15.0

---

**Status:** Architecture documented, ready for implementation
**Next:** Session 11 - CSM Gatekeeper Refactoring
