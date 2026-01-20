//+------------------------------------------------------------------+
//|                                   Jcamp_Strategy_AnalysisEA.mq5  |
//|                                            JcampForexTrader      |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "1.00"
#property strict
#property description "Modular Strategy Analysis EA - Exports signals for MainTradingEA"
#property description "Uses BacktestEA's exact CSM calculation logic"

//+------------------------------------------------------------------+
//| INCLUDE MODULAR COMPONENTS                                        |
//+------------------------------------------------------------------+
#include <JcampStrategies/Indicators/EmaCalculator.mqh>
#include <JcampStrategies/Indicators/AtrCalculator.mqh>
#include <JcampStrategies/Indicators/AdxCalculator.mqh>
#include <JcampStrategies/Indicators/RsiCalculator.mqh>
#include <JcampStrategies/RegimeDetector.mqh>
#include <JcampStrategies/Strategies/TrendRiderStrategy.mqh>
#include <JcampStrategies/Strategies/RangeRiderStrategy.mqh>
#include <JcampStrategies/SignalExporter.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
//═══════════════════════════════════════════════════════════════════
//  TIMEFRAME & EXECUTION SETTINGS
//═══════════════════════════════════════════════════════════════════
input group "═══ TIMEFRAME & EXECUTION ═══"
input ENUM_TIMEFRAMES AnalysisTimeframe = PERIOD_H1;      // Analysis timeframe (indicators)
input int AnalysisIntervalMinutes = 15;                   // Signal export interval (minutes)
input int RegimeCheckHours = 4;                           // Regime detection check interval (hours)

//═══════════════════════════════════════════════════════════════════
//  CURRENCY STRENGTH METER (CSM)
//═══════════════════════════════════════════════════════════════════
input group "═══ CURRENCY STRENGTH METER ═══"
input int CSM_LookbackHours = 48;                         // Lookback period (hours)

//═══════════════════════════════════════════════════════════════════
//  REGIME DETECTION TUNING
//═══════════════════════════════════════════════════════════════════
input group "═══ REGIME DETECTION TUNING ═══"
input int TrendingThresholdPercent = 55;                  // Trending classification threshold (%)
input int RangingThresholdPercent = 40;                   // Ranging classification threshold (%)
input double MinADXForTrending = 30.0;                    // Min ADX for strong trend
input double MinEMASeparation = 0.40;                     // Min EMA separation (%)

//═══════════════════════════════════════════════════════════════════
//  DYNAMIC REGIME DETECTION (Phase 4E)
//═══════════════════════════════════════════════════════════════════
input group "═══ DYNAMIC REGIME DETECTION (Phase 4E) ═══"
input bool UseDynamicRegimeDetection = true;              // Enable dynamic regime re-evaluation
input int DynamicRegimeMinIntervalMinutes = 60;           // Min minutes between dynamic checks
input double DynamicRegimeADXThreshold = 35.0;            // ADX threshold for dynamic recheck

//═══════════════════════════════════════════════════════════════════
//  TREND RIDER STRATEGY
//═══════════════════════════════════════════════════════════════════
input group "═══ TREND RIDER STRATEGY ═══"
input bool EnableTrendRider = true;                       // Enable Trend Rider
input double MinConfidenceScore = 65.0;                   // Min confidence (%)
input double MinCSMDifferential = 15.0;                   // Min CSM differential

//═══════════════════════════════════════════════════════════════════
//  RANGE RIDER STRATEGY
//═══════════════════════════════════════════════════════════════════
input group "═══ RANGE RIDER SETTINGS ═══"
input bool EnableRangeRider = true;                       // Enable Range Rider strategy
input int RangeDetectionBars = 100;                       // Bars to analyze for range
input int MinBoundaryTouches = 3;                         // Min touches per boundary
input double MinRangeWidthPips = 30.0;                    // Min range width (pips)
input double MaxRangeWidthPips = 100.0;                   // Max range width (pips)
input int RangeRiderMinConfidence = 65;                   // Min confidence for entry (%)

//═══════════════════════════════════════════════════════════════════
//  LOGGING & DIAGNOSTICS
//═══════════════════════════════════════════════════════════════════
input group "═══ LOGGING & DIAGNOSTICS ═══"
input bool VerboseLogging = true;                         // Enable detailed logging
input bool EnableCSMDiagnostics = false;                  // Enable CSM diagnostic reports

// Broker suffix for symbol names
input string BrokerSuffix = "";                           // Broker symbol suffix (e.g., ".sml")

