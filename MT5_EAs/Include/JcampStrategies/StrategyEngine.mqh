//+------------------------------------------------------------------+
//|                                           StrategyEngine.mqh     |
//|                                            JcampForexTrader      |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "1.00"
#property strict
#property description "Strategy Engine - Reusable strategy evaluation module"
#property description "Extracts core evaluation logic for use in both live and backtest EAs"

//+------------------------------------------------------------------+
//| INCLUDE DEPENDENCIES                                              |
//+------------------------------------------------------------------+
#include <JcampStrategies/Indicators/EmaCalculator.mqh>
#include <JcampStrategies/Indicators/AtrCalculator.mqh>
#include <JcampStrategies/Indicators/AdxCalculator.mqh>
#include <JcampStrategies/Indicators/RsiCalculator.mqh>
#include <JcampStrategies/RegimeDetector.mqh>
#include <JcampStrategies/Strategies/IStrategy.mqh>
#include <JcampStrategies/Strategies/TrendRiderStrategy.mqh>
#include <JcampStrategies/Strategies/GoldTrendRiderStrategy.mqh>
#include <JcampStrategies/Strategies/RangeRiderStrategy.mqh>

//+------------------------------------------------------------------+
//| CSM DATA STRUCTURES                                               |
//+------------------------------------------------------------------+
struct CurrencyStrengthData
{
    string   currency;
    double   current_strength;
    double   strength_24h_ago;
    double   strength_change_24h;
    bool     data_valid;
    datetime last_update;
};

//+------------------------------------------------------------------+
//| STRATEGY ENGINE CONFIGURATION                                     |
//+------------------------------------------------------------------+
struct StrategyEngineConfig
{
    // CSM Gatekeeper
    double   minCSMDifferential;

    // Regime Detection
    int      trendingThresholdPercent;
    int      rangingThresholdPercent;
    double   minADXForTrending;

    // Strategy Enables
    bool     enableTrendRider;
    bool     enableRangeRider;
    int      minConfidenceScore;

    // ATR-Based SL/TP
    int      atrPeriod;

    // Symbol-Specific ATR Multipliers
    double   eurusd_ATRMultiplier;
    double   gbpusd_ATRMultiplier;
    double   audjpy_ATRMultiplier;
    double   usdjpy_ATRMultiplier;
    double   usdchf_ATRMultiplier;
    double   xauusd_ATRMultiplier;

    // Symbol-Specific Min SL
    double   eurusd_MinSL;
    double   gbpusd_MinSL;
    double   audjpy_MinSL;
    double   usdjpy_MinSL;
    double   usdchf_MinSL;
    double   xauusd_MinSL;

    // Symbol-Specific Max SL
    double   eurusd_MaxSL;
    double   gbpusd_MaxSL;
    double   audjpy_MaxSL;
    double   usdjpy_MaxSL;
    double   usdchf_MaxSL;
    double   xauusd_MaxSL;

    // Gold-Specific
    ENUM_TIMEFRAMES xauusd_ATRTimeframe;

    // Logging
    bool     verboseLogging;
};

//+------------------------------------------------------------------+
//| STRATEGY ENGINE CLASS                                             |
//+------------------------------------------------------------------+
class StrategyEngine
{
private:
    // Configuration
    StrategyEngineConfig config;

    // Strategies (owned by this class)
    IStrategy* trendRider;
    RangeRiderStrategy* rangeRider;

    // CSM Data (internal copy)
    CurrencyStrengthData csmData[9];
    int csmDataSize;

    // Currency list (reference)
    string currencies[9];

public:
    //+------------------------------------------------------------------+
    //| Constructor                                                       |
    //+------------------------------------------------------------------+
    StrategyEngine(StrategyEngineConfig &cfg, CurrencyStrengthData &csm[], int csmSize)
    {
        // Copy configuration
        config = cfg;

        // Copy CSM data internally
        csmDataSize = csmSize;
        for(int i = 0; i < csmSize && i < 9; i++)
        {
            csmData[i] = csm[i];
        }

        // Initialize currency list
        currencies[0] = "USD"; currencies[1] = "EUR"; currencies[2] = "GBP";
        currencies[3] = "JPY"; currencies[4] = "CHF"; currencies[5] = "AUD";
        currencies[6] = "CAD"; currencies[7] = "NZD"; currencies[8] = "XAU";

        // Initialize strategies as NULL (will be created per-symbol in EvaluateSymbol)
        trendRider = NULL;
        rangeRider = NULL;

        if(config.verboseLogging)
            Print("✓ StrategyEngine initialized");
    }

