# Monday Market Open - Session 17 Validation Checklist

**Date:** February 10, 2026 (Monday market open)
**Status:** ✅ Compilation successful - Awaiting market validation

---

## ✅ PRE-VALIDATION STATUS

### Completed (February 7, 2026)
- [x] Session 17 code implementation complete
- [x] Strategy_AnalysisEA.mq5 compiled successfully (0 errors)
- [x] All 3 sessions (15-17) committed to git
- [x] Documentation created (testing guide, CLAUDE.md updated)

### Pending (Monday market open)
- [ ] Deploy on live demo MT5
- [ ] Verify confidence-based R:R scaling with real market data
- [ ] Monitor signal generation and logging
- [ ] Validate Gold R:R cap behavior

---

## 🚀 MONDAY MORNING CHECKLIST

### Step 1: Deploy EAs (5 minutes)
```
1. Open MT5 Terminal
2. Verify all 3 EAs are running:
   - CSM_AnalysisEA (any chart) - Generating 9-currency CSM
   - Strategy_AnalysisEA (4 charts) - EURUSD, GBPUSD, AUDJPY, XAUUSD
   - MainTradingEA (any chart) - Reading signals, executing trades
3. Check Expert tab for initialization messages
```

### Step 2: Verify Logging (15 minutes)
**Look for new Session 17 messages in Expert tab:**
- [ ] "🔥 High conf (XX) → 1:3 R:R"
- [ ] "⚡ Good conf (XX) → 1:2.5 R:R"
- [ ] "✓ Standard conf (XX) → 1:2 R:R"
- [ ] "⚠️ Gold R:R capped at 1:2.5" (if Gold has 90+ confidence)

### Step 3: Inspect Signal JSON Files (15 minutes)
**Check CSM_Signals folder for updated files:**

**EURUSD_signals.json:**
```json
{
  "confidence": 85,
  "stop_loss_dollars": 0.0002,
  "take_profit_dollars": 0.0005  // Should be 2.5× SL (1:2.5 R:R)
}
```

**Validation:**
- [ ] Confidence 90+ → TP = SL × 3.0
- [ ] Confidence 80-89 → TP = SL × 2.5
- [ ] Confidence 70-79 → TP = SL × 2.0

**XAUUSD_signals.json (Gold):**
```json
{
  "confidence": 95,
  "stop_loss_dollars": 100.0,
  "take_profit_dollars": 250.0  // Should be 2.5× (CAPPED, not 3.0×)
}
```

**Validation:**
- [ ] Gold never exceeds 2.5× even with 90+ confidence
- [ ] Log shows "Gold R:R capped" message

### Step 4: Monitor First Trades (1-2 hours)
**Wait for MainTradingEA to execute trades:**

**High Confidence Trade (90+):**
- [ ] Entry executed
- [ ] SL set based on ATR (Session 15)
- [ ] TP set at 3× SL distance (1:3 R:R)
- [ ] 3-phase trailing activates at +0.5R (Session 16)
- [ ] Position tracked correctly

**Medium Confidence Trade (80-89):**
- [ ] TP set at 2.5× SL distance (1:2.5 R:R)

**Gold Trade (any confidence):**
- [ ] TP never exceeds 2.5× SL (even if confidence 90+)

### Step 5: Check CSMMonitor Dashboard (5 minutes)
**Verify dashboard displays:**
- [ ] All 9 currencies showing (including Gold/XAU)
- [ ] 4 signal panels (EURUSD, GBPUSD, AUDJPY, XAUUSD)
- [ ] Component scores visible (Session 13 enhancement)
- [ ] Active positions updating every 5 seconds
- [ ] Signal colors correct (green/red for BUY/SELL, orange for NOT_TRADABLE)

---

## 🔍 VALIDATION SCENARIOS

### Scenario 1: High Confidence EURUSD
**If you see:** Confidence 95, SL 20 pips
**Expect:** TP 60 pips (1:3 R:R)
**Log:** "🔥 High conf (95) → 1:3 R:R"

### Scenario 2: Medium Confidence GBPUSD
**If you see:** Confidence 85, SL 48 pips
**Expect:** TP 120 pips (1:2.5 R:R)
**Log:** "⚡ Good conf (85) → 1:2.5 R:R"

### Scenario 3: Standard Confidence AUDJPY
**If you see:** Confidence 73, SL 25 pips
**Expect:** TP 50 pips (1:2 R:R)
**Log:** "✓ Standard conf (73) → 1:2 R:R"

### Scenario 4: High Confidence Gold (Cap Test)
**If you see:** Confidence 97, SL $100
**Expect:** TP $250 (1:2.5 R:R, NOT 1:3)
**Log:** "🔥 High conf (97) → 1:3 R:R" + "⚠️ Gold R:R capped at 1:2.5"

---

## ✅ SUCCESS CRITERIA

**Session 17 is validated if:**
1. [ ] All 4 symbols generate signals with different R:R ratios
2. [ ] High confidence trades (90+) get 1:3 R:R targets
3. [ ] Medium confidence trades (80-89) get 1:2.5 R:R targets
4. [ ] Standard confidence trades (70-79) get 1:2 R:R targets
5. [ ] Gold trades never exceed 1:2.5 R:R (even with 90+ confidence)
6. [ ] Logging shows correct confidence tier selection
7. [ ] No compilation errors or runtime errors
8. [ ] Trades execute successfully with dynamic TP values

---

## ⚠️ ISSUES TO WATCH FOR

### Issue 1: All trades getting same R:R
**Symptom:** All trades show 1:2 R:R regardless of confidence
**Cause:** Confidence scaling logic not executing
**Fix:** Check signal.confidence values in JSON files

### Issue 2: Gold getting 1:3 R:R
**Symptom:** Gold trades with confidence 90+ show TP = SL × 3.0
**Cause:** Gold cap not applying
**Fix:** Verify isGold detection logic working

### Issue 3: No confidence messages in logs
**Symptom:** Expert tab doesn't show "🔥 High conf" messages
**Cause:** VerboseLogging = false
**Fix:** Set VerboseLogging = true in Strategy_AnalysisEA inputs

---

## 📊 DATA TO COLLECT

**For next 1-2 weeks:**
- [ ] Confidence distribution (how many 90+, 80+, 70+ trades)
- [ ] Average R-multiple per confidence tier
- [ ] Gold trade count and actual R:R values
- [ ] Big winners (3R+) frequency vs Session 16
- [ ] Premature stop-out rate vs Session 16

**Goal:** Collect 50+ closed trades before Phase 3 Python backtesting

---

## 📸 SCREENSHOTS TO CAPTURE

Monday validation screenshots:
1. [ ] Expert tab with confidence scaling logs
2. [ ] Signal JSON files (all 4 symbols)
3. [ ] CSMMonitor dashboard showing different R:R ratios
4. [ ] First high confidence trade execution (1:3 R:R)
5. [ ] Gold cap in action (confidence 90+ but TP capped at 2.5×)

---

## 🎯 QUICK VALIDATION (30 minutes)

**Minimum validation to confirm Session 17 working:**
1. Check Expert tab for confidence messages (5 min)
2. Inspect 4 signal JSON files for dynamic TP values (10 min)
3. Wait for 1 trade execution and verify TP matches expected R:R (15 min)

**If all 3 checks pass:**
✅ Session 17 validated successfully!
✅ 3-Phase SL/TP Enhancement (Sessions 15-17) operational!

---

**Monday Status:** Awaiting market open for live validation
**Expected Result:** All Session 17 features working as designed

*Compiled successfully February 7, 2026 - Markets open Monday February 10, 2026*
