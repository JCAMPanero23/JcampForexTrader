# Session 21: Signal Analysis Tab Fix Plan

**Date Created:** February 11, 2026 (Session 20)
**Status:** 🔴 TO-DO (Next Session)

---

## 📋 Current State (After Session 20)

### ✅ What's Working:
1. **Live Dashboard Tab:**
   - ✅ Asset cards section is scrollable (Yellow section)
   - ✅ All 5 pairs showing with full details (EURUSD, GBPUSD, AUDJPY, USDJPY 🏯, USDCHF 🇨🇭)
   - ✅ Account Balance section updated for 5 pairs (Red section)
   - ✅ Per-Symbol Breakdown shows: EUR·GBP·AUD·USDJPY·USDCHF

2. **Signal Analysis Tab:**
   - ✅ 3x2 grid layout working (6 slots available)

### ❌ What's NOT Working:
**Signal Analysis Tab Content:**
- ❌ **XAUUSD (Gold)** still showing in bottom-left position
- ❌ **USDJPY** card missing
- ❌ **USDCHF** card missing
- Only 4 pairs displayed instead of 5

**Current Layout:**
```
┌─────────┬─────────┬─────────┐
│ EURUSD  │ GBPUSD  │ AUDJPY  │  ← Top Row (Correct ✅)
├─────────┼─────────┼─────────┤
│ XAUUSD  │ Empty   │ Empty   │  ← Bottom Row (WRONG ❌)
│ (Gold)  │         │         │
└─────────┴─────────┴─────────┘
```

**Target Layout:**
```
┌─────────┬─────────┬─────────┐
│ EURUSD  │ GBPUSD  │ AUDJPY  │  ← Top Row
├─────────┼─────────┼─────────┤
│ USDJPY  │ USDCHF  │ Empty   │  ← Bottom Row (Future 6th asset)
│  🏯     │  🇨🇭     │         │
└─────────┴─────────┴─────────┘
```

---

## 🎯 Session 21 Objectives

### Task 1: Remove XAUUSD (Gold) Card
**File:** `D:\JcampForexTrader\CSMMonitor\MainWindow.xaml`
**Lines:** ~1851-1968 (218 lines)

**Action:**
- Delete the entire XAUUSD card section
- Comment explains: "Gold (XAU) is CSM-tracked but not traded (Session 19)"

### Task 2: Add USDJPY Card (Position 4)
**Template:** Copy AUDJPY card structure (lines 1632-1850)
**Location:** Bottom-left position in 3x2 grid

**Strategy Breakdown:**
- ✅ **TrendRider Strategy:**
  - EMA Alignment (0-30 points)
  - ADX Strength (0-25 points)
  - RSI Position (0-20 points)
  - CSM Support (0-25 points)

- ✅ **RangeRider Strategy:**
  - Proximity (0-15 points)
  - Rejection Quality (0-15 points)
  - RSI Neutral (0-8 points)
  - S/R Clarity (0-10 points)
  - CSM Support (0-25 points)

**C# Bindings Needed (MainWindow.xaml.cs):**
```csharp
// Signal Analysis Tab - USDJPY
TextBlock USDJPY_Signal_SA;
TextBlock USDJPY_Confidence_SA;

// TrendRider
TextBlock USDJPY_TR_Signal_SA;
TextBlock USDJPY_TR_Conf_SA;
ProgressBar USDJPY_TR_Bar_SA;
ProgressBar USDJPY_TR_EMA_Bar;
TextBlock USDJPY_TR_EMA_Text;
ProgressBar USDJPY_TR_ADX_Bar;
TextBlock USDJPY_TR_ADX_Text;
ProgressBar USDJPY_TR_RSI_Bar;
TextBlock USDJPY_TR_RSI_Text;
ProgressBar USDJPY_TR_CSM_Bar;
TextBlock USDJPY_TR_CSM_Text;

// RangeRider
TextBlock USDJPY_RR_Signal_SA;
TextBlock USDJPY_RR_Conf_SA;
ProgressBar USDJPY_RR_Bar_SA;
ProgressBar USDJPY_RR_Prox_Bar;
TextBlock USDJPY_RR_Prox_Text;
ProgressBar USDJPY_RR_Rej_Bar;
TextBlock USDJPY_RR_Rej_Text;
ProgressBar USDJPY_RR_RSI_Bar;
TextBlock USDJPY_RR_RSI_Text;
ProgressBar USDJPY_RR_SR_Bar;
TextBlock USDJPY_RR_SR_Text;
ProgressBar USDJPY_RR_CSM_Bar;
TextBlock USDJPY_RR_CSM_Text;
```

