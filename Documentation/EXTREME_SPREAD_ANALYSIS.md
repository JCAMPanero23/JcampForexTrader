# Extreme Spread Analysis - When NOT to Trade
**Date:** February 3, 2026
**Critical Finding:** 700+ pip spreads = DISASTER for profitability

---

## 🚨 CRITICAL ANSWER: NEVER TRADE EXTREME SPREADS

**Rule:** If spread > 50 pips, DO NOT TRADE. Period.

**Your question:** "Can we trade at 100-700 pip spreads?"
**Answer:** **ABSOLUTELY NOT** - This would destroy your account.

---

## Cost Analysis - Extreme Spreads

### Example: Gold Trade @ 700 Pip Spread (0.01 lot)

**Entry Cost:**
```
700 pips × $1.00 per pip = $70.00 just to enter!
```

**Exit Cost:**
```
700 pips × $1.00 per pip = $70.00 to exit!
```

**TOTAL ROUND-TRIP COST:**
```
$70 + $70 = $140.00 for a 0.01 lot trade!
```

**Your typical profit target:** $50 (50 pips)
**Your cost to trade:** $140
**NET RESULT:** -$90 LOSS even if you hit take profit!

**Profit needed to break even:** 1,400 pips ($140 profit to cover $140 spread)

---

## Spread vs Profitability Table (0.01 lot)

| Spread | Entry Cost | Round-Trip | Profit Needed to Break Even | Verdict |
|--------|------------|------------|------------------------------|---------|
| 5 pips | $0.50 | $1.00 | 10 pips | ✅ Excellent (commission broker) |
| 10 pips | $1.00 | $2.00 | 20 pips | ✅ Good (commission broker) |
| 20 pips | $2.00 | $4.00 | 40 pips | ✅ Acceptable (current broker, prime hours) |
| 30 pips | $3.00 | $6.00 | 60 pips | ⚠️ Maximum limit (Session 9 setting) |
| 50 pips | $5.00 | $10.00 | 100 pips | ❌ Poor - Avoid |
| 100 pips | $10.00 | $20.00 | 200 pips | ❌ TERRIBLE - DO NOT TRADE |
| 200 pips | $20.00 | $40.00 | 400 pips | ❌ CATASTROPHIC |
| 500 pips | $50.00 | $100.00 | 1,000 pips | ❌ INSANE |
| 700 pips | $70.00 | $140.00 | 1,400 pips | ❌ ACCOUNT SUICIDE |

**Your TP:** 50 pips = $50 profit
**Your SL:** 50 pips = $50 loss

At 700 pip spread, you need **28x your normal profit target** just to break even!

---

## When Do Extreme Spreads Occur?

### Analysis from Session 9 Data (352,116 bars)

**Spread Distribution:**
```
0-5 pips:     0.00%  (0 bars) - Never happens
5-10 pips:    0.00%  (0 bars) - Never happens
10-15 pips:   22.03% (77,558 bars) - Rare, best case
15-20 pips:   14.82% (52,189 bars)
20-30 pips:   32.26% (113,588 bars) ← Most common
30-50 pips:   27.40% (96,486 bars) ← High but occasional
50-100 pips:  ~3.00% (~10,000 bars) ← Extreme
100+ pips:    ~0.49% (~1,700 bars) ← CATASTROPHIC
Max seen:     500 pips (outlier)
```

### Common Causes of Extreme Spreads

1. **Market Open/Close (Sunday/Friday)**
   - Sunday 21:00-23:00 UTC: Market opening, low liquidity
   - Friday 21:00-23:00 UTC: Market closing, liquidity drying up
   - **Spreads:** 100-300 pips common

2. **Major News Events**
   - NFP (Non-Farm Payroll) first 5 minutes
   - FOMC announcements
   - Central bank surprise decisions
   - Geopolitical shocks (war, terrorism, etc.)
   - **Spreads:** 50-200 pips during event

3. **Asian Session Low Liquidity**
   - 01:00-05:00 UTC+2 (your broker time)
   - Very few traders active
   - **Spreads:** 30-80 pips (we already block this in Session 9!)

4. **Flash Crashes / Market Panic**
   - Sudden market moves (e.g., Swiss Franc 2015, COVID crash 2020)
   - Circuit breakers triggered
   - **Spreads:** 200-1000+ pips (brokers protect themselves)

5. **Broker Manipulation**
   - Some brokers artificially widen spreads to discourage trading
   - Especially during high volatility
   - **Spreads:** Variable, can spike to 500+ pips

---

## Real-World Examples (Why You Shouldn't Trade Wide Spreads)

