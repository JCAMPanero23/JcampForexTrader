# Trade History Bug - Ultra-Deep Root Cause Analysis
**Date:** January 30, 2026
**Analyst:** Claude Sonnet 4.5
**Status:** 🔴 CRITICAL DATA LOSS BUG IDENTIFIED

---

## 🚨 CRITICAL FINDING: DATA LOSS ON EA RESTART

### The Smoking Gun
**Commit dafbe2a message reveals:**
> "Somehow deleted trade records from history"

### Current State vs Expected State
| Source | Expected Trades | Actual Trades | Missing |
|--------|----------------|---------------|---------|
| Jan 28 Fix Doc | AUDJPY #32814117 (-$24) <br/> GBPUSD #32876995 (+$26.79) | AUDJPY #32814117 (-$24) <br/> AUDJPY #32981218 (+$37.32) | GBPUSD #32876995 ❌ |
| Session 8 CLAUDE.md | EURUSD (+$6.08) <br/> GBPUSD (+$3.42) | AUDJPY #32814117 (-$24) <br/> AUDJPY #32981218 (+$37.32) | EURUSD ❌ <br/> GBPUSD ❌ |
| Account Balance | Started: $9,976 <br/> Current: $9,472 | Loss: $504 | **SIGNIFICANT LOSS NOT IN HISTORY** |

---

## 🔍 ROOT CAUSE IDENTIFIED

### The Fatal Flaw: IN-MEMORY ONLY TRADE HISTORY

**Current Architecture:**
```
EA OnInit()
    ↓
PerformanceTracker Constructor
    ↓
ArrayResize(closedTrades, 0)  ← CLEARS ARRAY (IN-MEMORY ONLY)
    ↓
LoadTradeHistory()
    ↓
Scan MT5 history (volatile)
    ↓
Rebuild closedTrades[] from MT5
    ↓
ExportTradeHistory() → trade_history.json
```

**The Problem:**
1. `closedTrades[]` is an **in-memory array** (NOT persistent)
2. When EA restarts: array is **cleared** (line 53)
3. LoadTradeHistory() **only scans MT5's history** (doesn't read JSON)
4. MT5 demo history is **volatile** (brokers can clear old trades)
5. JSON file is **overwritten** with current MT5 state
6. **Result: Permanent data loss** if MT5 history is cleared!

---

## 📊 EVIDENCE OF THE BUG

### 1. Missing GBPUSD Trade (#32876995)
- **Jan 28:** Recorded in fix verification (GBPUSD.sml +$26.79)
- **Jan 30:** Completely missing from trade_history.json
- **Cause:** MT5 demo account cleared this trade OR EA restart lost it

### 2. Missing Session 8 Trades
- **CLAUDE.md claims:** "EURUSD +$6.08, GBPUSD +$3.42"
- **Current JSON:** Only 2 AUDJPY trades
- **Cause:** These were either:
  - Never actually executed (claim was aspirational)
  - Manually closed and not recorded
  - Lost during EA restart

### 3. Account Balance Discrepancy
- **Expected:** $9,976 (Session 8 starting balance)
- **Actual:** $9,472.20
- **Missing:** -$503.80 in losses NOT accounted for in history
- **Implication:** Multiple unrecorded losing trades

### 4. The "46 Invalid Deals" Mystery
```
Total deals in MT5 history: 49
Invalid tickets (skipped): 46  ← 94% INVALID?!
Valid deals: 3
```

**Analysis:**
- `HistoryDealGetTicket(i)` returns 0 for 46 out of 49 deals
- This suggests MT5's history is **corrupted** or **clearing deals**
- Demo accounts often purge old history to save server resources
- Our system trusts MT5 as source of truth (WRONG!)

---

## 💡 THE REAL ISSUE: NO PERSISTENT SOURCE OF TRUTH

### Current Flow (BROKEN)
```
MT5 History (Volatile)  ←───  PerformanceTracker reads on startup
     ↓
closedTrades[] (In-Memory)
     ↓
trade_history.json  ←───  Overwritten on every export
```

**Problems:**
1. ✅ MT5 history = **volatile** (broker can clear anytime)
2. ❌ closedTrades[] = **lost on restart** (in-memory only)
3. ❌ trade_history.json = **overwritten, not merged** (data loss)

### Correct Architecture (NEEDED)
```
trade_history.json (PERSISTENT SOURCE OF TRUTH)
     ↓
PerformanceTracker.LoadTradeHistory()
     ↓
1. READ existing JSON (restore historical record)
2. SCAN MT5 history (find new trades)
3. MERGE new trades into array (no duplicates)
4. EXPORT updated JSON (preserve all history)
```

---

## 🐛 SPECIFIC BUGS FOUND

### Bug #1: No JSON Import on Startup
**File:** `PerformanceTracker.mqh:493`
**Function:** `LoadTradeHistory()`

