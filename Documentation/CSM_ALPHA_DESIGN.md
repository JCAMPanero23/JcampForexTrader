# CSM Alpha - 9-Currency System Design

**Date:** January 23, 2026
**Purpose:** Design specification for CSM with Gold integration
**Status:** Design Phase

---

## Overview

The **CSM Alpha** system extends the traditional 8-currency CSM to include **Gold (XAU)** as the 9th "currency" in the competitive strength scoring system.

### Why Gold as a Currency?

Gold behaves like a currency in forex markets:
- **Safe Haven:** Strengthens during market fear/uncertainty
- **Inflation Hedge:** Competes with fiat currencies
- **Risk Indicator:** When Gold strong + JPY strong = Risk-Off mode

By treating Gold as the 9th currency in CSM, we automatically get a **Market State Detector**:
- Gold strength 80-100 = Fear/Panic = Risk-Off
- Gold strength 0-20 = Optimism = Risk-On
- Gold strength ~50 = Neutral

---

## 9-Currency CSM Architecture

### Currency List
```cpp
string currencies[9] = {
    "USD",  // US Dollar
    "EUR",  // Euro
    "GBP",  // British Pound
    "JPY",  // Japanese Yen
    "CHF",  // Swiss Franc
    "AUD",  // Australian Dollar
    "CAD",  // Canadian Dollar
    "NZD",  // New Zealand Dollar
    "XAU"   // Gold
};
```

### Pair List (20 pairs)

**Traditional Currency Pairs (16):**
```cpp
"EURUSD", "GBPUSD", "USDJPY", "USDCHF",
"USDCAD", "AUDUSD", "NZDUSD", "EURGBP",
"GBPNZD", "AUDNZD", "NZDCAD", "NZDJPY",
"GBPJPY", "GBPCHF", "GBPCAD", "EURJPY"
```

**Gold Pairs (4 synthetic + 1 real):**
```cpp
"XAUUSD",  // Real pair (broker provides)
"XAUEUR",  // Synthetic: XAUUSD / EURUSD
"XAUJPY",  // Synthetic: XAUUSD * USDJPY
"XAUGBP",  // Synthetic: XAUUSD / GBPUSD
"XAUAUD"   // Synthetic: XAUUSD / AUDUSD
```

---

## Synthetic Gold Pair Calculation

### Why Synthetic Pairs?

Most brokers only offer **XAUUSD**. To calculate Gold strength fairly in the competitive CSM system, we need Gold paired against multiple currencies.

**Solution:** Calculate synthetic Gold pairs using cross-rates.

### Cross-Rate Formulas

```cpp
// Gold priced in EUR (Gold per Euro)
double XAUEUR = XAUUSD / EURUSD;

// Gold priced in JPY (Gold per 100 Yen)
double XAUJPY = XAUUSD * USDJPY;

// Gold priced in GBP (Gold per Pound)
double XAUGBP = XAUUSD / GBPUSD;

// Gold priced in AUD (Gold per Australian Dollar)
double XAUAUD = XAUUSD / AUDUSD;
```

### Example Calculation

**Scenario:**
- XAUUSD = 2050.00 (Gold costs $2050 per ounce)
- EURUSD = 1.0500 (1 EUR = 1.05 USD)

**Synthetic XAUEUR:**
```
XAUEUR = 2050.00 / 1.0500 = 1952.38
```

**Meaning:** Gold costs 1952.38 EUR per ounce.

**24-Hour Price Change:**
```
If XAUEUR increased from 1900 to 1952.38:
Price_Change_24h = (1952.38 - 1900) / 1900 = +2.76%

In CSM:
- XAU strength += 2.76 * 100 * 2.0 = +5.52
- EUR strength -= 5.52
```

---

## CSM Calculation Algorithm (Updated)

### Step 1: Initialize Strengths
```cpp
for(int i = 0; i < 9; i++)  // Now 9 currencies
{
    csm_data[i].current_strength = 50.0;  // Neutral
    csm_data[i].strength_change_24h = 0.0;
}
```