### Example 1: Sunday Market Open (Spread: 150 pips)

**Scenario:** You see a strong signal on Sunday 22:00 UTC+2

**Entry:**
```
Price: 2650.00
Spread: 150 pips
Actual entry after spread: 2665.00 (BUY) or 2635.00 (SELL)
Cost: $15.00 per 0.01 lot just to enter!
```

**Your SL:** 50 pips = 2645.00
**But you entered at:** 2665.00 (due to spread)
**INSTANT LOSS:** You're already -20 pips in the hole BEFORE market moves!

**Result:** You're starting with a -$20 loss. You need 70 pips profit just to break even.

### Example 2: NFP News Event (Spread: 200 pips)

**Scenario:** NFP report released, spread spikes to 200 pips

**Entry:**
```
Price: 2650.00
Spread: 200 pips
Actual entry: 2670.00 (BUY)
Cost: $20.00 per 0.01 lot
```

**Market moves in your favor:** +100 pips to 2750.00
**Exit spread:** Still 100 pips (volatility high)
**Exit price:** 2740.00 (exit spread eats 10 pips)

**Calculation:**
```
Entry: 2670.00 (after 200 pip spread)
Exit:  2740.00 (after 100 pip spread)
Profit: 70 pips = $70

BUT:
Entry spread cost: $20
Exit spread cost:  $10
Net profit: $70 - $30 = $40

If you waited for spread to normalize (20 pips):
Entry: 2652.00 (after 20 pip spread)
Exit:  2748.00 (after 20 pip spread)
Profit: 96 pips = $96
Spread cost: $4
Net profit: $96 - $4 = $92

DIFFERENCE: $92 - $40 = $52 MORE PROFIT (130% better!)
```

**Lesson:** Waiting for spread to normalize = 2.3x better profit!

### Example 3: Your 700 Pip Scenario

**Scenario:** Spread hits 700 pips (extreme event)

**Entry:**
```
Price: 2650.00
Spread: 700 pips
Actual entry: 2720.00 (BUY) or 2580.00 (SELL)
Cost: $70.00 per 0.01 lot
```

**You need to be right by:** 1,400 pips just to break even!
**Gold's typical daily range:** 100-300 pips
**Your TP target:** 50 pips

**Result:** Even if you catch a 100 pip move perfectly, you LOSE $40!

```
Perfect 100 pip move:
Entry: 2720.00
Exit:  2820.00
Profit: 100 pips = $100

Spread costs:
Entry: $70
Exit:  $70 (assume spread still wide)
Total cost: $140

NET: $100 - $140 = -$40 LOSS
```

**Verdict:** IMPOSSIBLE TO PROFIT. You're fighting a $140 handicap for a $50 profit target.

---

## Session 9 Protection (Already Implemented!)

**Your Current Settings:**
```mql5
SpreadMultiplierXAUUSD = 15.0
MaxSpreadPips = 2.0

Maximum allowed spread: 2.0 × 15.0 = 30 pips
```

**Additional Protection in TradeExecutor:**
```mql5
// Spread quality logic
if(quality == SPREAD_POOR)  // > 35 pips
{
   Print("⚠️ Gold spread too wide - REJECTED");
   return false;
}
```

**Result:** Your EA will AUTOMATICALLY REJECT spreads > 30-35 pips!

**This means:**
- ✅ 100 pip spread: BLOCKED automatically
- ✅ 200 pip spread: BLOCKED automatically
- ✅ 700 pip spread: BLOCKED automatically

**You are ALREADY protected!** Session 9 optimization ensures you never trade extreme spreads.

---

## What To Do When Spreads Are Extreme

### ❌ DON'T:
- Don't panic trade during news events
- Don't trade Sunday/Friday market open/close
- Don't "chase" a signal if spread is > 50 pips
- Don't assume spread will normalize quickly
- Don't increase position size to "make up" for spread costs

### ✅ DO:
- **Wait for spread to normalize** (below 30 pips)
- **Skip the trade** if signal expires before spread normalizes
- **Log the event** for future analysis
- **Check broker feeds** - if spread is consistently extreme, consider switching brokers
- **Review your settings** - ensure spread multiplier is protecting you

---

## Recommended Spread Limits by Asset

### Gold (XAUUSD)
```
EXCELLENT:   < 15 pips (rare, execute immediately)
GOOD:        15-25 pips (normal prime hours)
ACCEPTABLE:  25-30 pips (acceptable with high confidence 120+)
MAXIMUM:     30 pips (hard limit - Session 9 setting)
REJECT:      > 30 pips (DO NOT TRADE)
```