### Task 3: Add USDCHF Card (Position 5)
**Template:** Copy AUDJPY card structure
**Location:** Bottom-middle position in 3x2 grid

**Strategy Breakdown:** Same as USDJPY (both TrendRider + RangeRider)

**C# Bindings Needed (MainWindow.xaml.cs):**
```csharp
// Signal Analysis Tab - USDCHF
TextBlock USDCHF_Signal_SA;
TextBlock USDCHF_Confidence_SA;

// TrendRider (same structure as USDJPY)
// RangeRider (same structure as USDJPY)
```

### Task 4: Update C# Backend
**File:** `D:\JcampForexTrader\CSMMonitor\MainWindow.xaml.cs`

**Actions:**
1. **Add x:Name declarations** for all new TextBlocks and ProgressBars
2. **Update LoadSignalAnalysisData() method:**
   - Remove XAUUSD/Gold parsing
   - Add USDJPY parsing (read `USDJPY_signals.json` or `USDJPY.sml_signals.json`)
   - Add USDCHF parsing (read `USDCHF_signals.json` or `USDCHF.sml_signals.json`)

3. **Add signal file paths:**
```csharp
private void LoadSignalAnalysisData()
{
    // Existing
    LoadSymbolSignals("EURUSD", ...);
    LoadSymbolSignals("GBPUSD", ...);
    LoadSymbolSignals("AUDJPY", ...);

    // NEW
    LoadSymbolSignals("USDJPY",
        USDJPY_Signal_SA, USDJPY_Confidence_SA,
        USDJPY_TR_Signal_SA, USDJPY_TR_Conf_SA, USDJPY_TR_Bar_SA,
        USDJPY_TR_EMA_Bar, USDJPY_TR_EMA_Text, ...);

    LoadSymbolSignals("USDCHF",
        USDCHF_Signal_SA, USDCHF_Confidence_SA,
        USDCHF_TR_Signal_SA, USDCHF_TR_Conf_SA, USDCHF_TR_Bar_SA,
        USDCHF_TR_EMA_Bar, USDCHF_TR_EMA_Text, ...);

    // REMOVE
    // LoadSymbolSignals("XAUUSD", ...);  // Gold no longer traded
}
```

---

## 📝 Implementation Checklist

### Phase 1: Remove Gold
- [ ] Read MainWindow.xaml lines 1851-1968
- [ ] Confirm XAUUSD card boundaries
- [ ] Delete entire XAUUSD Border section
- [ ] Add comment: `<!-- XAUUSD (Gold) removed - CSM-tracked but not traded (Session 19) -->`

### Phase 2: Add USDJPY Card
- [ ] Copy AUDJPY card structure (lines 1632-1850)
- [ ] Replace all "AUDJPY" with "USDJPY"
- [ ] Replace "AUDJPY" x:Name prefixes with "USDJPY"
- [ ] Add emoji: `<TextBlock Text="🏯" FontSize="13" Foreground="#FFD700" Margin="4,0,0,0"/>`
- [ ] Place after AUDJPY card in UniformGrid

### Phase 3: Add USDCHF Card
- [ ] Copy AUDJPY card structure
- [ ] Replace all "AUDJPY" with "USDCHF"
- [ ] Replace "AUDJPY" x:Name prefixes with "USDCHF"
- [ ] Add emoji: `<TextBlock Text="🇨🇭" FontSize="13" Foreground="#FFD700" Margin="4,0,0,0"/>`
- [ ] Place after USDJPY card in UniformGrid