    //+------------------------------------------------------------------+
    //| Destructor                                                        |
    //+------------------------------------------------------------------+
    ~StrategyEngine()
    {
        // Cleanup strategies
        if(trendRider != NULL) delete trendRider;
        if(rangeRider != NULL) delete rangeRider;
    }

    //+------------------------------------------------------------------+
    //| Update CSM Data (call when CSM is refreshed)                     |
    //+------------------------------------------------------------------+
    void UpdateCSM(CurrencyStrengthData &csm[], int csmSize)
    {
        csmDataSize = csmSize;
        for(int i = 0; i < csmSize && i < 9; i++)
        {
            csmData[i] = csm[i];
        }
    }

    //+------------------------------------------------------------------+
    //| Initialize Strategies for Symbol                                 |
    //+------------------------------------------------------------------+
    void InitializeStrategiesForSymbol(string symbol)
    {
        // Clean up existing strategies
        if(trendRider != NULL) delete trendRider;
        if(rangeRider != NULL) delete rangeRider;

        // Create appropriate TrendRider based on symbol
        if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
        {
            trendRider = new GoldTrendRiderStrategy(config.minConfidenceScore,
                                                     config.minCSMDifferential,
                                                     config.verboseLogging);
            if(config.verboseLogging)
                Print("✓ Using GOLD_TREND_RIDER for ", symbol);
        }
        else
        {
            trendRider = new TrendRiderStrategy(config.minConfidenceScore,
                                                config.minCSMDifferential,
                                                config.verboseLogging);
        }

        // Create RangeRider
        rangeRider = new RangeRiderStrategy(config.minConfidenceScore, config.verboseLogging);

        if(config.verboseLogging)
            Print("✓ Strategies initialized for ", symbol);
    }

    //+------------------------------------------------------------------+
    //| Main Evaluation Method                                           |
    //+------------------------------------------------------------------+
    bool EvaluateSymbol(string symbol,
                        ENUM_TIMEFRAMES timeframe,
                        StrategySignal &signal,
                        MARKET_REGIME &regime,
                        string &failureReason)
    {
        //═══════════════════════════════════════════════════════════════
        // STEP 1: CSM GATEKEEPER CHECK
        //═══════════════════════════════════════════════════════════════
        double csmDiff = GetCSMDifferential(symbol);

        if(config.verboseLogging)
            Print("CSM Differential for ", symbol, ": ", DoubleToString(csmDiff, 2));

        if(csmDiff < config.minCSMDifferential)
        {
            failureReason = "NOT_TRADABLE - CSM diff too low";
            if(config.verboseLogging)
                Print("✗ NOT TRADABLE - CSM Diff: ", DoubleToString(csmDiff, 2),
                      " < ", config.minCSMDifferential, " (CSM gate failed)");
            return false;
        }

        if(config.verboseLogging)
            Print("✓ CSM GATE PASSED - Diff: ", DoubleToString(csmDiff, 2),
                  " >= ", config.minCSMDifferential);

        //═══════════════════════════════════════════════════════════════
        // STEP 2: REGIME DETECTION
        //═══════════════════════════════════════════════════════════════
        regime = DetectMarketRegime(symbol,
                                    config.trendingThresholdPercent,
                                    config.rangingThresholdPercent,
                                    config.minADXForTrending,
                                    config.verboseLogging);

        if(config.verboseLogging)
            Print("Regime for ", symbol, ": ", EnumToString(regime));

        //═══════════════════════════════════════════════════════════════
        // STEP 3: STRATEGY SELECTION
        //═══════════════════════════════════════════════════════════════
        IStrategy* activeStrategy = NULL;
        bool isGold = (StringFind(symbol, "XAU") >= 0);

        if(regime == REGIME_TRENDING && config.enableTrendRider)
        {
            activeStrategy = trendRider;
        }
        else if(regime == REGIME_RANGING && config.enableRangeRider && !isGold)
        {
            activeStrategy = rangeRider;
        }
        else
        {
            // No applicable strategy
            if(regime == REGIME_TRANSITIONAL)
                failureReason = "NOT_TRADABLE - TRANSITIONAL regime";
            else if(isGold && regime == REGIME_RANGING)
                failureReason = "NOT_TRADABLE - Gold in RANGING market";
            else
                failureReason = "NOT_TRADABLE - No applicable strategy";

            if(config.verboseLogging)
                Print("✗ NOT TRADABLE - ", failureReason);

            return false;
        }

        //═══════════════════════════════════════════════════════════════
        // STEP 4: STRATEGY EXECUTION
        //═══════════════════════════════════════════════════════════════
        bool hasSignal = activeStrategy.Analyze(symbol, timeframe, csmDiff, signal);

        if(!hasSignal)
        {
            failureReason = "No valid signal - strategy conditions not met";
            if(config.verboseLogging)
                Print("✗ No signal from ", signal.strategyName);
            return false;
        }

        if(config.verboseLogging)
        {
            Print("Strategy: ", signal.strategyName);
            Print("Signal: ", signal.signal == 1 ? "BUY" : (signal.signal == -1 ? "SELL" : "NEUTRAL"));
            Print("Confidence: ", signal.confidence);
        }

        //═══════════════════════════════════════════════════════════════
        // STEP 5: ATR-BASED DYNAMIC SL/TP CALCULATION
        //═══════════════════════════════════════════════════════════════
        CalculateATRBasedStops(symbol, timeframe, signal);

        return true;
    }

