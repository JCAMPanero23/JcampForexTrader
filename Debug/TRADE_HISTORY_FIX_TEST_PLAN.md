# Trade History Fix - Test Verification Plan
**Date:** January 30, 2026
**Fix Version:** PerformanceTracker v2.00
**Status:** 🧪 TESTING

---

## 📋 PRE-FIX STATE

### Current Trade History (Before Fix)
```json
{
  "total_trades": 2,
  "trades": [
    {"ticket": 32814117, "symbol": "AUDJPY", "profit": -24.00},
    {"ticket": 32981218, "symbol": "AUDJPY", "profit": 37.32}
  ]
}
```

### Known Missing Trades (Data Loss Evidence)
1. **GBPUSD #32876995** (+$26.79) - Jan 28 fix doc, now missing
2. **Session 8 trades** - EURUSD (+$6.08), GBPUSD (+$3.42) - never recorded
3. **Account balance loss** - $503.80 unaccounted for

---

## 🔧 IMPLEMENTED FIXES

### 1. JSON Import Function ✅
**Function:** `LoadTradeHistoryFromJSON()`
- Reads existing trade_history.json on EA startup
- Parses JSON and populates closedTrades[] array
- Preserves all historical trades even if MT5 forgets them

### 2. Merge Strategy (Not Overwrite) ✅
**Function:** `LoadTradeHistory()` (redesigned)
- **Step 1:** Load from JSON (persistent storage)
- **Step 2:** Scan MT5 for NEW trades only
- **Step 3:** Merge (add only trades not in JSON)
- **Step 4:** Export updated JSON

### 3. Backup System ✅
**Function:** `CreateBackup()`
- Creates `trade_history_backup.json` before each export
- Safety net for corrupted exports
- Can manually restore if needed

### 4. JSON Parser ✅
**Functions:** `ParseTradeHistoryJSON()`, `ParseSingleTrade()`, `ExtractJSONString()`, `ExtractJSONNumber()`
- Manual JSON parsing (MQL5 has no native parser)
- Extracts all 12 trade fields
- Handles our specific JSON format

---

## 🧪 TEST PLAN

### Test #1: Restart Persistence (CRITICAL)
**Objective:** Verify trades survive EA restart

**Steps:**
1. Note current trade count (2 trades)
2. Restart MainTradingEA
3. Check trade_history.json

**Expected Result:**
```
🔄 LOADING TRADE HISTORY (PERSISTENT + MT5)
📁 Loaded from JSON: 2 trades
🔍 Scanning MT5 history for new trades...
Already recorded (in JSON): 2
NEW trades from MT5: 0
TOTAL trades now: 2
✅ Trade history load complete
```

**Success Criteria:**
- ✅ JSON import shows "Loaded from JSON: 2 trades"
- ✅ No data loss (still 2 trades after restart)
- ✅ Backup file created (trade_history_backup.json exists)

**Status:** ⏳ PENDING

---

### Test #2: New Trade Detection (CRITICAL)
**Objective:** Verify new MT5 trades are added to JSON

**Steps:**
1. Manually close an open position (if any)
2. Wait for OnTradeTransaction to fire
3. Check trade_history.json

**Expected Result:**
```
🆕 NEW DEALS DETECTED!
New deals to process: 1
✅ Recording trade!
💾 Backup created: trade_history_backup.json
📊 Trade history exported: 3 trades
```

**Success Criteria:**
- ✅ New trade added to closedTrades[] array
- ✅ trade_history.json updated with new trade
- ✅ total_trades increments (2 → 3)
- ✅ Backup created before export

**Status:** ⏳ PENDING

---

### Test #3: Duplicate Prevention (CRITICAL)
**Objective:** Verify same trade not added twice

**Steps:**
1. After Test #2, restart EA again
2. Check that new trade from Test #2 is loaded from JSON
3. Verify it's not re-added from MT5

**Expected Result:**
```
📁 Loaded from JSON: 3 trades
Already recorded (in JSON): 3
NEW trades from MT5: 0
TOTAL trades now: 3
```

**Success Criteria:**
- ✅ IsTradeAlreadyRecorded() catches duplicates
- ✅ Trade count stays at 3 (not 4 or 6)
- ✅ No duplicate entries in JSON

**Status:** ⏳ PENDING

---

### Test #4: Backup System (HIGH PRIORITY)
**Objective:** Verify backup file is created and valid

**Steps:**
1. Check for trade_history_backup.json in CSM_Data folder
2. Compare backup to current JSON
3. Verify backup is valid JSON (can be parsed)

