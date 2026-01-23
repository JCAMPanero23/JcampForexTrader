//+------------------------------------------------------------------+
//|                                   Jcamp_Strategy_AnalysisEA.mq5  |
//|                                            JcampForexTrader      |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "2.00"
#property strict
#property description "Modular Strategy Analysis EA - Exports signals for MainTradingEA"
#property description "CSM Alpha: Reads CSM from CSM_AnalysisEA (9-currency system with Gold)"
#property description "Supports EURUSD, GBPUSD, AUDJPY, XAUUSD (TrendRider only for Gold)"

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
input string CSM_Folder = "CSM_Data";                     // CSM file folder (from CSM_AnalysisEA)
input int CSM_MaxAgeMinutes = 120;                        // Max CSM file age (minutes)

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

// ✅ CSM Alpha: 9 currencies (with Gold)
string currencies[9] = {"USD", "EUR", "GBP", "JPY", "CHF", "AUD", "CAD", "NZD", "XAU"};
CurrencyStrengthData csm_data[9];  // Loaded from csm_current.txt

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

    // ✅ CSM Alpha: Initialize 9 currencies
    for(int i = 0; i < 9; i++)
    {
        csm_data[i].currency = currencies[i];
        csm_data[i].current_strength = 50.0;  // Default neutral
        csm_data[i].strength_24h_ago = 50.0;
        csm_data[i].strength_change_24h = 0.0;
        csm_data[i].data_valid = false;
        csm_data[i].last_update = 0;
    }

    // ✅ Load CSM from file (generated by CSM_AnalysisEA)
    LoadCSMFromFile();

    if(csm_data[0].data_valid)
        Print("✓ CSM loaded successfully from file");
    else
        Print("⚠ Warning: CSM file not found or stale - using neutral strengths");

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
    // ✅ Load CSM from file (generated by CSM_AnalysisEA)
    // Check every tick, but LoadCSMFromFile() caches and only reloads if stale
    //═══════════════════════════════════════════════════════════════
    LoadCSMFromFile();

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
    // ✅ CSM Alpha: Gold (XAUUSD) uses TrendRider only
    //═══════════════════════════════════════════════════════════════
    IStrategy* activeStrategy = NULL;
    bool isGold = (StringFind(_Symbol, "XAU") >= 0);

    if(currentRegime == REGIME_TRENDING && EnableTrendRider)
    {
        activeStrategy = trendRider;
    }
    else if(currentRegime == REGIME_RANGING && EnableRangeRider && !isGold)
    {
        // ✅ Skip RangeRider for Gold - only use TrendRider
        activeStrategy = rangeRider;
    }
    else
    {
        activeStrategy = NULL;  // TRANSITIONAL or Gold in ranging market

        if(isGold && currentRegime == REGIME_RANGING && VerboseLogging)
            Print("⚠ Gold in RANGING market - no signal (TrendRider only for Gold)");
    }

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
//+------------------------------------------------------------------+
//| Load CSM from File (✅ CSM Alpha - reads from CSM_AnalysisEA)   |
//+------------------------------------------------------------------+
void LoadCSMFromFile()
{
    static datetime last_file_check = 0;
    datetime currentTime = TimeCurrent();
    
    // Only check file every 60 seconds (reduce I/O)
    if(currentTime - last_file_check < 60)
        return;
    
    last_file_check = currentTime;

    string filename = CSM_Folder + "\\csm_current.txt";
    int handle = FileOpen(filename, FILE_READ|FILE_TXT|FILE_ANSI);
    
    if(handle == INVALID_HANDLE)
    {
        if(VerboseLogging && csm_data[0].data_valid)  // Only warn once
        {
            Print("⚠ CSM file not found: ", filename);
            Print("  Make sure CSM_AnalysisEA is running!");
        }
        
        // Mark all CSM data as invalid
        for(int i = 0; i < 9; i++)
            csm_data[i].data_valid = false;
        
        return;
    }
    
    // Parse CSM file
    int currencies_loaded = 0;
    
    while(!FileIsEnding(handle))
    {
        string line = FileReadString(handle);
        
        // Skip comments and empty lines
        if(StringLen(line) == 0 || StringSubstr(line, 0, 1) == "#")
            continue;
        
        // Parse: CURRENCY,STRENGTH
        int comma_pos = StringFind(line, ",");
        if(comma_pos > 0)
        {
            string currency = StringSubstr(line, 0, comma_pos);
            string strength_str = StringSubstr(line, comma_pos + 1);
            double strength = StringToDouble(strength_str);
            
            // Find and update currency
            int idx = GetCurrencyIndex(currency);
            if(idx >= 0)
            {
                csm_data[idx].current_strength = strength;
                csm_data[idx].data_valid = true;
                csm_data[idx].last_update = currentTime;
                currencies_loaded++;
            }
        }
    }
    
    FileClose(handle);
    
    // Check if CSM file is stale
    if(currencies_loaded > 0)
    {
        // All good - CSM loaded successfully
        if(VerboseLogging)
            Print("✅ CSM loaded: ", currencies_loaded, " currencies");
    }
    else
    {
        Print("⚠ CSM file exists but no valid data found");
    }
}

//+------------------------------------------------------------------+
//| Get Currency Index                                                |
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
//| Get CSM Differential for Symbol                                  |
//+------------------------------------------------------------------+
double GetCSMDifferential(string symbol)
{
    // Extract base and quote currencies from symbol
    string base_currency = StringSubstr(symbol, 0, 3);
    string quote_currency = StringSubstr(symbol, 3, 3);

    int base_idx = GetCurrencyIndex(base_currency);
    int quote_idx = GetCurrencyIndex(quote_currency);

    if(base_idx < 0 || quote_idx < 0)
    {
        if(VerboseLogging)
            Print("⚠ Cannot calculate CSM differential for ", symbol, " - currency not found");
        return 0.0;
    }

    if(!csm_data[base_idx].data_valid || !csm_data[quote_idx].data_valid)
    {
        if(VerboseLogging)
            Print("⚠ CSM data not valid for ", symbol);
        return 0.0;
    }

    // CSM Differential = Base Strength - Quote Strength
    double diff = csm_data[base_idx].current_strength - csm_data[quote_idx].current_strength;

    return diff;
}

//+------------------------------------------------------------------+