    //+------------------------------------------------------------------+
    //| Calculate ATR-Based SL/TP (Sessions 15-17)                      |
    //+------------------------------------------------------------------+
    void CalculateATRBasedStops(string symbol, ENUM_TIMEFRAMES timeframe, StrategySignal &signal)
    {
        bool isGold = (StringFind(symbol, "XAU") >= 0);

        // Use H4 ATR for Gold, specified timeframe for forex
        ENUM_TIMEFRAMES atrTimeframe = isGold ? config.xauusd_ATRTimeframe : timeframe;

        // Get ATR
        double atr = GetATR(symbol, atrTimeframe, config.atrPeriod);

        if(atr <= 0)
        {
            // Invalid ATR - set to zero (TradeExecutor will use defaults)
            signal.stopLossDollars = 0.0;
            signal.takeProfitDollars = 0.0;

            if(config.verboseLogging)
                Print("⚠ ATR data invalid, using default SL/TP");
            return;
        }

        // Get symbol-specific parameters
        double atrMultiplier = GetSymbolATRMultiplier(symbol);
        double minSL = GetSymbolMinSL(symbol);
        double maxSL = GetSymbolMaxSL(symbol);

        // Calculate pip size
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        double pipSize = (digits == 3 || digits == 5) ? point * 10.0 : point;

        // Convert ATR to pips (for Gold, ATR is already in dollars)
        double atrPips = isGold ? atr : (atr / pipSize);

        // Calculate SL distance
        double slPips = atrPips * atrMultiplier;

        // Apply bounds
        if(slPips < minSL) slPips = minSL;
        if(slPips > maxSL) slPips = maxSL;

        // Convert to price distance
        double slDistance = isGold ? slPips : (slPips * pipSize);

        //═══════════════════════════════════════════════════════════════
        // SESSION 17: CONFIDENCE-BASED R:R SCALING
        //═══════════════════════════════════════════════════════════════
        double rrRatio;

        if(signal.confidence >= 90)
        {
            rrRatio = 3.0;
            if(config.verboseLogging)
                Print("🔥 High conf (", signal.confidence, ") → 1:3 R:R");
        }
        else if(signal.confidence >= 80)
        {
            rrRatio = 2.5;
            if(config.verboseLogging)
                Print("⚡ Good conf (", signal.confidence, ") → 1:2.5 R:R");
        }
        else
        {
            rrRatio = 2.0;
            if(config.verboseLogging)
                Print("✓ Standard conf (", signal.confidence, ") → 1:2 R:R");
        }

        // Apply Gold R:R cap
        if(isGold && rrRatio > 2.5)
        {
            rrRatio = 2.5;
            if(config.verboseLogging)
                Print("⚠️ Gold R:R capped at 1:2.5");
        }

        // Calculate TP distance
        double tpDistance = slDistance * rrRatio;

        // Store in signal
        signal.stopLossDollars = slDistance;
        signal.takeProfitDollars = tpDistance;

        if(config.verboseLogging)
        {
            Print("═══ ATR-Based SL/TP ═══");
            Print("Symbol: ", symbol);
            Print("ATR: ", DoubleToString(atrPips, 1), (isGold ? " $" : " pips"));
            Print("SL: ", DoubleToString(slPips, 1), (isGold ? " $" : " pips"));
            Print("TP: ", DoubleToString(tpDistance / (isGold ? 1.0 : pipSize), 1),
                  (isGold ? " $" : " pips"), " (R:R ", rrRatio, ":1)");
        }
    }