//+------------------------------------------------------------------+
//| CSM DATA STRUCTURES (from BacktestEA)                            |
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

struct PairData
{
    string symbol;
    double current_price;
    double price_24h_ago;
    double price_48h_ago;
    double price_change_24h;
    double price_change_48h;
    bool   symbol_available;
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
// Strategies
TrendRiderStrategy* trendRider;
RangeRiderStrategy* rangeRider;

// Signal exporter
SignalExporter* signalExporter;

// CSM data (from BacktestEA)
string currencies[8] = {"USD", "EUR", "GBP", "JPY", "CHF", "AUD", "CAD", "NZD"};
CurrencyStrengthData csm_data[8];

string major_pairs[16] = {
    "EURUSD", "GBPUSD", "USDJPY", "USDCHF",
    "USDCAD", "AUDUSD", "NZDUSD", "EURGBP",
    "GBPNZD", "AUDNZD", "NZDCAD", "NZDJPY",
    "GBPJPY", "GBPCHF", "GBPCAD", "EURJPY"
};
PairData pair_data[16];

// Timing variables
datetime lastAnalysisTime = 0;
datetime lastRegimeCheck = 0;
datetime lastDynamicCheck = 0;     // Dynamic regime detection (Phase 4E)
datetime last_csm_update = 0;

int analysisInterval;        // Will be set from input (minutes → seconds)
int regimeCheckInterval;     // Will be set from input (hours → seconds)
int csm_update_interval = 3600;  // Update CSM hourly (matches BacktestEA)

// Current regime
MARKET_REGIME currentRegime = REGIME_TRANSITIONAL;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("\n╔════════════════════════════════════════════════════════════╗");
    Print("║       Jcamp Strategy Analysis EA - Initialization         ║");
    Print("╚════════════════════════════════════════════════════════════╝");

    //═══════════════════════════════════════════════════════════════
    // Initialize strategies
    //═══════════════════════════════════════════════════════════════
    trendRider = new TrendRiderStrategy(
        (int)MinConfidenceScore,
        MinCSMDifferential,
        VerboseLogging
    );

    rangeRider = new RangeRiderStrategy(
        RangeRiderMinConfidence,
        VerboseLogging
    );

    Print("✓ Strategies initialized");
    Print("  - TrendRider: ", EnableTrendRider ? "ENABLED" : "DISABLED");
    Print("  - RangeRider: ", EnableRangeRider ? "ENABLED" : "DISABLED");

    //═══════════════════════════════════════════════════════════════
    // Initialize signal exporter
    //═══════════════════════════════════════════════════════════════
    signalExporter = new SignalExporter("CSM_Signals", VerboseLogging);

    Print("✓ Signal exporter initialized");

    //═══════════════════════════════════════════════════════════════
    // Initialize CSM system (BacktestEA's exact logic)
    //═══════════════════════════════════════════════════════════════
    Print("\n═══ Initializing Full CSM (16 pairs, 8 currencies) ═══");

    for(int i = 0; i < 8; i++)
    {
        csm_data[i].currency = currencies[i];
        csm_data[i].current_strength = 0.0;
        csm_data[i].strength_24h_ago = 0.0;
        csm_data[i].strength_change_24h = 0.0;
        csm_data[i].data_valid = false;
        csm_data[i].last_update = 0;
    }

    if(!InitializePairData())
    {
        Print("⚠ Warning: Some pairs unavailable");
    }

    UpdateFullCSM();     // Initial CSM calculation
    ExportCSMToFile();   // Export for C# monitoring

    Print("✓ Full CSM initialized successfully");

    //═══════════════════════════════════════════════════════════════
    // Set initial regime (call function directly)
    //═══════════════════════════════════════════════════════════════
    currentRegime = DetectMarketRegime(_Symbol,
                                       TrendingThresholdPercent,
                                       RangingThresholdPercent,
                                       MinADXForTrending,
                                       false);
    lastRegimeCheck = TimeCurrent();
    lastDynamicCheck = TimeCurrent();  // Initialize dynamic check timer (Phase 4E)

    Print("✓ Initial regime: ", EnumToString(currentRegime));

    //═══════════════════════════════════════════════════════════════
    // Set timing intervals
    //═══════════════════════════════════════════════════════════════
    analysisInterval = AnalysisIntervalMinutes * 60;  // Convert to seconds
    regimeCheckInterval = RegimeCheckHours * 3600;    // Convert to seconds

