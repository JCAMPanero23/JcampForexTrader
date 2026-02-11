//+------------------------------------------------------------------+
//|                                   Jcamp_Strategy_AnalysisEA.mq5  |
//|                                            JcampForexTrader      |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "2.10"
#property strict
#property description "Modular Strategy Analysis EA - Exports signals for MainTradingEA"
#property description "CSM Alpha: Reads CSM from CSM_AnalysisEA (9-currency system with Gold)"
#property description "Supports EURUSD, GBPUSD, AUDJPY, XAUUSD (TrendRider only for Gold)"
#property description "Session 19: Refactored to use StrategyEngine.mqh"

//+------------------------------------------------------------------+
//| INCLUDE MODULAR COMPONENTS                                        |
//+------------------------------------------------------------------+
#include <JcampStrategies/StrategyEngine.mqh>
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
//  CSM GATEKEEPER (Primary Trading Filter)
//═══════════════════════════════════════════════════════════════════
input group "═══ CSM GATEKEEPER (PRIMARY FILTER) ═══"
input double MinCSMDifferential = 15.0;                   // Min CSM diff (blocks all trading if < threshold)
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

//═══════════════════════════════════════════════════════════════════
//  RANGE RIDER STRATEGY
//═══════════════════════════════════════════════════════════════════
input group "═══ RANGE RIDER SETTINGS ═══"
input bool EnableRangeRider = true;                       // Enable Range Rider strategy
input int RangeRiderMinConfidence = 65;                   // Min confidence for entry (%)

//═══════════════════════════════════════════════════════════════════
//  ATR-BASED DYNAMIC SL/TP (Session 15)
//═══════════════════════════════════════════════════════════════════
input group "═══ ATR-BASED SL/TP SETTINGS ═══"
input int      ATRPeriod = 14;                            // ATR period

input group "═══ EURUSD BOUNDS ═══"
input double   EURUSD_MinSL = 20.0;                       // Min SL (pips)
input double   EURUSD_MaxSL = 60.0;                       // Max SL (pips)
input double   EURUSD_ATRMultiplier = 0.5;                // ATR multiplier

input group "═══ GBPUSD BOUNDS ═══"
input double   GBPUSD_MinSL = 25.0;                       // Min SL (pips)
input double   GBPUSD_MaxSL = 80.0;                       // Max SL (pips)
input double   GBPUSD_ATRMultiplier = 0.6;                // ATR multiplier (wider for spikes)

input group "═══ AUDJPY BOUNDS ═══"
input double   AUDJPY_MinSL = 25.0;                       // Min SL (pips)
input double   AUDJPY_MaxSL = 70.0;                       // Max SL (pips)
input double   AUDJPY_ATRMultiplier = 0.5;                // ATR multiplier

input group "═══ USDJPY BOUNDS ═══"
input double   USDJPY_MinSL = 25.0;                       // Min SL (pips)
input double   USDJPY_MaxSL = 70.0;                       // Max SL (pips)
input double   USDJPY_ATRMultiplier = 0.5;                // ATR multiplier

input group "═══ USDCHF BOUNDS ═══"
input double   USDCHF_MinSL = 20.0;                       // Min SL (pips)
input double   USDCHF_MaxSL = 60.0;                       // Max SL (pips)
input double   USDCHF_ATRMultiplier = 0.5;                // ATR multiplier

// ⚠️ SESSION 19: XAUUSD (Gold) parameters kept for code compatibility (not trading Gold)
input group "═══ XAUUSD (GOLD) BOUNDS - NOT TRADING ═══"
input double   XAUUSD_MinSL = 50.0;                       // Min SL (pips/$) - raised from 30
input double   XAUUSD_MaxSL = 200.0;                      // Max SL (pips/$) - raised from 150
input double   XAUUSD_ATRMultiplier = 0.6;                // ATR multiplier - raised from 0.4
input ENUM_TIMEFRAMES XAUUSD_ATRTimeframe = PERIOD_H4;    // ATR timeframe for Gold (H4 more stable)

//═══════════════════════════════════════════════════════════════════
//  LOGGING & DIAGNOSTICS
//═══════════════════════════════════════════════════════════════════
input group "═══ LOGGING & DIAGNOSTICS ═══"
input bool VerboseLogging = true;                         // Enable detailed logging