    //+------------------------------------------------------------------+
    //| Get CSM Differential                                             |
    //+------------------------------------------------------------------+
    double GetCSMDifferential(string symbol)
    {
        string base_currency = StringSubstr(symbol, 0, 3);
        string quote_currency = StringSubstr(symbol, 3, 3);

        int base_idx = GetCurrencyIndex(base_currency);
        int quote_idx = GetCurrencyIndex(quote_currency);

        if(base_idx < 0 || quote_idx < 0)
        {
            if(config.verboseLogging)
                Print("⚠ Cannot calculate CSM differential for ", symbol);
            return 0.0;
        }

        if(!csmData[base_idx].data_valid || !csmData[quote_idx].data_valid)
        {
            if(config.verboseLogging)
                Print("⚠ CSM data not valid for ", symbol);
            return 0.0;
        }

        return csmData[base_idx].current_strength - csmData[quote_idx].current_strength;
    }

private:
    //+------------------------------------------------------------------+
    //| Get Currency Index                                               |
    //+------------------------------------------------------------------+
    int GetCurrencyIndex(string currency)
    {
        for(int i = 0; i < 9; i++)
        {
            if(currencies[i] == currency)
                return i;
        }
        return -1;
    }

    //+------------------------------------------------------------------+
    //| Get Symbol-Specific ATR Multiplier                              |
    //+------------------------------------------------------------------+
    double GetSymbolATRMultiplier(string symbol)
    {
        string clean = symbol;
        StringReplace(clean, ".sml", "");
        StringReplace(clean, ".r", "");
        StringReplace(clean, ".ecn", "");
        StringReplace(clean, ".raw", "");

        if(StringFind(clean, "EURUSD") >= 0) return config.eurusd_ATRMultiplier;
        if(StringFind(clean, "GBPUSD") >= 0) return config.gbpusd_ATRMultiplier;
        if(StringFind(clean, "AUDJPY") >= 0) return config.audjpy_ATRMultiplier;
        if(StringFind(clean, "USDJPY") >= 0) return config.usdjpy_ATRMultiplier;
        if(StringFind(clean, "USDCHF") >= 0) return config.usdchf_ATRMultiplier;
        if(StringFind(clean, "XAUUSD") >= 0 || StringFind(clean, "GOLD") >= 0)
            return config.xauusd_ATRMultiplier;

        return 0.5; // Default
    }

    //+------------------------------------------------------------------+
    //| Get Symbol-Specific Min SL                                      |
    //+------------------------------------------------------------------+
    double GetSymbolMinSL(string symbol)
    {
        string clean = symbol;
        StringReplace(clean, ".sml", "");
        StringReplace(clean, ".r", "");
        StringReplace(clean, ".ecn", "");
        StringReplace(clean, ".raw", "");

        if(StringFind(clean, "EURUSD") >= 0) return config.eurusd_MinSL;
        if(StringFind(clean, "GBPUSD") >= 0) return config.gbpusd_MinSL;
        if(StringFind(clean, "AUDJPY") >= 0) return config.audjpy_MinSL;
        if(StringFind(clean, "USDJPY") >= 0) return config.usdjpy_MinSL;
        if(StringFind(clean, "USDCHF") >= 0) return config.usdchf_MinSL;
        if(StringFind(clean, "XAUUSD") >= 0 || StringFind(clean, "GOLD") >= 0)
            return config.xauusd_MinSL;

        return 20.0; // Default
    }

    //+------------------------------------------------------------------+
    //| Get Symbol-Specific Max SL                                      |
    //+------------------------------------------------------------------+
    double GetSymbolMaxSL(string symbol)
    {
        string clean = symbol;
        StringReplace(clean, ".sml", "");
        StringReplace(clean, ".r", "");
        StringReplace(clean, ".ecn", "");
        StringReplace(clean, ".raw", "");

        if(StringFind(clean, "EURUSD") >= 0) return config.eurusd_MaxSL;
        if(StringFind(clean, "GBPUSD") >= 0) return config.gbpusd_MaxSL;
        if(StringFind(clean, "AUDJPY") >= 0) return config.audjpy_MaxSL;
        if(StringFind(clean, "USDJPY") >= 0) return config.usdjpy_MaxSL;
        if(StringFind(clean, "USDCHF") >= 0) return config.usdchf_MaxSL;
        if(StringFind(clean, "XAUUSD") >= 0 || StringFind(clean, "GOLD") >= 0)
            return config.xauusd_MaxSL;

        return 100.0; // Default
    }
};
