# Broker Symbol Suffix Guide
**Date:** February 3, 2026
**Context:** Understanding why brokers use different symbol suffixes

---

## 🎯 Quick Answer

**Symbol suffixes indicate the account type:**

- `EURUSD` (no suffix) = **Standard/Spread account** (wide spreads, no commission)
- `EURUSD.r` = **Raw account** (tight spreads + commission)
- `EURUSD.sml` = **FusionMarkets suffix** (broker-specific naming)
- `EURUSD.ecn` = **ECN account** (commission-based)
- `EURUSD.raw` = **Raw spread account** (commission-based)

**You MUST use symbols matching your account type!**

---

## 📊 Why Both Versions Exist?

**Broker Architecture:**

Modern MT5 brokers often run **multiple account types on the same server**:

```
FP Markets MT5 Server:
├── Standard Accounts (spread-based)
│   ├── EURUSD (0.8-1.5 pip spread, no commission)
│   ├── GBPUSD (1.0-2.0 pip spread, no commission)
│   └── XAUUSD (30-60 pip spread, no commission)
│
└── Raw Accounts (commission-based)
    ├── EURUSD.r (0.0-0.2 pip spread, $3 commission)
    ├── GBPUSD.r (0.1-0.4 pip spread, $3 commission)
    └── XAUUSD.r (5-12 pip spread, $3 commission)
```

**This allows:**
1. Easy switching between account types
2. Same MT5 platform for all clients
3. Clear differentiation of pricing models

---

## 🔍 How to Identify Your Account Type

### Method 1: Check Symbol Suffix in Market Watch

1. Open MT5
2. Open **Market Watch** (Ctrl+M)
3. Right-click → **Show All** (to see all available symbols)
4. Look at the symbols:

**If you see:**
```
EURUSD (no suffix)
GBPUSD (no suffix)
XAUUSD (no suffix)
```
→ You have a **Standard/Spread account**

**If you see:**
```
EURUSD.r
GBPUSD.r
XAUUSD.r
```
→ You have a **Raw account** (what you want!)

**You might see BOTH!** This is normal. Your account type determines which you should use.

---

### Method 2: Check Account Type in Terminal

1. Open **Terminal** (Ctrl+T)
2. Click **Account History** tab
3. Right-click → **Account Statement**
4. Look for:
   - Account Type: "Raw" or "Standard"
   - Commission charges (if you see commission → Raw account)

---

### Method 3: Check with Broker

**Ask support:** "What account type is my account ID XXXXX?"

**They'll tell you:**
- Standard / Classic / Fixed Spread → Use symbols without suffix
- Raw / ECN / Zero Spread → Use symbols with suffix (.r, .ecn, .raw)

---

## ⚙️ Common Broker Suffixes

| Broker | Standard Account | Raw/ECN Account | Notes |
|--------|-----------------|-----------------|-------|
| **FP Markets** | `EURUSD` | `EURUSD.r` | .r = Raw |
| **IC Markets** | `EURUSD` | `EURUSD` (same!) | Account type determines pricing |
| **Pepperstone** | `EURUSD` | `EURUSD` (same!) | Account type determines pricing |
| **FusionMarkets** | `EURUSD` | `EURUSD.sml` | .sml = broker suffix |
| **XM** | `EURUSD` | `EURUSD.` (dot only) | Period suffix |
| **FXCM** | `EUR/USD` | `EUR/USD` | Slash notation |
| **Tickmill** | `EURUSD` | `EURUSDpro` | "pro" suffix |

**No standard naming!** Each broker chooses their own suffix convention.

---

## 🚨 Critical: Use Correct Symbols!

### ❌ WRONG: Using Standard Symbols on Raw Account

**Problem:**
```
You have: Raw account (.r symbols)
You trade: EURUSD (standard symbol)

Result:
- ❌ Broker may reject trades
- ❌ Wrong spread charged (wide spread instead of tight)
- ❌ Commission structure incorrect
- ❌ Poor execution
```

**Example:**
```
Account: FP Markets Raw ($3 commission per lot)
Symbol used: EURUSD (standard)

Expected cost: 0.1 pip spread + $0.03 commission = $0.04
Actual cost:   1.5 pip spread + no commission = $0.15

You're paying 4x more than necessary!
```

---

### ✅ CORRECT: Matching Symbols to Account Type

**Raw Account → Use .r Symbols:**
```
Account: FP Markets Raw
Symbols: EURUSD.r, GBPUSD.r, XAUUSD.r

Result:
✅ Correct raw spreads (0.0-0.2 pips)
✅ Correct commission ($3.00 per lot)
✅ Best execution quality
```