input string BrokerSuffix = ".r";                         // Broker symbol suffix (e.g., ".r")

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
// Strategy Engine (new!)
StrategyEngine* engine;

// Signal exporter
SignalExporter* signalExporter;

// ✅ CSM Alpha: 9 currencies (with Gold)
string currencies[9] = {"USD", "EUR", "GBP", "JPY", "CHF", "AUD", "CAD", "NZD", "XAU"};
CurrencyStrengthData csm_data[9];  // Loaded from csm_current.txt

// Timing variables
datetime lastAnalysisTime = 0;
datetime lastRegimeCheck = 0;
datetime lastDynamicCheck = 0;     // Dynamic regime detection (Phase 4E)

int analysisInterval;        // Will be set from input (minutes → seconds)
int regimeCheckInterval;     // Will be set from input (hours → seconds)

// Current regime (maintained by this EA for dynamic detection)
MARKET_REGIME currentRegime = REGIME_TRANSITIONAL;
bool dynamicRegimeTriggeredThisCycle = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("\n╔════════════════════════════════════════════════════════════╗");
    Print("║       Jcamp Strategy Analysis EA - Initialization         ║");
    Print("║       Session 19: Using StrategyEngine.mqh                ║");
    Print("╚════════════════════════════════════════════════════════════╝");

    //═══════════════════════════════════════════════════════════════
    // Initialize CSM system
    //═══════════════════════════════════════════════════════════════
    for(int i = 0; i < 9; i++)
    {
        csm_data[i].currency = currencies[i];
        csm_data[i].current_strength = 50.0;  // Default neutral
        csm_data[i].strength_24h_ago = 50.0;
        csm_data[i].strength_change_24h = 0.0;
        csm_data[i].data_valid = false;
        csm_data[i].last_update = 0;
    }

    LoadCSMFromFile();

    if(csm_data[0].data_valid)
        Print("✓ CSM loaded successfully from file");
    else
        Print("⚠ Warning: CSM file not found or stale - using neutral strengths");

    //═══════════════════════════════════════════════════════════════
    // Create StrategyEngine configuration
    //═══════════════════════════════════════════════════════════════
    StrategyEngineConfig config;

    // CSM Gatekeeper
    config.minCSMDifferential = MinCSMDifferential;

    // Regime Detection
    config.trendingThresholdPercent = TrendingThresholdPercent;
    config.rangingThresholdPercent = RangingThresholdPercent;
    config.minADXForTrending = MinADXForTrending;

    // Strategy Enables
    config.enableTrendRider = EnableTrendRider;
    config.enableRangeRider = EnableRangeRider;
    config.minConfidenceScore = (int)MinConfidenceScore;

    // ATR-Based SL/TP
    config.atrPeriod = ATRPeriod;

    // Symbol-Specific ATR Multipliers
    config.eurusd_ATRMultiplier = EURUSD_ATRMultiplier;
    config.gbpusd_ATRMultiplier = GBPUSD_ATRMultiplier;
    config.audjpy_ATRMultiplier = AUDJPY_ATRMultiplier;
    config.usdjpy_ATRMultiplier = USDJPY_ATRMultiplier;
    config.usdchf_ATRMultiplier = USDCHF_ATRMultiplier;
    config.xauusd_ATRMultiplier = XAUUSD_ATRMultiplier;

    // Symbol-Specific Min SL
    config.eurusd_MinSL = EURUSD_MinSL;
    config.gbpusd_MinSL = GBPUSD_MinSL;
    config.audjpy_MinSL = AUDJPY_MinSL;
    config.usdjpy_MinSL = USDJPY_MinSL;
    config.usdchf_MinSL = USDCHF_MinSL;
    config.xauusd_MinSL = XAUUSD_MinSL;

    // Symbol-Specific Max SL
    config.eurusd_MaxSL = EURUSD_MaxSL;
    config.gbpusd_MaxSL = GBPUSD_MaxSL;
    config.audjpy_MaxSL = AUDJPY_MaxSL;
    config.usdjpy_MaxSL = USDJPY_MaxSL;
    config.usdchf_MaxSL = USDCHF_MaxSL;
    config.xauusd_MaxSL = XAUUSD_MaxSL;

    // Gold-Specific
    config.xauusd_ATRTimeframe = XAUUSD_ATRTimeframe;

    // Logging
    config.verboseLogging = VerboseLogging;

    //═══════════════════════════════════════════════════════════════
    // Initialize StrategyEngine
    //═══════════════════════════════════════════════════════════════
    engine = new StrategyEngine(config, csm_data, 9);
    engine.InitializeStrategiesForSymbol(_Symbol);

    Print("✓ StrategyEngine initialized for ", _Symbol);

    //═══════════════════════════════════════════════════════════════
    // Initialize signal exporter
    //═══════════════════════════════════════════════════════════════
    signalExporter = new SignalExporter("CSM_Signals", VerboseLogging);
    Print("✓ Signal exporter initialized");

    //═══════════════════════════════════════════════════════════════
    // Set initial regime
    //═══════════════════════════════════════════════════════════════
    currentRegime = DetectMarketRegime(_Symbol,
                                       TrendingThresholdPercent,
                                       RangingThresholdPercent,
                                       MinADXForTrending,
                                       false);
    lastRegimeCheck = TimeCurrent();
    lastDynamicCheck = TimeCurrent();

    Print("✓ Initial regime: ", EnumToString(currentRegime));

    //═══════════════════════════════════════════════════════════════
    // Set timing intervals
    //═══════════════════════════════════════════════════════════════
    analysisInterval = AnalysisIntervalMinutes * 60;
    regimeCheckInterval = RegimeCheckHours * 3600;

    Print("\n═══ Configuration ═══");
    Print("Analysis Interval: ", AnalysisIntervalMinutes, " minutes");
    Print("Regime Check: ", RegimeCheckHours, " hours");
    Print("Dynamic Regime: ", UseDynamicRegimeDetection ? "ENABLED" : "DISABLED");
    Print("Symbol: ", _Symbol);
    Print("Timeframe: ", EnumToString(AnalysisTimeframe));

    Print("\n╔════════════════════════════════════════════════════════════╗");
    Print("║          Strategy Analysis EA Ready (v2.10)              ║");
    Print("╚════════════════════════════════════════════════════════════╝\n");

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    delete engine;
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
    // Load CSM from file (every tick, but cached internally)
    //═══════════════════════════════════════════════════════════════
    LoadCSMFromFile();
    engine.UpdateCSM(csm_data, 9);  // Update StrategyEngine's CSM copy

    //═══════════════════════════════════════════════════════════════
    // Update regime every 4 hours (independent of analysis interval)
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
    // PHASE 4E: DYNAMIC REGIME RE-EVALUATION
    //═══════════════════════════════════════════════════════════════
    if(UseDynamicRegimeDetection)
    {
        int minutesSinceLastCheck = (int)((currentTime - lastDynamicCheck) / 60);

        if(minutesSinceLastCheck >= DynamicRegimeMinIntervalMinutes)
        {
            double currentADX = GetADX(_Symbol, AnalysisTimeframe, 14);

            if(currentADX > 0)
            {
                // Strong trending signal detected?
                if(currentADX > DynamicRegimeADXThreshold)
                {
                    double ema20 = GetEMA(_Symbol, AnalysisTimeframe, 20);
                    double ema50 = GetEMA(_Symbol, AnalysisTimeframe, 50);
                    double ema100 = GetEMA(_Symbol, AnalysisTimeframe, 100);

                    bool uptrend = (ema20 > ema50 && ema50 > ema100);
                    bool downtrend = (ema20 < ema50 && ema50 < ema100);
                    bool strongTrendingSignals = (uptrend || downtrend);

                    if(strongTrendingSignals && currentRegime != REGIME_TRENDING)
                    {
                        if(VerboseLogging)
                            Print("⚡ DYNAMIC REGIME RECHECK TRIGGERED");

                        MARKET_REGIME previousRegime = currentRegime;
                        currentRegime = DetectMarketRegime(_Symbol,
                                                           TrendingThresholdPercent,
                                                           RangingThresholdPercent,
                                                           MinADXForTrending,
                                                           VerboseLogging);
                        lastRegimeCheck = currentTime;

                        if(previousRegime != currentRegime)
                        {
                            Print("⚡ DYNAMIC REGIME CHANGE: ", EnumToString(previousRegime),
                                  " → ", EnumToString(currentRegime));
                            dynamicRegimeTriggeredThisCycle = true;
                        }
                    }
                }
                // Weak ADX but regime is TRENDING?
                else if(currentADX < 20 && currentRegime == REGIME_TRENDING)
                {
                    if(VerboseLogging)
                        Print("⚡ DYNAMIC REGIME RECHECK (Weak ADX)");

                    MARKET_REGIME previousRegime = currentRegime;
                    currentRegime = DetectMarketRegime(_Symbol,
                                                       TrendingThresholdPercent,
                                                       RangingThresholdPercent,
                                                       MinADXForTrending,
                                                       VerboseLogging);
                    lastRegimeCheck = currentTime;

                    if(previousRegime != currentRegime)
                    {
                        Print("⚡ DYNAMIC REGIME CHANGE: ", EnumToString(previousRegime),
                              " → ", EnumToString(currentRegime));
                        dynamicRegimeTriggeredThisCycle = true;
                    }
                }
            }

            lastDynamicCheck = currentTime;
        }
    }

    //═══════════════════════════════════════════════════════════════
    // ANALYSIS INTERVAL THROTTLE
    //═══════════════════════════════════════════════════════════════
    if(currentTime - lastAnalysisTime < analysisInterval)
        return;

    lastAnalysisTime = currentTime;

    //═══════════════════════════════════════════════════════════════
    // USE STRATEGYENGINE TO EVALUATE SYMBOL
    //═══════════════════════════════════════════════════════════════
    StrategySignal signal;
    MARKET_REGIME detectedRegime;
    string failureReason;

    bool hasValidSignal = engine.EvaluateSymbol(_Symbol,
                                                 AnalysisTimeframe,
                                                 signal,
                                                 detectedRegime,
                                                 failureReason);

    // Get CSM differential for export (engine already calculated it)
    double csmDiff = engine.GetCSMDifferential(_Symbol);

    //═══════════════════════════════════════════════════════════════
    // Export signal to JSON file
    //═══════════════════════════════════════════════════════════════
    if(hasValidSignal && signal.signal != 0)  // BUY or SELL
    {
        signalExporter.ExportSignalFromStrategy(_Symbol, signal, csmDiff,
                                                 EnumToString(detectedRegime),
                                                 dynamicRegimeTriggeredThisCycle);

        if(VerboseLogging)
            Print("✓ Valid signal exported: ", signal.signal == 1 ? "BUY" : "SELL");

        dynamicRegimeTriggeredThisCycle = false;
    }
    else if(hasValidSignal)  // HOLD/NEUTRAL (strategy ran but no entry)
    {
        signalExporter.ExportSignalFromStrategy(_Symbol, signal, csmDiff,
                                                 EnumToString(detectedRegime),
                                                 dynamicRegimeTriggeredThisCycle);

        if(VerboseLogging)
            Print("✗ No valid signal - HOLD");

        dynamicRegimeTriggeredThisCycle = false;
    }
    else  // NOT_TRADABLE (CSM gate failed or wrong regime)
    {
        signalExporter.ClearSignal(_Symbol,
                                    EnumToString(detectedRegime),
                                    csmDiff,
                                    failureReason);

        if(VerboseLogging)
            Print("✗ ", failureReason);

        dynamicRegimeTriggeredThisCycle = false;
    }
}

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
        if(VerboseLogging && csm_data[0].data_valid)
        {
            Print("⚠ CSM file not found: ", filename);
            Print("  Make sure CSM_AnalysisEA is running!");
        }

        for(int i = 0; i < 9; i++)
            csm_data[i].data_valid = false;

        return;
    }

    // Parse CSM file
    int currencies_loaded = 0;

    while(!FileIsEnding(handle))
    {
        string line = FileReadString(handle);

        if(StringLen(line) == 0 || StringSubstr(line, 0, 1) == "#")
            continue;

        int comma_pos = StringFind(line, ",");
        if(comma_pos > 0)
        {
            string currency = StringSubstr(line, 0, comma_pos);
            string strength_str = StringSubstr(line, comma_pos + 1);
            double strength = StringToDouble(strength_str);

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

    if(currencies_loaded > 0 && VerboseLogging)
        Print("✅ CSM loaded: ", currencies_loaded, " currencies");
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