### Step 2: Calculate Real Gold Price
```cpp
// Get XAUUSD (real pair from broker)
double xauusd_current = iClose("XAUUSD", AnalysisTimeframe, 0);
double xauusd_24h_ago = iClose("XAUUSD", AnalysisTimeframe, bars_24h);
```

### Step 3: Calculate Synthetic Gold Pairs
```cpp
// Get required currency pairs
double eurusd_current = iClose("EURUSD", AnalysisTimeframe, 0);
double eurusd_24h_ago = iClose("EURUSD", AnalysisTimeframe, bars_24h);

// Synthetic XAUEUR (current)
double xaueur_current = xauusd_current / eurusd_current;

// Synthetic XAUEUR (24h ago)
double xaueur_24h_ago = xauusd_24h_ago / eurusd_24h_ago;

// Calculate 24h price change for XAUEUR
double xaueur_change_24h = (xaueur_current - xaueur_24h_ago) / xaueur_24h_ago;
```

### Step 4: Accumulate Strength (Same as Before)
```cpp
// For each pair (real or synthetic)
for(int i = 0; i < 20; i++)  // Now 20 pairs
{
    double price_change = pair_data[i].price_change_24h;
    double weight = 1.0;

    // Special weighting (same as before)
    if(pair == "XAUUSD" || pair == "EURUSD" || pair == "GBPUSD")
        weight = 1.5;

    double strength_change = price_change * 100.0 * 2.0 * weight;

    // Add to base currency, subtract from quote
    csm_data[base_idx].current_strength += strength_change;
    csm_data[quote_idx].current_strength -= strength_change;
}
```

### Step 5: Normalize to 0-100 (Same as Before)
```cpp
// Find min and max
double min_strength = csm_data[0].current_strength;
double max_strength = csm_data[0].current_strength;

for(int i = 1; i < 9; i++)  // Now 9 currencies
{
    if(csm_data[i].current_strength < min_strength)
        min_strength = csm_data[i].current_strength;
    if(csm_data[i].current_strength > max_strength)
        max_strength = csm_data[i].current_strength;
}

// Normalize
double range = max_strength - min_strength;
for(int i = 0; i < 9; i++)
{
    csm_data[i].current_strength =
        ((csm_data[i].current_strength - min_strength) / range) * 100.0;
}
```

---

## Market State Detection Using Gold

### Interpretation Guide

| Gold Strength | JPY Strength | Market State | Trading Implication |
|---------------|--------------|--------------|---------------------|
| 80-100 | 80-100 | **PANIC** | Short AUDJPY, Buy XAUUSD |
| 80-100 | 0-20 | **Gold Rally** | Buy XAUUSD, neutral on risk |
| 0-20 | 80-100 | **Yen Safe Haven** | Short AUDJPY, caution on XAUUSD |
| 0-20 | 0-20 | **RISK ON** | Buy AUDJPY, avoid XAUUSD |
| 40-60 | 40-60 | **NEUTRAL** | Use technicals (EMA, ADX) |

### Example Scenarios

**Scenario 1: Market Crash**
```
CSM Output:
- XAU: 95 (very strong - everyone buying gold)
- JPY: 90 (very strong - safe haven demand)
- AUD: 15 (very weak - risk currencies sold)
- USD: 60 (mixed - reserve currency but risk-off)

Signal: PANIC MODE
- ✅ Short AUDJPY (Risk-Off trade)
- ✅ Buy XAUUSD (Safe haven)
- ❌ Avoid GBPUSD (too chaotic)
```

**Scenario 2: Economic Boom**
```
CSM Output:
- XAU: 10 (very weak - nobody wants safe havens)
- JPY: 5 (very weak - risk currencies in demand)
- AUD: 85 (very strong - commodity currency thriving)
- USD: 45 (weakish - capital flowing to higher yields)

Signal: RISK ON
- ✅ Buy AUDJPY (Risk-On trade)
- ❌ Avoid XAUUSD (downtrend)
- ✅ Buy GBPUSD if GBP strong
```