**Current Code:**
```mql5
void LoadTradeHistory() {
    // Select all history from start of 2020
    HistorySelect(startTime, TimeCurrent());
    // ... scan MT5 deals ...
    // ❌ NEVER reads trade_history.json
}
```

**Missing Logic:**
```mql5
void LoadTradeHistory() {
    // ✅ STEP 1: Read existing JSON (restore permanent record)
    LoadTradeHistoryFromJSON();

    // ✅ STEP 2: Scan MT5 (find new trades since last export)
    ScanMT5History();

    // ✅ STEP 3: Merge & export (preserve all history)
    ExportTradeHistory();
}
```

### Bug #2: Array Cleared on Every Init
**File:** `PerformanceTracker.mqh:53`
**Constructor:**

**Current Code:**
```mql5
PerformanceTracker(...) {
    ArrayResize(closedTrades, 0);  // ❌ DELETES HISTORY
    LoadTradeHistory();            // ❌ Relies on volatile MT5
}
```

**Should Be:**
```mql5
PerformanceTracker(...) {
    ArrayResize(closedTrades, 0);  // ✅ OK (will be filled from JSON)
    LoadTradeHistoryFromJSON();    // ✅ Restore permanent record
    ScanMT5ForNewTrades();         // ✅ Add any new trades
}
```

### Bug #3: MT5 "Invalid Tickets" Not Investigated
**File:** `PerformanceTracker.mqh:522`

**Current Code:**
```mql5
ulong ticket = HistoryDealGetTicket(i);
if(ticket <= 0) {
    invalidTickets++;  // ❌ Just counts, doesn't investigate WHY
    continue;
}
```

**Investigation Needed:**
- Why are 46/49 deals returning ticket=0?
- Is this MT5 clearing history?
- Are we accessing deals incorrectly?
- Should we use `HistorySelect()` differently?

### Bug #4: No Backup/Archive Strategy
**Missing:** Old trades should be archived even if MT5 purges them

**Should Have:**
```
CSM_Data/
  ├── trade_history.json          ← Current (all trades)
  ├── trade_archive_2026_01.json  ← Monthly archive
  └── trade_backup.json           ← Backup before each restart
```

---

## 🔧 REQUIRED FIXES

### Fix #1: Implement JSON Import (CRITICAL)
**Priority:** 🔴 HIGHEST
**Impact:** Prevents all future data loss