**Standard Account → Use Standard Symbols:**
```
Account: FP Markets Standard
Symbols: EURUSD, GBPUSD, XAUUSD

Result:
✅ Correct pricing (wider spreads, no commission)
✅ Proper execution
```

---

## 🔧 How to Update Your EAs for New Broker

### Step 1: Identify Suffix in Market Watch

1. Open MT5 with new broker
2. Check Market Watch (Ctrl+M)
3. Note the symbol format:
   - `EURUSD.r` → suffix is `.r`
   - `EURUSD.sml` → suffix is `.sml`
   - `EURUSD` (no suffix) → blank suffix

---

### Step 2: Update MainTradingEA.mq5

**Find line ~24:**
```mql5
input string TradedSymbols = "EURUSD.OLD,GBPUSD.OLD,AUDJPY.OLD,XAUUSD.OLD";
```

**Replace with new suffix:**
```mql5
input string TradedSymbols = "EURUSD.r,GBPUSD.r,AUDJPY.r,XAUUSD.r";
```

**Or if no suffix:**
```mql5
input string TradedSymbols = "EURUSD,GBPUSD,AUDJPY,XAUUSD";
```

---

### Step 3: Update TradeExecutor.mqh

**Check GetSpreadMultiplier() function** (~line 300):

**Make sure new suffix is handled:**
```mql5
double GetSpreadMultiplier(string symbol)
{
   // Remove broker suffix for matching
   string cleanSymbol = symbol;
   StringReplace(cleanSymbol, ".sml", "");   // FusionMarkets
   StringReplace(cleanSymbol, ".ecn", "");   // ECN accounts
   StringReplace(cleanSymbol, ".raw", "");   // Raw accounts
   StringReplace(cleanSymbol, ".r", "");     // FP Markets Raw ← ADD THIS!

   // ... rest of function
}
```

**Add your broker's suffix** if not already there!

---

### Step 4: Update CSMMonitor (C# Dashboard)

**Find pairMappings** (~line 477 and 1786):

```csharp
var pairMappings = new Dictionary<string, string>
{
    ["EURUSD"] = "EURUSD.r",   // Update suffix here
    ["GBPUSD"] = "GBPUSD.r",
    ["AUDJPY"] = "AUDJPY.r",
    ["XAUUSD"] = "XAUUSD.r"
};
```

**This tells CSMMonitor to look for signal files like:**
- `EURUSD.r_signals.json`
- `GBPUSD.r_signals.json`
- etc.

---

### Step 5: Recompile & Test

1. **Compile MainTradingEA** (F7 in MetaEditor)
2. **Rebuild CSMMonitor** (Visual Studio or build tool)
3. **Test on demo account** first!
4. **Verify signal files** are created with correct names
5. **Check CSMMonitor** reads files correctly

---

## 🧪 Testing Checklist (New Broker)

### Before Live Trading

- [ ] **Identify account type** (Standard vs Raw/ECN)
- [ ] **Check symbol suffix** in Market Watch
- [ ] **Update MainTradingEA.mq5** (TradedSymbols input)
- [ ] **Update TradeExecutor.mqh** (add new suffix to GetSpreadMultiplier)
- [ ] **Update CSMMonitor** (pairMappings dictionary)
- [ ] **Recompile all EAs** (0 errors expected)
- [ ] **Rebuild CSMMonitor**
- [ ] **Deploy on demo account**
- [ ] **Verify signal files created** (check CSM_Signals folder)
- [ ] **Check signal file names** (e.g., EURUSD.r_signals.json)
- [ ] **Test CSMMonitor** reads signals correctly
- [ ] **Execute test trade** (0.01 lots)
- [ ] **Verify spread charged** matches account type
- [ ] **Check commission** (if Raw account)
- [ ] **Run for 1-2 weeks** on demo before live

---

## 📋 Common Broker Suffix Patterns

### Pattern 1: Same Symbols, Different Accounts
**Brokers:** IC Markets, Pepperstone, OANDA

```
Standard account:
  Symbols: EURUSD, GBPUSD, XAUUSD
  Pricing: Wide spreads, no commission

Raw/ECN account:
  Symbols: EURUSD, GBPUSD, XAUUSD (SAME!)
  Pricing: Tight spreads + commission

The account type determines pricing, not the symbol name!
```

**How to update EAs:**
```mql5
// No suffix change needed!
input string TradedSymbols = "EURUSD,GBPUSD,AUDJPY,XAUUSD";
```

---

### Pattern 2: Different Suffix for Raw Accounts
**Brokers:** FP Markets (.r), Tickmill (pro), XM (.)