### Forex Pairs (EURUSD, GBPUSD, AUDJPY)
```
EXCELLENT:   < 1 pip
GOOD:        1-2 pips
MAXIMUM:     2 pips (current setting × 1.0 multiplier)
REJECT:      > 2 pips
```

---

## Broker Quality Check

**Question:** Is your broker widening spreads excessively?

**Normal vs Suspicious Spreads:**

**Normal (Quality Broker):**
```
EURUSD: 0.5-1.5 pips (even during news)
GBPUSD: 0.8-2.0 pips
XAUUSD: 10-40 pips (20-25 pips prime hours)
```

**Suspicious (Poor Broker):**
```
EURUSD: 3-10 pips during normal hours
GBPUSD: 5-15 pips during normal hours
XAUUSD: 50-200 pips during normal hours (NOT news events)
```

**If you regularly see 700 pip spreads OUTSIDE of:**
- Market open/close (Sunday 21:00-23:00, Friday 21:00-23:00)
- Major news events (NFP, FOMC)
- Flash crashes

**Then your broker is likely:**
1. **Poor quality** - inadequate liquidity providers
2. **Manipulative** - artificially widening spreads to prevent trading
3. **Offshore/unregulated** - not held to standards

**Action:** Switch to a regulated broker (IC Markets, Pepperstone, etc.)

---

## Cost of Waiting vs Trading Immediately

**Scenario:** Signal appears, spread is 100 pips. Do you wait or trade now?

**Option A: Trade Immediately (100 pip spread)**
```
Entry cost: $10
Exit cost:  $10 (assume normalizes)
Total cost: $20

Profit target: $50
Net profit: $50 - $20 = $30 (40% eaten by spread!)
```

**Option B: Wait 15 Minutes for Spread to Normalize (20 pips)**
```
Entry cost: $2
Exit cost:  $2
Total cost: $4

Profit target: $50
Net profit: $50 - $4 = $46 (8% eaten by spread)

Risk: Signal may expire or market may move against you
```

**Analysis:**
- Waiting saves: $16 per trade (53% better outcome)
- Risk: Miss the trade if market moves before spread normalizes
- Trade-off: Worth waiting if spread > 50 pips

**Recommendation:**
- If spread < 30 pips: Trade immediately
- If spread 30-50 pips: Wait 5-10 minutes, re-check
- If spread > 50 pips: Skip the trade, wait for next signal

---

## Updated MainTradingEA Logic (Recommendation)

**Add logging to track when extreme spreads occur:**

```mql5
// In TradeExecutor.mqh ValidateSignal()

if(spreadPips > 50.0)
{
   Print("⚠️ EXTREME SPREAD DETECTED: ", signal.symbol, " = ", spreadPips, " pips");
   Print("   Time: ", TimeToString(TimeCurrent()));
   Print("   This spread is ", (spreadPips / 30.0), "x our maximum limit");
   Print("   DO NOT TRADE - Waiting for normalization");
   return false;
}

if(spreadPips > 100.0)
{
   Print("🚨 CATASTROPHIC SPREAD: ", signal.symbol, " = ", spreadPips, " pips!");
   Print("   Possible causes: Market open/close, news event, broker issue");
   Print("   Check broker feed quality");
}
```

This will help you identify:
1. When extreme spreads occur
2. Patterns (always Sunday? Always during news?)
3. If your broker is problematic

---

## Final Verdict

**Your Question:** "Can we trade at 100-700 pip spreads?"

**Answer:**
- **100 pips:** NO - You need 200 pips profit just to break even ($20 cost vs $50 target)
- **200 pips:** HELL NO - You need 400 pips profit to break even
- **700 pips:** ABSOLUTELY NOT - You need 1,400 pips profit to break even (28x your target!)

**Session 9 Protection:** ✅ You're already protected! 30 pip maximum enforced.

**What This Means:**
- Your EA will automatically skip trades when spread > 30 pips
- You'll never accidentally trade at 100-700 pip spreads
- You're protected from account suicide

**If You See 700 Pip Spreads Regularly:**
1. Check the time (market open/close?)
2. Check for news events
3. If neither, your broker is POOR QUALITY → switch immediately

**Recommended Action:**
- Keep Session 9 settings (30 pip max) ✅
- Monitor logs for extreme spread warnings
- Consider switching to commission broker (5-12 pip spreads vs 20-700!)

---

**Bottom Line:** Trading at 700 pip spread = Financial suicide. Session 9 protects you. Keep it that way.

---

*Analysis Date: February 3, 2026*
*Verdict: NEVER trade spreads > 50 pips. Session 9 enforces 30 pip max. You're protected.*