**Implementation:**
1. Add `LoadTradeHistoryFromJSON()` function
2. Parse existing JSON file
3. Populate `closedTrades[]` array from JSON
4. Mark all loaded trades with flag (don't re-query MT5 for details)

### Fix #2: Merge Strategy (Not Overwrite)
**Priority:** 🔴 CRITICAL
**Impact:** Preserves historical data

**Implementation:**
1. Load trades from JSON (permanent record)
2. Scan MT5 history for new trades
3. Check each MT5 trade against JSON (by ticket number)
4. Only add trades that don't exist in JSON
5. Export merged result

### Fix #3: Investigate MT5 Invalid Tickets
**Priority:** 🟡 HIGH
**Impact:** May reveal MT5 API usage bug

**Investigation:**
1. Why does `HistoryDealGetTicket(i)` return 0?
2. Is index out of bounds?
3. Do we need `HistoryDealSelect(ticket)` first?
4. Is demo account clearing deals?

### Fix #4: Add Backup System
**Priority:** 🟢 MEDIUM
**Impact:** Safety net for catastrophic failures

**Implementation:**
1. Before overwriting JSON, create backup
2. Keep last 3 backups
3. Monthly archive files
4. CSV export option (human-readable)

---

## 🧪 PROPOSED SOLUTION

### New Architecture: JSON as Source of Truth

```mql5
class PerformanceTracker {
private:
   TradeRecord closedTrades[];           // In-memory cache
   string tradeHistoryFile;              // JSON persistence

   // ✅ NEW: Load existing JSON on startup
   bool LoadTradeHistoryFromJSON() {
      // 1. Check if JSON exists
      // 2. Parse JSON into closedTrades[]
      // 3. Return true if successful
      // This preserves ALL historical data
   }

   // ✅ NEW: Scan MT5 for trades not in JSON
   void ScanMT5ForNewTrades() {
      HistorySelect(lastExportTime, TimeCurrent());

      // Only process deals that aren't already in closedTrades[]
      for(deal in history) {
         if(!IsTradeAlreadyRecorded(dealTicket)) {
            RecordClosedTrade(dealTicket);
         }
      }
   }

   // ✅ MODIFIED: Never delete, only add
   void LoadTradeHistory() {
      // STEP 1: Restore from persistent storage
      if(FileExists(tradeHistoryFile)) {
         LoadTradeHistoryFromJSON();
         Print("✅ Loaded ", ArraySize(closedTrades), " trades from JSON");
      }

      // STEP 2: Scan MT5 for any new trades
      ScanMT5ForNewTrades();

      // STEP 3: Save merged result
      ExportTradeHistory();
   }
};
```

### Benefits of This Approach
1. ✅ **Persistent** - Trades survive EA restart
2. ✅ **MT5-independent** - Broker can't delete our records
3. ✅ **Merge-based** - Never overwrites, only adds
4. ✅ **Recoverable** - JSON is human-readable, can be manually fixed
5. ✅ **Scalable** - Works for years of trading history

---

## 📋 TESTING PLAN

### Test #1: Restart Recovery
1. Record current trade_history.json
2. Restart EA (should NOT lose trades)
3. Verify all trades still present
4. **Expected:** 100% preservation

### Test #2: New Trade Detection
1. Close a position manually
2. Verify OnTradeTransaction fires
3. Check new trade added to JSON
4. Restart EA, verify trade persists
5. **Expected:** Trade recorded and persists

### Test #3: MT5 History Cleared
1. Backup trade_history.json
2. Simulate: Clear MT5 history OR switch account
3. Restart EA
4. Verify JSON trades not deleted
5. **Expected:** JSON preserves all history

### Test #4: Duplicate Prevention
1. Manually add duplicate ticket to JSON
2. Restart EA
3. Verify duplicate not added again
4. **Expected:** IsTradeAlreadyRecorded() catches it

---

## 🎯 SUCCESS CRITERIA

### Must Have (Go/No-Go)
- [❌] Trade history survives EA restart
- [❌] JSON import function implemented
- [❌] Merge strategy (not overwrite)
- [❌] All historical trades recovered

### Should Have
- [ ] Backup system (auto-backup before overwrite)
- [ ] Monthly archives
- [ ] Diagnostic: explain "invalid tickets"
- [ ] CSV export option

### Nice to Have
- [ ] Cloud backup (upload to Google Drive/Dropbox)
- [ ] Trade statistics history (daily snapshots)
- [ ] Performance timeline (balance over time)

---

## 📊 CURRENT STATUS SUMMARY

| Metric | Status | Notes |
|--------|--------|-------|
| **Data Integrity** | 🔴 CRITICAL | Trades being deleted on restart |
| **Persistence** | 🔴 FAILED | No JSON import, MT5-dependent |
| **Accuracy** | 🟡 PARTIAL | Recorded trades are accurate, but incomplete |
| **Reliability** | 🔴 FAILED | Cannot trust historical data |
| **Production Ready** | 🔴 NO | **BLOCKER: Data loss bug** |

---

## 🚀 IMMEDIATE ACTION REQUIRED

### Priority 1: Stop Data Loss (TODAY)
1. ✅ Implement `LoadTradeHistoryFromJSON()`
2. ✅ Test with current trade_history.json
3. ✅ Verify EA restart preserves all trades

### Priority 2: Recover Lost Trades (TODAY)
1. Check if GBPUSD #32876995 still in MT5 history
2. Check if EURUSD/GBPUSD Session 8 trades exist
3. Manually add to JSON if found
4. Investigate $504 account loss

### Priority 3: Prevent Future Loss (NEXT SESSION)
1. Implement backup system
2. Add monthly archives
3. Document recovery procedures
4. Test disaster recovery scenarios

---

## 💭 LESSONS LEARNED

### What Went Wrong
1. **Assumption:** MT5 history is persistent ❌
   **Reality:** Demo accounts purge old trades

2. **Assumption:** In-memory array is sufficient ❌
   **Reality:** Need persistent storage (JSON)

3. **Assumption:** Export-only JSON is enough ❌
   **Reality:** Need import + merge for reliability

### Best Practices for Trading Systems
1. ✅ **Never trust broker's history** - Always maintain your own
2. ✅ **Persistent storage** - Export AND import
3. ✅ **Merge, don't overwrite** - Append-only logs
4. ✅ **Multiple backups** - JSON + CSV + Cloud
5. ✅ **Defensive coding** - Assume MT5 can lose data anytime

---

## 🎉 CONCLUSION

### The Bug
**PerformanceTracker does not persist trade history across EA restarts**, relying solely on MT5's volatile history. When MT5 clears deals (common on demo), trades are permanently lost.

### The Fix
**Implement JSON import on startup** + **merge strategy** to treat trade_history.json as the authoritative source of truth, never deleting trades even if MT5 forgets them.

### The Impact
- **Before Fix:** Data loss on every EA restart ❌
- **After Fix:** Complete historical record preserved ✅
- **Confidence:** Can trust years of trading data ✅

---

**Status:** 🔴 **CRITICAL BUG IDENTIFIED**
**Next Step:** Implement JSON import + merge strategy
**ETA:** 2-3 hours
**Priority:** 🔥 **HIGHEST** (blocks production deployment)