```
Standard account:
  Symbols: EURUSD, GBPUSD, XAUUSD

Raw account:
  Symbols: EURUSD.r, GBPUSD.r, XAUUSD.r
```

**How to update EAs:**
```mql5
// Add suffix to all symbols
input string TradedSymbols = "EURUSD.r,GBPUSD.r,AUDJPY.r,XAUUSD.r";
```

---

### Pattern 3: Custom Broker Suffix (All Accounts)
**Brokers:** FusionMarkets (.sml), some regional brokers

```
All accounts use suffix:
  Symbols: EURUSD.sml, GBPUSD.sml, XAUUSD.sml
```

**How to update EAs:**
```mql5
// Add broker-specific suffix
input string TradedSymbols = "EURUSD.sml,GBPUSD.sml,AUDJPY.sml,XAUUSD.sml";
```

---

## 🎯 Your Current Setup (FP Markets Raw)

**Broker:** FP Markets
**Account Type:** Raw Account (commission-based)
**Suffix:** `.r`

**Symbols to use:**
- EURUSD.r
- GBPUSD.r
- AUDJPY.r
- XAUUSD.r

**Files updated:**
- ✅ MainTradingEA.mq5 (TradedSymbols = ".r" suffix)
- ✅ TradeExecutor.mqh (handles .r suffix stripping)
- ✅ CSMMonitor (pairMappings = ".r" suffix)

**Status:** Ready to deploy on FP Markets demo!

---

## 🚀 Quick Migration Checklist

**When switching brokers:**

1. ✅ Open demo account with new broker
2. ✅ Check Market Watch for symbol suffix
3. ✅ Update MainTradingEA.mq5 (1 line)
4. ✅ Update TradeExecutor.mqh (add suffix to strip list)
5. ✅ Update CSMMonitor pairMappings (2 locations)
6. ✅ Recompile EAs (F7)
7. ✅ Rebuild CSMMonitor
8. ✅ Test on demo for 1-2 weeks
9. ✅ Verify signal files created correctly
10. ✅ Confirm costs match expectations

**Total update time:** ~15 minutes

---

## 💡 Pro Tips

### Tip 1: Always Check Both Versions
**Some brokers show BOTH standard and raw symbols in Market Watch!**

Example (FP Markets):
```
EURUSD    ← Standard account symbol (don't use!)
EURUSD.r  ← Raw account symbol (use this!)
```

**How to verify you're using the right one:**
- Place a test trade (0.01 lots)
- Check if commission is charged
- If commission = $0.03-0.07 → you're using Raw symbols ✅
- If commission = $0 and spread is wide → you're using Standard symbols ❌

---

### Tip 2: Hide Unused Symbols
**Reduce clutter in Market Watch:**

1. Right-click symbol → **Hide**
2. Hide all standard symbols (no suffix)
3. Keep only .r symbols visible

**Result:** No confusion about which symbols to trade!

---

### Tip 3: Symbol Template File
**Create a text file for each broker:**

`broker_symbols.txt`:
```
FP Markets Raw:
EURUSD.r,GBPUSD.r,AUDJPY.r,XAUUSD.r

IC Markets Raw:
EURUSD,GBPUSD,AUDJPY,XAUUSD

FusionMarkets:
EURUSD.sml,GBPUSD.sml,AUDJPY,XAUUSD.sml
```

**Copy-paste when switching!**

---

## ❓ FAQ

**Q: Why doesn't my broker use suffixes?**
A: Some brokers (IC Markets, Pepperstone) use the same symbol names for all account types. The account type determines pricing, not the symbol name.

**Q: Can I trade both Standard and Raw symbols on the same account?**
A: Technically yes, but **DON'T!** You'll get charged incorrectly. Always match symbols to your account type.

**Q: What if I accidentally trade the wrong symbol?**
A: You'll pay more in spreads or get wrong commission structure. Close the trade and re-enter with correct symbol.

**Q: How do I know which suffix my broker uses?**
A: Check Market Watch (Ctrl+M → Show All) or ask broker support: "What symbols should I use for a Raw/ECN account?"

**Q: Do I need to update Strategy_AnalysisEA too?**
A: No! It uses `_Symbol` variable which automatically detects the chart symbol (including suffix). Just attach it to EURUSD.r chart and it works.

---

**Summary:** Symbol suffixes indicate account type. Always use symbols matching your account (Raw account → use .r symbols). Update 3 files when switching brokers, test on demo, verify costs are correct. Done! 🚀

---

*Guide created: February 3, 2026*
*Your setup: FP Markets Raw account (.r suffix) ✅*