    Print("\n═══ Configuration ═══");
    Print("Analysis Interval: ", AnalysisIntervalMinutes, " minutes");
    Print("Regime Check: ", RegimeCheckHours, " hours");
    Print("Dynamic Regime: ", UseDynamicRegimeDetection ? "ENABLED" : "DISABLED");
    if(UseDynamicRegimeDetection)
    {
        Print("  - Min Interval: ", DynamicRegimeMinIntervalMinutes, " minutes");
        Print("  - ADX Threshold: ", DynamicRegimeADXThreshold);
    }
    Print("CSM Update: 1 hour");
    Print("Symbol: ", _Symbol);
    Print("Timeframe: ", EnumToString(AnalysisTimeframe));

    Print("\n╔════════════════════════════════════════════════════════════╗");
    Print("║          Strategy Analysis EA Ready                       ║");
    Print("╚════════════════════════════════════════════════════════════╝\n");

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Cleanup modules
    delete trendRider;
    delete rangeRider;
    delete signalExporter;

    Print("Strategy Analysis EA deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    datetime currentTime = TimeCurrent();

    //═══════════════════════════════════════════════════════════════
    // Update CSM hourly (runs independently)
    //═══════════════════════════════════════════════════════════════
    if(currentTime - last_csm_update >= csm_update_interval)
    {
        UpdateFullCSM();      // BacktestEA's exact logic
        ExportCSMToFile();    // For C# monitoring
        last_csm_update = currentTime;

        if(VerboseLogging)
            Print("CSM updated at ", TimeToString(currentTime, TIME_DATE|TIME_MINUTES));
    }

    //═══════════════════════════════════════════════════════════════
    // Update regime every 4 hours (runs independently)
    //═══════════════════════════════════════════════════════════════
    if(currentTime - lastRegimeCheck >= regimeCheckInterval)
    {
        MARKET_REGIME previousRegime = currentRegime;
        currentRegime = DetectMarketRegime(_Symbol,
                                           TrendingThresholdPercent,
                                           RangingThresholdPercent,
                                           MinADXForTrending,
                                           VerboseLogging);
        lastRegimeCheck = currentTime;

        if(VerboseLogging || previousRegime != currentRegime)
        {
            Print("Regime updated: ", EnumToString(currentRegime));
            if(previousRegime != currentRegime)
                Print("  → Regime change: ", EnumToString(previousRegime), " → ", EnumToString(currentRegime));
        }
    }

    //═══════════════════════════════════════════════════════════════
    // PHASE 4E: DYNAMIC REGIME RE-EVALUATION (runs independently)
    // Re-check regime if strong trending signals detected
    //═══════════════════════════════════════════════════════════════

    if(UseDynamicRegimeDetection)
    {
        int minutesSinceLastCheck = (int)((currentTime - lastDynamicCheck) / 60);

        // Only recheck if minimum interval passed
        if(minutesSinceLastCheck >= DynamicRegimeMinIntervalMinutes)
        {
            if(VerboseLogging)
            {
                Print("⚡ Dynamic regime check running (", minutesSinceLastCheck, " min since last check)");
            }

            // Get ADX to check for strong trending
            double currentADX = GetADX(_Symbol, AnalysisTimeframe, 14);

            if(VerboseLogging)
            {
                Print("   Current ADX: ", DoubleToString(currentADX, 1),
                      " | Current Regime: ", EnumToString(currentRegime));
            }

            // Validate ADX data
            if(currentADX > 0)
            {
                // Strong trending signal detected?
                if(currentADX > DynamicRegimeADXThreshold)
                {
                    // Get EMA values for alignment check
                    double ema20 = GetEMA(_Symbol, AnalysisTimeframe, 20);
                    double ema50 = GetEMA(_Symbol, AnalysisTimeframe, 50);
                    double ema100 = GetEMA(_Symbol, AnalysisTimeframe, 100);

                    // Check for strong EMA alignment
                    bool uptrend = (ema20 > ema50 && ema50 > ema100);
                    bool downtrend = (ema20 < ema50 && ema50 < ema100);
                    bool strongTrendingSignals = (uptrend || downtrend);

                    // If strong trending detected but regime is not TRENDING, recheck!
                    if(strongTrendingSignals && currentRegime != REGIME_TRENDING)
                    {
                        if(VerboseLogging)
                        {
                            Print("\n⚡ DYNAMIC REGIME RECHECK TRIGGERED:");
                            Print("   ADX: ", DoubleToString(currentADX, 1), " > ", DynamicRegimeADXThreshold);
                            Print("   EMA Alignment: ", uptrend ? "Strong Uptrend" : "Strong Downtrend");
                            Print("   Current Regime: ", EnumToString(currentRegime), " → Forcing recheck!");
                        }

                        // Force regime re-evaluation (BYPASS TIME GATE)
                        MARKET_REGIME previousRegime = currentRegime;
                        currentRegime = DetectMarketRegime(_Symbol,
                                                           TrendingThresholdPercent,
                                                           RangingThresholdPercent,
                                                           MinADXForTrending,
                                                           VerboseLogging);
                        lastRegimeCheck = currentTime;  // Update scheduled check timer too

                        if(previousRegime != currentRegime)
                        {
                            Print("⚡ DYNAMIC REGIME CHANGE: ", EnumToString(previousRegime),
                                  " → ", EnumToString(currentRegime));
                        }
                    }
                    // If weak ADX but regime is TRENDING, might need recheck
                    else if(currentADX < 20 && currentRegime == REGIME_TRENDING)
                    {
                        if(VerboseLogging)
                        {
                            Print("\n⚡ DYNAMIC REGIME RECHECK (Weak ADX):");
                            Print("   ADX: ", DoubleToString(currentADX, 1), " (very weak)");
                            Print("   Current Regime: TRENDING → Might be ranging now");
                        }

                        // Force regime re-evaluation (BYPASS TIME GATE)
                        MARKET_REGIME previousRegime = currentRegime;
                        currentRegime = DetectMarketRegime(_Symbol,
                                                           TrendingThresholdPercent,
                                                           RangingThresholdPercent,
                                                           MinADXForTrending,
                                                           VerboseLogging);
                        lastRegimeCheck = currentTime;  // Update scheduled check timer too

                        if(previousRegime != currentRegime)
                        {
                            Print("⚡ DYNAMIC REGIME CHANGE: ", EnumToString(previousRegime),
                                  " → ", EnumToString(currentRegime));
                        }
                    }
                }
            }

            // ALWAYS update timer after check completes (prevents spam)
            lastDynamicCheck = currentTime;
        }
    }

    //═══════════════════════════════════════════════════════════════
    // ANALYSIS INTERVAL THROTTLE (only for strategy/signals below)
    //═══════════════════════════════════════════════════════════════
    if(currentTime - lastAnalysisTime < analysisInterval)
        return;  // Exit here - dynamic checks already ran above

    lastAnalysisTime = currentTime;

    //═══════════════════════════════════════════════════════════════
    // Get CSM differential
    //═══════════════════════════════════════════════════════════════
    double csmDiff = GetCSMDifferential(_Symbol);

    if(VerboseLogging)
        Print("CSM Differential for ", _Symbol, ": ", DoubleToString(csmDiff, 2));

    //═══════════════════════════════════════════════════════════════
    // Select strategy based on regime
    //═══════════════════════════════════════════════════════════════
    IStrategy* activeStrategy = NULL;

    if(currentRegime == REGIME_TRENDING && EnableTrendRider)
        activeStrategy = trendRider;
    else if(currentRegime == REGIME_RANGING && EnableRangeRider)
        activeStrategy = rangeRider;
    else
        activeStrategy = NULL;  // TRANSITIONAL - no strategy

    //═══════════════════════════════════════════════════════════════
    // Generate signal
    //═══════════════════════════════════════════════════════════════
    StrategySignal signal;
    bool hasSignal = false;

    if(activeStrategy != NULL)
    {
        hasSignal = activeStrategy.Analyze(_Symbol, AnalysisTimeframe, csmDiff, signal);

        if(VerboseLogging)
        {
            Print("Strategy: ", signal.strategyName);
            Print("Signal: ", signal.signal == 1 ? "BUY" : (signal.signal == -1 ? "SELL" : "NEUTRAL"));
            Print("Confidence: ", signal.confidence);
        }
    }
    else
    {
        if(VerboseLogging)
            Print("No active strategy (Regime: ", EnumToString(currentRegime), ")");
    }

    //═══════════════════════════════════════════════════════════════
    // Export signal to JSON file
    //═══════════════════════════════════════════════════════════════
    if(hasSignal && activeStrategy.IsValidSignal(signal))
    {
        signalExporter.ExportSignalFromStrategy(_Symbol, signal, csmDiff,
                                                 EnumToString(currentRegime));

        if(VerboseLogging)
            Print("✓ Valid signal exported");
    }
    else
    {
        // No valid signal - clear signal file
        signalExporter.ClearSignal(_Symbol);

        if(VerboseLogging)
            Print("✗ No valid signal - signal file cleared");
    }
}

//+------------------------------------------------------------------+
//| Initialize Pair Data (from BacktestEA)                           |
//+------------------------------------------------------------------+
bool InitializePairData()
{
    bool all_available = true;

    for(int i = 0; i < 16; i++)
    {
        string symbol = major_pairs[i] + BrokerSuffix;
        pair_data[i].symbol = symbol;
        pair_data[i].symbol_available = SymbolExists(symbol);

        if(!pair_data[i].symbol_available)
        {
            symbol = major_pairs[i];
            pair_data[i].symbol = symbol;
            pair_data[i].symbol_available = SymbolExists(symbol);
        }

        if(pair_data[i].symbol_available)
        {
            pair_data[i].current_price = 0.0;
            pair_data[i].price_24h_ago = 0.0;
            pair_data[i].price_48h_ago = 0.0;
            pair_data[i].price_change_24h = 0.0;
            pair_data[i].price_change_48h = 0.0;

            if(VerboseLogging)
                Print("✓ ", symbol, " available");
        }
        else
        {
            if(VerboseLogging)
                Print("✗ ", major_pairs[i], " NOT available");
            all_available = false;
        }
    }

    return all_available;
}

//+------------------------------------------------------------------+
//| Update Full CSM (from BacktestEA - EXACT COPY)                   |
//+------------------------------------------------------------------+
void UpdateFullCSM()
{
    for(int i = 0; i < 8; i++)
    {
        csm_data[i].current_strength = 50.0;
        csm_data[i].strength_change_24h = 0.0;
        csm_data[i].data_valid = false;
    }

    double hoursPerBar = (double)PeriodSeconds(AnalysisTimeframe) / 3600.0;
    int bars_48h = (int)MathCeil((double)CSM_LookbackHours / hoursPerBar);
    int bars_24h = bars_48h / 2;

    for(int i = 0; i < 16; i++)
    {
        if(!pair_data[i].symbol_available)
            continue;

        double close[];
        ArraySetAsSeries(close, true);

        int copied = CopyClose(pair_data[i].symbol, AnalysisTimeframe, 0, bars_48h + 1, close);

        if(copied > bars_48h)
        {
            pair_data[i].current_price = close[0];
            pair_data[i].price_24h_ago = close[bars_24h];
            pair_data[i].price_48h_ago = close[bars_48h];

            if(pair_data[i].price_24h_ago > 0)
            {
                pair_data[i].price_change_24h =
                    (pair_data[i].current_price - pair_data[i].price_24h_ago) /
                    pair_data[i].price_24h_ago;
            }

            if(pair_data[i].price_48h_ago > 0)
            {
                pair_data[i].price_change_48h =
                    (pair_data[i].current_price - pair_data[i].price_48h_ago) /
                    pair_data[i].price_48h_ago;
            }
        }
    }

    // Calculate currency strengths from pair movements
    for(int i = 0; i < 16; i++)
    {
        if(!pair_data[i].symbol_available)
            continue;

        double price_change = pair_data[i].price_change_24h;

        if(price_change == 0.0 && pair_data[i].price_24h_ago == 0.0)
            continue;

        // Weight certain pairs more heavily (matches BacktestEA)
        double weight = 1.0;
        if(major_pairs[i] == "GBPNZD" || major_pairs[i] == "EURUSD" || major_pairs[i] == "GBPUSD")
            weight = 1.5;

        string base_currency = StringSubstr(major_pairs[i], 0, 3);
        string quote_currency = StringSubstr(major_pairs[i], 3, 3);

        int base_idx = GetCurrencyIndex(base_currency);
        int quote_idx = GetCurrencyIndex(quote_currency);

        if(base_idx >= 0 && quote_idx >= 0)
        {
            // ✅ MULTIPLY BY 100 TO MAKE VALUES LARGER FOR NORMALIZATION (BacktestEA)
            double strength_change = price_change * 100.0 * 2.0 * weight;

            csm_data[base_idx].current_strength += strength_change;
            csm_data[base_idx].strength_change_24h += strength_change;

            csm_data[quote_idx].current_strength -= strength_change;
            csm_data[quote_idx].strength_change_24h -= strength_change;
        }
    }

    NormalizeStrengthValues();

    datetime currentTime = TimeCurrent();
    for(int i = 0; i < 8; i++)
    {
        csm_data[i].data_valid = true;
        csm_data[i].last_update = currentTime;
    }
}

//+------------------------------------------------------------------+
//| Normalize Strength Values (from BacktestEA - EXACT COPY)         |
//+------------------------------------------------------------------+
void NormalizeStrengthValues()
{
    double min_strength = csm_data[0].current_strength;
    double max_strength = csm_data[0].current_strength;

    for(int i = 1; i < 8; i++)
    {
        if(csm_data[i].current_strength < min_strength)
            min_strength = csm_data[i].current_strength;
        if(csm_data[i].current_strength > max_strength)
            max_strength = csm_data[i].current_strength;
    }

    double range = max_strength - min_strength;
    if(range > 0.001)  // ✅ MUCH LOWER THRESHOLD (BacktestEA)
    {
        for(int i = 0; i < 8; i++)
        {
            csm_data[i].current_strength =
                ((csm_data[i].current_strength - min_strength) / range) * 100.0;

            if(range > 0)
            {
                csm_data[i].strength_change_24h =
                    (csm_data[i].strength_change_24h / range) * 100.0;
            }
        }
    }
    else
    {
        // ✅ IF NO RANGE, SET ALL TO 50 (NEUTRAL) (BacktestEA)
        for(int i = 0; i < 8; i++)
        {
            csm_data[i].current_strength = 50.0;
        }
    }
}

//+------------------------------------------------------------------+
//| Get Currency Strength (from BacktestEA - EXACT COPY)             |
//+------------------------------------------------------------------+
double GetCurrencyStrength(string currency)
{
    for(int i = 0; i < 8; i++)
    {
        if(csm_data[i].currency == currency && csm_data[i].data_valid)
        {
            return csm_data[i].current_strength;
        }
    }

    return 50.0;
}

//+------------------------------------------------------------------+
//| Get CSM Differential (from BacktestEA - EXACT COPY)              |
//+------------------------------------------------------------------+
double GetCSMDifferential(string symbol)
{
    string pairName = symbol;
    StringReplace(pairName, BrokerSuffix, "");

    string baseCurrency = StringSubstr(pairName, 0, 3);
    string quoteCurrency = StringSubstr(pairName, 3, 3);

    double baseStrength = GetCurrencyStrength(baseCurrency);
    double quoteStrength = GetCurrencyStrength(quoteCurrency);

    return baseStrength - quoteStrength;
}

//+------------------------------------------------------------------+
//| Get Currency Index (from BacktestEA - EXACT COPY)                |
//+------------------------------------------------------------------+
int GetCurrencyIndex(string currency)
{
    for(int i = 0; i < 8; i++)
    {
        if(currencies[i] == currency)
            return i;
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Check if Symbol Exists (from BacktestEA)                         |
//+------------------------------------------------------------------+
bool SymbolExists(string symbol)
{
    return (SymbolInfoInteger(symbol, SYMBOL_SELECT) > 0);
}

//+------------------------------------------------------------------+
//| Export CSM to File (NEW - for C# monitoring)                     |
//+------------------------------------------------------------------+
void ExportCSMToFile()
{
    string filename = "CSM_Signals\\csm_current.txt";
    int handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI);
    if(handle == INVALID_HANDLE)
    {
        Print("ERROR: Cannot write CSM file: ", filename);
        Print("Error code: ", GetLastError());
        return;
    }

    // Export timestamp
    FileWriteString(handle, "# CSM Currency Strengths\n");
    FileWriteString(handle, "# Updated: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "\n");
    FileWriteString(handle, "# Format: CURRENCY,STRENGTH\n");

    // Export all 8 currencies
    for(int i = 0; i < 8; i++)
    {
        if(csm_data[i].data_valid)
        {
            FileWriteString(handle, csm_data[i].currency + "," +
                          DoubleToString(csm_data[i].current_strength, 2) + "\n");
        }
    }

    FileClose(handle);

    if(EnableCSMDiagnostics)
    {
        Print("\n═══ CSM Exported ═══");
        for(int i = 0; i < 8; i++)
        {
            if(csm_data[i].data_valid)
            {
                Print(csm_data[i].currency, ": ",
                      DoubleToString(csm_data[i].current_strength, 1));
            }
        }
        Print("════════════════════\n");
    }
}
//+------------------------------------------------------------------+