### Phase 4: Update C# Backend
- [ ] Open MainWindow.xaml.cs
- [ ] Add USDJPY x:Name declarations (35 controls)
- [ ] Add USDCHF x:Name declarations (35 controls)
- [ ] Remove XAUUSD x:Name declarations
- [ ] Update LoadSignalAnalysisData() method
- [ ] Add USDJPY signal parsing
- [ ] Add USDCHF signal parsing
- [ ] Remove XAUUSD signal parsing

### Phase 5: Test & Verify
- [ ] Compile: `dotnet build` (0 errors expected)
- [ ] Run CSMMonitor.exe
- [ ] Navigate to Signal Analysis tab
- [ ] Verify 5 cards showing:
  - [ ] EURUSD (top-left)
  - [ ] GBPUSD (top-middle)
  - [ ] AUDJPY (top-right)
  - [ ] USDJPY 🏯 (bottom-left)
  - [ ] USDCHF 🇨🇭 (bottom-middle)
- [ ] Verify Gold is NOT showing
- [ ] Check all progress bars populate correctly
- [ ] Check strategy breakdowns (TrendRider + RangeRider)

---

## 📸 Reference Screenshots

**Current State (Session 20):**
- `Debug/Screenshot 2026-02-11 010528.png` - Live Dashboard (✅ Working)
- `Debug/Screenshot 2026-02-11 010558.png` - Signal Analysis (❌ Gold still showing)

**Expected Result (Session 21):**
- Signal Analysis tab shows 5 pairs (EURUSD, GBPUSD, AUDJPY, USDJPY, USDCHF)
- No Gold card
- Bottom-right slot empty (ready for future 6th asset)

---

## 🔗 Related Files

**XAML:**
- `CSMMonitor/MainWindow.xaml` (Lines 1185-1971)

**C# Backend:**
- `CSMMonitor/MainWindow.xaml.cs`
  - LoadSignalAnalysisData() method (~line 2000+)
  - x:Name declarations (class fields)

**Signal Files (MT5 Output):**
- `CSM_Signals/EURUSD_signals.json` (or with broker suffix)
- `CSM_Signals/GBPUSD_signals.json`
- `CSM_Signals/AUDJPY_signals.json`
- `CSM_Signals/USDJPY_signals.json` ← NEW
- `CSM_Signals/USDCHF_signals.json` ← NEW
- ~~`CSM_Signals/XAUUSD_signals.json`~~ ← REMOVE

---

## ⚠️ Important Notes

1. **Gold (XAU) Status:**
   - Gold IS tracked in CSM (9-currency system)
   - Gold is NOT traded (removed in Session 19)
   - Replace Gold card with USDJPY + USDCHF

2. **Broker Suffix Handling:**
   - Signal files may have broker suffix (e.g., `.sml`)
   - C# code already handles this (check existing LoadSymbolSignals logic)

3. **Strategy Differences:**
   - EURUSD, GBPUSD, AUDJPY, USDJPY, USDCHF: TrendRider + RangeRider
   - Gold (removed): Was TrendRider only

4. **Session 19 Context:**
   - Gold was replaced due to volatility concerns
   - USDJPY added as "safe haven indicator"
   - USDCHF added for CHF exposure

---

## 🎯 Success Criteria

✅ Session 21 complete when:
1. Signal Analysis tab shows exactly 5 pairs
2. XAUUSD (Gold) card removed
3. USDJPY card added with full strategy breakdown
4. USDCHF card added with full strategy breakdown
5. All progress bars and scores populate correctly
6. No compilation errors
7. Dashboard runs without crashes

---

**Estimated Time:** 2-3 hours
**Complexity:** Medium (repetitive XAML + C# binding work)
**Priority:** High (dashboard incomplete without this fix)

---

*Created: Session 20 (February 11, 2026)*
*Next Session: 21*