**Scenario 3: USD Strength + Gold Strength**
```
CSM Output:
- XAU: 80 (strong - inflation fears)
- USD: 85 (strong - Fed hiking rates)
- EUR: 20 (weak - ECB dovish)
- JPY: 30 (weak - BoJ still easing)

Signal: INFLATION FEAR
- ✅ Buy XAUUSD (Gold as inflation hedge)
- ✅ Buy EURUSD (wait, USD strong? Better skip)
- ⚠️ Conflict: Gold and USD both strong = complex macro environment
- → Use lower position sizes, higher confidence threshold
```

---

## Implementation Checklist

### Phase 1: CSM_AnalysisEA.mq5
- [ ] Add XAU to currencies array (9 currencies)
- [ ] Add XAUUSD to major_pairs array
- [ ] Implement synthetic Gold pair calculation
- [ ] Add 4 synthetic Gold pairs to pair_data array (20 pairs total)
- [ ] Update normalization loop to handle 9 currencies
- [ ] Export Gold strength to csm_current.txt

### Phase 2: Strategy_AnalysisEA.mq5
- [ ] Read Gold strength from CSM
- [ ] Add XAUUSD symbol support
- [ ] Configure XAUUSD to use TrendRider only (skip RangeRider)
- [ ] Update signal export to include Gold signals

### Phase 3: MainTradingEA.mq5
- [ ] Read XAUUSD_signals.json
- [ ] Update spread configuration for XAUUSD (~0.3 pips)
- [ ] Test Gold trade execution on demo

---

## Expected CSM Output Format

**csm_current.txt:**
```
USD,65.2
EUR,42.8
GBP,58.3
JPY,35.1
CHF,48.6
AUD,71.4
CAD,55.9
NZD,38.7
XAU,82.5
```

**Interpretation:**
- AUD strongest (71.4) = Risk-On
- Gold very strong (82.5) = Fear/Safe Haven demand
- **Conflict!** AUD strong + Gold strong = Mixed signals
- → Strategy should require higher confidence or skip trade

---

## Testing Strategy

### Unit Tests (Demo)
1. **Synthetic Pair Accuracy:**
   - Verify XAUEUR = XAUUSD / EURUSD (within 0.01%)
   - Test with known historical data

2. **CSM Normalization:**
   - Verify min currency = 0, max = 100
   - Confirm sum doesn't need to equal fixed value (competitive system)

3. **Market State Detection:**
   - Test during known events:
     - March 2020 COVID crash (Gold + JPY should spike)
     - November 2021 risk-on (AUD strong, Gold weak)
     - Current period (verify matches market sentiment)

### Integration Tests
1. **Signal Generation:**
   - XAUUSD should generate TrendRider signals
   - No RangeRider signals for Gold
   - CSM confirmation should use Gold strength appropriately

2. **Trade Execution:**
   - Test XAUUSD trade execution on demo
   - Verify spread checks work for Gold (different pip size)
   - Confirm position sizing accounts for Gold contract size

---

## Risk Considerations

### 1. Gold Volatility
- Gold moves differently than currency pairs
- ATR for XAUUSD is typically 1.5-3.0x higher than EURUSD
- **Mitigation:** Dynamic SL/TP based on ATR (critical fix from Session 6)

### 2. Synthetic Pair Accuracy
- Synthetic pairs are calculated, not real market prices
- Small rounding errors acceptable
- **Mitigation:** Use high precision (DoubleToString(..., 5))

### 3. Gold Contract Size
- 1 lot Gold = different value than 1 lot EURUSD
- **Mitigation:** Position sizing must account for contract specifications

### 4. Conflicting Signals
- Gold strong + AUD strong = Mixed market state
- **Mitigation:** Require higher confidence threshold (e.g., 85 instead of 70)

---

**Design Status:** ✅ Complete
**Next Step:** Implement CSM_AnalysisEA.mq5
**Review Date:** After initial testing on demo