**Expected Result:**
- Backup file exists
- Backup contains previous state (before latest export)
- Backup is valid JSON format

**Success Criteria:**
- ✅ trade_history_backup.json exists
- ✅ File size > 0 bytes
- ✅ Contains valid JSON

**Status:** ⏳ PENDING

---

### Test #5: MT5 History Cleared Scenario (CRITICAL)
**Objective:** Verify JSON preserves trades even if MT5 forgets them

**Steps:**
1. Note current trades in JSON (e.g., 3 trades)
2. Simulate MT5 history clear:
   - Option A: Switch to different MT5 demo account
   - Option B: Clear history in MT5 (if possible)
   - Option C: Delete MT5 history files (risky)
3. Restart EA
4. Verify JSON trades are preserved

**Expected Result:**
```
📁 Loaded from JSON: 3 trades
MT5 deals in history: 0 (or less than 3)
Already recorded (in JSON): 0
NEW trades from MT5: 0
TOTAL trades now: 3
```

**Success Criteria:**
- ✅ All 3 trades preserved in JSON
- ✅ No data loss even though MT5 has no history
- ✅ JSON is authoritative source of truth

**Status:** ⏳ PENDING (optional, risky test)

---

### Test #6: JSON Corruption Recovery (MEDIUM PRIORITY)
**Objective:** Verify backup can restore corrupted JSON

**Steps:**
1. Manually corrupt trade_history.json (add random text)
2. Restart EA (should fail to parse JSON)
3. Manually restore from trade_history_backup.json
4. Restart EA again

**Expected Result:**
- First restart: "⚠️ No trades found in JSON (may be corrupted)"
- After restore: "✅ Loaded X trades from persistent JSON storage"

**Success Criteria:**
- ✅ EA detects corrupted JSON gracefully (no crash)
- ✅ Backup allows manual recovery
- ✅ System continues operating after recovery

**Status:** ⏳ PENDING (optional, for robustness testing)

---

## 📊 TEST RESULTS LOG

### Test #1: Restart Persistence
**Date:** _____________________
**Tester:** _____________________
**Result:** ⬜ PASS / ⬜ FAIL

**Observations:**
```
(Paste log output here)
```

**Issues Found:**
-

---

### Test #2: New Trade Detection
**Date:** _____________________
**Tester:** _____________________
**Result:** ⬜ PASS / ⬜ FAIL

**Observations:**
```
(Paste log output here)
```

**Issues Found:**
-

---

### Test #3: Duplicate Prevention
**Date:** _____________________
**Tester:** _____________________
**Result:** ⬜ PASS / ⬜ FAIL

**Observations:**
```
(Paste log output here)
```

**Issues Found:**
-

---

## ✅ ACCEPTANCE CRITERIA

**Fix is PRODUCTION READY when:**
- [❌] Test #1 PASS: Trades persist across EA restart
- [❌] Test #2 PASS: New trades added to JSON correctly
- [❌] Test #3 PASS: No duplicate trades after restart
- [❌] Test #4 PASS: Backup system working
- [ ] Test #5 PASS: JSON survives MT5 history clear (optional)
- [ ] Test #6 PASS: Backup restores corrupted JSON (optional)

**Minimum for deployment:**
- ✅ Tests #1, #2, #3, #4 must all PASS
- ✅ No data loss on EA restart
- ✅ No duplicate trades
- ✅ Backup system functional

---

## 🚀 DEPLOYMENT CHECKLIST

**Before deploying to live account:**
- [ ] All critical tests passed
- [ ] Fix documented in CLAUDE.md
- [ ] Commit changes to git
- [ ] Compile with 0 errors
- [ ] Test on demo for 24-48 hours
- [ ] Verify CSMMonitor displays correctly
- [ ] Create recovery instructions for users

---

## 📝 NOTES

### Implementation Details
- **Version:** PerformanceTracker v2.00
- **Lines Added:** ~200 lines (JSON import + parser)
- **Files Modified:** PerformanceTracker.mqh only
- **Breaking Changes:** None (backward compatible)

### Backup Strategy
- **Backup File:** trade_history_backup.json
- **Frequency:** Before each export
- **Retention:** Last 1 backup (can extend to 3-5 if needed)

### Recovery Procedure
If trade_history.json is corrupted:
1. Stop EA
2. Copy trade_history_backup.json to trade_history.json
3. Restart EA
4. Verify trades loaded correctly

---

**Status:** 🧪 READY FOR TESTING
**Priority:** 🔴 CRITICAL (blocks production)
**ETA:** 1-2 hours of testing
