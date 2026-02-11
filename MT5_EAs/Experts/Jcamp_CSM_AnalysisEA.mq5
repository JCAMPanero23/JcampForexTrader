//+------------------------------------------------------------------+
//|                                        Jcamp_CSM_AnalysisEA.mq5  |
//|                                   CSM Alpha - 9 Currency System  |
//|                                              With Gold (XAU)     |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      "https://github.com/JCAMPanero23/JcampForexTrader"
#property version   "3.00"
#property description "CSM Alpha: Currency Strength Meter with Gold as 9th currency"
#property description "Calculates competitive strength scoring (0-100) for 9 currencies"
#property description "Session 19: BACKTEST MODE - Generates signals for all 4 assets"
#property description "Exports to csm_current.txt (live) OR full JSON export (backtest)"

//+------------------------------------------------------------------+
//| INCLUDE MODULAR COMPONENTS (Session 19)                          |
//+------------------------------------------------------------------+
#include <JcampStrategies/StrategyEngine.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input group "═══ MODE SELECTION ═══"
input bool   BacktestMode = false;                        // Backtest Mode (generates signals for all 4 assets)

input group "═══ CSM Configuration ═══"
input ENUM_TIMEFRAMES AnalysisTimeframe = PERIOD_H1;      // CSM Calculation Timeframe
input int    CSM_LookbackHours = 48;                      // CSM Lookback Period (hours)
input int    UpdateIntervalMinutes = 60;                  // CSM Update Interval (minutes)

input group "═══ BACKTEST SETTINGS ═══"
input ENUM_TIMEFRAMES SignalTimeframe = PERIOD_H1;        // Strategy evaluation timeframe
input int    SignalCheckIntervalMinutes = 15;             // Signal generation interval (M15)

// ✅ Tradable symbols in backtest (all 4 assets)
input group "═══ BACKTEST SYMBOLS ═══"
input string Symbol1 = "EURUSD";                          // Symbol 1
input string Symbol2 = "GBPUSD";                          // Symbol 2
input string Symbol3 = "AUDJPY";                          // Symbol 3
input string Symbol4 = "USDJPY";                          // Symbol 4 (replaces XAUUSD)
input string Symbol5 = "USDCHF";                          // Symbol 5 (5-asset system)

input group "═══ Export Settings ═══"
input string ExportFolder = "CSM_Data";                   // Export folder name
input bool   VerboseLogging = false;                      // Verbose logging (disable in backtest!)

input group "═══ Broker Settings ═══"
input string BrokerSuffix = ".r";                         // Broker symbol suffix (e.g., ".r")

//+------------------------------------------------------------------+
//| STRATEGY ENGINE CONFIGURATION (Session 19)                       |
//+------------------------------------------------------------------+
input group "═══ STRATEGY ENGINE CONFIG ═══"
input double MinCSMDifferential = 15.0;                   // Min CSM diff
input int    TrendingThresholdPercent = 55;               // Trending threshold (%)
input int    RangingThresholdPercent = 40;                // Ranging threshold (%)
input double MinADXForTrending = 30.0;                    // Min ADX for trending
input bool   EnableTrendRider = true;                     // Enable TrendRider
input bool   EnableRangeRider = true;                     // Enable RangeRider
input int    MinConfidenceScore = 65;                     // Min confidence

input group "═══ ATR-BASED SL/TP ═══"
input int    ATRPeriod = 14;                              // ATR period

// Symbol-specific bounds (5 assets)
input group "═══ EURUSD ═══"
input double EURUSD_MinSL = 20.0;
input double EURUSD_MaxSL = 60.0;
input double EURUSD_ATRMultiplier = 0.5;

input group "═══ GBPUSD ═══"
input double GBPUSD_MinSL = 25.0;
input double GBPUSD_MaxSL = 80.0;
input double GBPUSD_ATRMultiplier = 0.6;

input group "═══ AUDJPY ═══"
input double AUDJPY_MinSL = 25.0;
input double AUDJPY_MaxSL = 70.0;
input double AUDJPY_ATRMultiplier = 0.5;

input group "═══ USDJPY ═══"
input double USDJPY_MinSL = 25.0;
input double USDJPY_MaxSL = 70.0;
input double USDJPY_ATRMultiplier = 0.5;

input group "═══ USDCHF ═══"
input double USDCHF_MinSL = 20.0;
input double USDCHF_MaxSL = 60.0;
input double USDCHF_ATRMultiplier = 0.5;

input group "═══ XAUUSD (NOT USED) ═══"
input double XAUUSD_MinSL = 50.0;
input double XAUUSD_MaxSL = 200.0;
input double XAUUSD_ATRMultiplier = 0.6;
input ENUM_TIMEFRAMES XAUUSD_ATRTimeframe = PERIOD_H4;

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

struct PairData
{
    string symbol;
    double current_price;
    double price_24h_ago;
    double price_change_24h;
    bool   is_synthetic;        // True for synthetic Gold pairs
    bool   symbol_available;
};

//+------------------------------------------------------------------+
//| BACKTEST SIGNAL BUFFERING (Session 19)                           |
//+------------------------------------------------------------------+
struct SignalRecord
{
    datetime timestamp;
    string   symbol;
    int      signal;           // -1=SELL, 0=HOLD, 1=BUY
    int      confidence;
    double   csmDiff;
    string   regime;
    double   stopLossDollars;
    double   takeProfitDollars;
};

struct TradeRecord
{
    datetime entry_time;
    datetime exit_time;
    string   symbol;
    int      direction;        // 1=BUY, -1=SELL
    double   entry_price;
    double   exit_price;
    double   sl_price;
    double   tp_price;
    double   profit_dollars;
    double   r_multiple;
    string   exit_reason;
};

// Dynamic arrays for buffering
SignalRecord signalBuffer[];
TradeRecord tradeBuffer[];
int signalCount = 0;
int tradeCount = 0;

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
// ✅ 9 CURRENCIES (with XAU - Gold)
string currencies[9] = {"USD", "EUR", "GBP", "JPY", "CHF", "AUD", "CAD", "NZD", "XAU"};
CurrencyStrengthData csm_data[9];

// ✅ 21 PAIRS (16 traditional + 5 Gold pairs)
string pair_list[21] = {
    "EURUSD", "GBPUSD", "USDJPY", "USDCHF",
    "USDCAD", "AUDUSD", "NZDUSD", "EURGBP",
    "GBPNZD", "AUDNZD", "NZDCAD", "NZDJPY",
    "GBPJPY", "GBPCHF", "GBPCAD", "EURJPY",
    "XAUUSD",   // Real Gold pair
    "XAUEUR",   // Synthetic
    "XAUJPY",   // Synthetic
    "XAUGBP",   // Synthetic
    "XAUAUD"    // Synthetic
};

PairData pair_data[21];

// Strategy Engine (Session 19)
StrategyEngine* engine;

// Tradable symbols list (5 assets)
string tradableSymbols[5];
int numTradableSymbols = 5;

// Timing
datetime last_csm_update = 0;
datetime last_signal_check = 0;
int update_interval_seconds;
int signal_check_interval_seconds;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("\n╔════════════════════════════════════════════════════════════╗");
    Print("║         Jcamp CSM Analysis EA - Initialization            ║");
    if(BacktestMode)
        Print("║           🎯 BACKTEST MODE ENABLED 🎯                    ║");
    else
        Print("║              CSM Alpha - Live Mode                       ║");
    Print("╚════════════════════════════════════════════════════════════╝\n");

    // Initialize tradable symbols
    tradableSymbols[0] = Symbol1 + BrokerSuffix;
    tradableSymbols[1] = Symbol2 + BrokerSuffix;
    tradableSymbols[2] = Symbol3 + BrokerSuffix;
    tradableSymbols[3] = Symbol4 + BrokerSuffix;
    tradableSymbols[4] = Symbol5 + BrokerSuffix;

    if(BacktestMode)
    {
        Print("📊 Tradable Symbols (5 assets):");
        for(int i = 0; i < numTradableSymbols; i++)
            Print("   ", i+1, ". ", tradableSymbols[i]);
    }

    // Convert intervals to seconds
    update_interval_seconds = UpdateIntervalMinutes * 60;
    signal_check_interval_seconds = SignalCheckIntervalMinutes * 60;

    // Initialize CSM data
    for(int i = 0; i < 9; i++)
    {
        csm_data[i].currency = currencies[i];
        csm_data[i].current_strength = 50.0;
        csm_data[i].strength_24h_ago = 50.0;
        csm_data[i].strength_change_24h = 0.0;
        csm_data[i].data_valid = false;
        csm_data[i].last_update = 0;
    }

    // Initialize pair data
    for(int i = 0; i < 21; i++)
    {
        string symbol_name = pair_list[i] + BrokerSuffix;

        bool is_gold_synthetic = (pair_list[i] == "XAUEUR" ||
                                  pair_list[i] == "XAUJPY" ||
                                  pair_list[i] == "XAUGBP" ||
                                  pair_list[i] == "XAUAUD");

        pair_data[i].symbol = symbol_name;
        pair_data[i].current_price = 0.0;
        pair_data[i].price_24h_ago = 0.0;
        pair_data[i].price_change_24h = 0.0;
        pair_data[i].is_synthetic = is_gold_synthetic;
        pair_data[i].symbol_available = false;

        if(!is_gold_synthetic)
        {
            if(SymbolInfoInteger(symbol_name, SYMBOL_SELECT))
            {
                pair_data[i].symbol_available = true;
                if(!BacktestMode || VerboseLogging)
                    Print("✅ ", symbol_name, " available");
            }
            else
            {
                if(!BacktestMode)
                    Print("⚠️  ", symbol_name, " not available");
            }
        }
        else
        {
            pair_data[i].symbol_available = true;
            if(!BacktestMode && VerboseLogging)
                Print("🔨 ", pair_list[i], " (synthetic)");
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SESSION 19: Initialize StrategyEngine (if backtest mode)
    // ═══════════════════════════════════════════════════════════════
    if(BacktestMode)
    {
        StrategyEngineConfig config;

        config.minCSMDifferential = MinCSMDifferential;
        config.trendingThresholdPercent = TrendingThresholdPercent;
        config.rangingThresholdPercent = RangingThresholdPercent;
        config.minADXForTrending = MinADXForTrending;
        config.enableTrendRider = EnableTrendRider;
        config.enableRangeRider = EnableRangeRider;
        config.minConfidenceScore = MinConfidenceScore;
        config.atrPeriod = ATRPeriod;

        config.eurusd_ATRMultiplier = EURUSD_ATRMultiplier;
        config.gbpusd_ATRMultiplier = GBPUSD_ATRMultiplier;
        config.audjpy_ATRMultiplier = AUDJPY_ATRMultiplier;
        config.usdjpy_ATRMultiplier = USDJPY_ATRMultiplier;
        config.usdchf_ATRMultiplier = USDCHF_ATRMultiplier;
        config.xauusd_ATRMultiplier = XAUUSD_ATRMultiplier;

        config.eurusd_MinSL = EURUSD_MinSL;
        config.gbpusd_MinSL = GBPUSD_MinSL;
        config.audjpy_MinSL = AUDJPY_MinSL;
        config.usdjpy_MinSL = USDJPY_MinSL;
        config.usdchf_MinSL = USDCHF_MinSL;
        config.xauusd_MinSL = XAUUSD_MinSL;

        config.eurusd_MaxSL = EURUSD_MaxSL;
        config.gbpusd_MaxSL = GBPUSD_MaxSL;
        config.audjpy_MaxSL = AUDJPY_MaxSL;
        config.usdjpy_MaxSL = USDJPY_MaxSL;
        config.usdchf_MaxSL = USDCHF_MaxSL;
        config.xauusd_MaxSL = XAUUSD_MaxSL;

        config.xauusd_ATRTimeframe = XAUUSD_ATRTimeframe;
        config.verboseLogging = VerboseLogging;

        engine = new StrategyEngine(config, csm_data, 9);
        Print("✅ StrategyEngine initialized");

        // Resize signal buffer (estimate: 1 year M15 = 35,040 bars × 5 symbols = 175,200 signals)
        ArrayResize(signalBuffer, 200000);
        ArrayResize(tradeBuffer, 10000);  // Estimate max 10,000 trades
        Print("✅ Signal buffer allocated (200k signals, 10k trades)");
    }

    // Initial CSM calculation
    Print("\n🔄 Running initial CSM calculation...");
    UpdateFullCSM();

    if(csm_data[0].data_valid)
    {
        Print("✅ Initial CSM calculation successful");

        if(!BacktestMode)
        {
            ExportCSM();
            last_csm_update = TimeCurrent();
            Print("🕐 Next update in ", UpdateIntervalMinutes, " minutes");
        }
        else
        {
            last_csm_update = TimeCurrent();
            last_signal_check = TimeCurrent();
            Print("🕐 Backtest starting - signals every ", SignalCheckIntervalMinutes, " minutes");
        }
    }
    else
    {
        Print("⚠️  Initial CSM calculation returned no data");
    }

    if(!BacktestMode)
        Print("\n⏰ CSM will update every ", UpdateIntervalMinutes, " minutes");
    else
        Print("\n⏰ Backtest Mode: CSM every ", UpdateIntervalMinutes, " min, Signals every ", SignalCheckIntervalMinutes, " min");

    Print("═══════════════════════════════════════════════════════════\n");

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("\n╔════════════════════════════════════════════════════════════╗");
    Print("║          Jcamp CSM Analysis EA - Shutdown                 ║");
    Print("╚════════════════════════════════════════════════════════════╝");

    if(BacktestMode)
    {
        Print("\n🎯 BACKTEST COMPLETE - Exporting results...");
        Print("   Signals collected: ", signalCount);
        Print("   Trades executed: ", tradeCount);

        ExportBacktestResults();

        delete engine;
        Print("✅ Backtest results exported successfully");
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    datetime currentTime = TimeCurrent();
    static int tick_count = 0;
    tick_count++;

    // ═══════════════════════════════════════════════════════════════
    // CSM UPDATE (both live and backtest modes)
    // ═══════════════════════════════════════════════════════════════
    if(currentTime - last_csm_update >= update_interval_seconds)
    {
        if(VerboseLogging)
            Print("⏰ CSM Update at ", TimeToString(currentTime, TIME_DATE|TIME_MINUTES));

        UpdateFullCSM();

        if(csm_data[0].data_valid)
        {
            if(!BacktestMode)
            {
                ExportCSM();
                if(VerboseLogging)
                    PrintCSMSummary();
            }

            last_csm_update = currentTime;
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // BACKTEST MODE: SIGNAL GENERATION FOR ALL 5 ASSETS
    // ═══════════════════════════════════════════════════════════════
    if(BacktestMode && (currentTime - last_signal_check >= signal_check_interval_seconds))
    {
        last_signal_check = currentTime;

        // Generate signals for all 5 tradable symbols
        for(int i = 0; i < numTradableSymbols; i++)
        {
            string symbol = tradableSymbols[i];

            // Initialize strategies for this symbol
            engine.InitializeStrategiesForSymbol(symbol);

            // Evaluate symbol
            StrategySignal signal;
            MARKET_REGIME regime;
            string failureReason;

            bool hasValidSignal = engine.EvaluateSymbol(symbol,
                                                         SignalTimeframe,
                                                         signal,
                                                         regime,
                                                         failureReason);

            double csmDiff = engine.GetCSMDifferential(symbol);

            // Buffer signal (even if HOLD/NOT_TRADABLE)
            if(signalCount < ArraySize(signalBuffer))
            {
                signalBuffer[signalCount].timestamp = currentTime;
                signalBuffer[signalCount].symbol = symbol;
                signalBuffer[signalCount].signal = hasValidSignal ? signal.signal : 0;
                signalBuffer[signalCount].confidence = hasValidSignal ? signal.confidence : 0;
                signalBuffer[signalCount].csmDiff = csmDiff;
                signalBuffer[signalCount].regime = EnumToString(regime);
                signalBuffer[signalCount].stopLossDollars = hasValidSignal ? signal.stopLossDollars : 0;
                signalBuffer[signalCount].takeProfitDollars = hasValidSignal ? signal.takeProfitDollars : 0;
                signalCount++;
            }

            // Execute trade for ATTACHED SYMBOL only (if BUY/SELL signal)
            if(hasValidSignal && signal.signal != 0 && symbol == _Symbol)
            {
                ExecuteBacktestTrade(symbol, signal, currentTime);
            }
        }

        // Progress logging (every 100 signal cycles = 1,500 bars)
        if(VerboseLogging && (signalCount % 500 == 0))
        {
            Print("📊 Progress: ", signalCount, " signals, ", tradeCount, " trades");
        }
    }
}

//+------------------------------------------------------------------+
//| Execute Backtest Trade (attached symbol only)                    |
//+------------------------------------------------------------------+
void ExecuteBacktestTrade(string symbol, StrategySignal &signal, datetime entryTime)
{
    // Simple backtest trade execution (no position tracking, just record)
    double entry_price = SymbolInfoDouble(symbol, SYMBOL_BID);

    if(entry_price <= 0)
        return;

    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double pipSize = (digits == 3 || digits == 5) ? point * 10.0 : point;

    // Calculate SL/TP prices
    double sl_price = 0, tp_price = 0;

    if(signal.signal == 1)  // BUY
    {
        sl_price = entry_price - signal.stopLossDollars;
        tp_price = entry_price + signal.takeProfitDollars;
    }
    else  // SELL
    {
        sl_price = entry_price + signal.stopLossDollars;
        tp_price = entry_price - signal.takeProfitDollars;
    }

    // Record trade entry (exit will be simulated based on SL/TP hit)
    // For now, just log the entry (full trade tracking in Python simulator)
    if(tradeCount < ArraySize(tradeBuffer))
    {
        tradeBuffer[tradeCount].entry_time = entryTime;
        tradeBuffer[tradeCount].exit_time = 0;  // Will be filled by Python
        tradeBuffer[tradeCount].symbol = symbol;
        tradeBuffer[tradeCount].direction = signal.signal;
        tradeBuffer[tradeCount].entry_price = entry_price;
        tradeBuffer[tradeCount].exit_price = 0;
        tradeBuffer[tradeCount].sl_price = sl_price;
        tradeBuffer[tradeCount].tp_price = tp_price;
        tradeBuffer[tradeCount].profit_dollars = 0;
        tradeBuffer[tradeCount].r_multiple = 0;
        tradeBuffer[tradeCount].exit_reason = "PENDING";
        tradeCount++;

        if(VerboseLogging)
        {
            Print("🔵 Trade #", tradeCount, ": ", signal.signal == 1 ? "BUY" : "SELL",
                  " ", symbol, " @ ", DoubleToString(entry_price, digits),
                  " | SL: ", DoubleToString(sl_price, digits),
                  " | TP: ", DoubleToString(tp_price, digits));
        }
    }
}

//+------------------------------------------------------------------+
//| Update Full CSM (9-currency system with Gold)                    |
//+------------------------------------------------------------------+
void UpdateFullCSM()
{
    // Reset all strengths to neutral (50.0)
    for(int i = 0; i < 9; i++)
    {
        csm_data[i].current_strength = 50.0;
        csm_data[i].strength_change_24h = 0.0;
        csm_data[i].data_valid = false;
    }

    // Calculate lookback bars
    double hoursPerBar = (double)PeriodSeconds(AnalysisTimeframe) / 3600.0;
    int bars_24h = (int)MathCeil(24.0 / hoursPerBar);

    // ═══════════════════════════════════════════════════════════════
    // STEP 1: Get prices for REAL pairs (needed for synthetic calc)
    // ═══════════════════════════════════════════════════════════════
    double xauusd_current = 0, xauusd_24h = 0;
    double eurusd_current = 0, eurusd_24h = 0;
    double gbpusd_current = 0, gbpusd_24h = 0;
    double audusd_current = 0, audusd_24h = 0;
    double usdjpy_current = 0, usdjpy_24h = 0;

    // Get XAUUSD (needed for all synthetic Gold pairs)
    int xauusd_idx = GetPairIndex("XAUUSD");
    if(xauusd_idx >= 0 && pair_data[xauusd_idx].symbol_available)
    {
        double close[];
        ArraySetAsSeries(close, true);
        int copied = CopyClose(pair_data[xauusd_idx].symbol, AnalysisTimeframe, 0, bars_24h + 1, close);
        if(copied > bars_24h)
        {
            xauusd_current = close[0];
            xauusd_24h = close[bars_24h];
        }
    }

    // Get EURUSD (for XAUEUR)
    int eurusd_idx = GetPairIndex("EURUSD");
    if(eurusd_idx >= 0 && pair_data[eurusd_idx].symbol_available)
    {
        double close[];
        ArraySetAsSeries(close, true);
        int copied = CopyClose(pair_data[eurusd_idx].symbol, AnalysisTimeframe, 0, bars_24h + 1, close);
        if(copied > bars_24h)
        {
            eurusd_current = close[0];
            eurusd_24h = close[bars_24h];
        }
    }

    // Get GBPUSD (for XAUGBP)
    int gbpusd_idx = GetPairIndex("GBPUSD");
    if(gbpusd_idx >= 0 && pair_data[gbpusd_idx].symbol_available)
    {
        double close[];
        ArraySetAsSeries(close, true);
        int copied = CopyClose(pair_data[gbpusd_idx].symbol, AnalysisTimeframe, 0, bars_24h + 1, close);
        if(copied > bars_24h)
        {
            gbpusd_current = close[0];
            gbpusd_24h = close[bars_24h];
        }
    }

    // Get AUDUSD (for XAUAUD)
    int audusd_idx = GetPairIndex("AUDUSD");
    if(audusd_idx >= 0 && pair_data[audusd_idx].symbol_available)
    {
        double close[];
        ArraySetAsSeries(close, true);
        int copied = CopyClose(pair_data[audusd_idx].symbol, AnalysisTimeframe, 0, bars_24h + 1, close);
        if(copied > bars_24h)
        {
            audusd_current = close[0];
            audusd_24h = close[bars_24h];
        }
    }

    // Get USDJPY (for XAUJPY)
    int usdjpy_idx = GetPairIndex("USDJPY");
    if(usdjpy_idx >= 0 && pair_data[usdjpy_idx].symbol_available)
    {
        double close[];
        ArraySetAsSeries(close, true);
        int copied = CopyClose(pair_data[usdjpy_idx].symbol, AnalysisTimeframe, 0, bars_24h + 1, close);
        if(copied > bars_24h)
        {
            usdjpy_current = close[0];
            usdjpy_24h = close[bars_24h];
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // STEP 2: Process ALL pairs (real + synthetic)
    // ═══════════════════════════════════════════════════════════════
    for(int i = 0; i < 21; i++)
    {
        if(!pair_data[i].symbol_available)
            continue;

        // Handle SYNTHETIC Gold pairs
        if(pair_data[i].is_synthetic)
        {
            if(pair_list[i] == "XAUEUR" && eurusd_current > 0 && xauusd_current > 0)
            {
                pair_data[i].current_price = xauusd_current / eurusd_current;
                pair_data[i].price_24h_ago = xauusd_24h / eurusd_24h;
            }
            else if(pair_list[i] == "XAUJPY" && usdjpy_current > 0 && xauusd_current > 0)
            {
                pair_data[i].current_price = xauusd_current * usdjpy_current;
                pair_data[i].price_24h_ago = xauusd_24h * usdjpy_24h;
            }
            else if(pair_list[i] == "XAUGBP" && gbpusd_current > 0 && xauusd_current > 0)
            {
                pair_data[i].current_price = xauusd_current / gbpusd_current;
                pair_data[i].price_24h_ago = xauusd_24h / gbpusd_24h;
            }
            else if(pair_list[i] == "XAUAUD" && audusd_current > 0 && xauusd_current > 0)
            {
                pair_data[i].current_price = xauusd_current / audusd_current;
                pair_data[i].price_24h_ago = xauusd_24h / audusd_24h;
            }

            if(pair_data[i].price_24h_ago > 0)
            {
                pair_data[i].price_change_24h =
                    (pair_data[i].current_price - pair_data[i].price_24h_ago) /
                    pair_data[i].price_24h_ago;
            }
        }
        else
        {
            // Handle REAL pairs
            double close[];
            ArraySetAsSeries(close, true);

            int copied = CopyClose(pair_data[i].symbol, AnalysisTimeframe, 0, bars_24h + 1, close);

            if(copied > bars_24h)
            {
                pair_data[i].current_price = close[0];
                pair_data[i].price_24h_ago = close[bars_24h];

                if(pair_data[i].price_24h_ago > 0)
                {
                    pair_data[i].price_change_24h =
                        (pair_data[i].current_price - pair_data[i].price_24h_ago) /
                        pair_data[i].price_24h_ago;
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // STEP 3: Calculate currency strengths from pair movements
    // ═══════════════════════════════════════════════════════════════
    for(int i = 0; i < 21; i++)
    {
        if(!pair_data[i].symbol_available)
            continue;

        double price_change = pair_data[i].price_change_24h;

        if(price_change == 0.0 && pair_data[i].price_24h_ago == 0.0)
            continue;

        double weight = 1.0;
        if(pair_list[i] == "XAUUSD" || pair_list[i] == "EURUSD" || pair_list[i] == "GBPUSD")
            weight = 1.5;

        string base_currency = StringSubstr(pair_list[i], 0, 3);
        string quote_currency = StringSubstr(pair_list[i], 3, 3);

        int base_idx = GetCurrencyIndex(base_currency);
        int quote_idx = GetCurrencyIndex(quote_currency);

        if(base_idx >= 0 && quote_idx >= 0)
        {
            double strength_change = price_change * 100.0 * 2.0 * weight;

            csm_data[base_idx].current_strength += strength_change;
            csm_data[base_idx].strength_change_24h += strength_change;

            csm_data[quote_idx].current_strength -= strength_change;
            csm_data[quote_idx].strength_change_24h -= strength_change;
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // STEP 4: Normalize to 0-100 scale
    // ═══════════════════════════════════════════════════════════════
    NormalizeStrengthValues();

    datetime currentTime = TimeCurrent();
    for(int i = 0; i < 9; i++)
    {
        csm_data[i].data_valid = true;
        csm_data[i].last_update = currentTime;
    }
}

//+------------------------------------------------------------------+
//| Normalize Strength Values to 0-100                               |
//+------------------------------------------------------------------+
void NormalizeStrengthValues()
{
    double min_strength = csm_data[0].current_strength;
    double max_strength = csm_data[0].current_strength;

    for(int i = 1; i < 9; i++)
    {
        if(csm_data[i].current_strength < min_strength)
            min_strength = csm_data[i].current_strength;
        if(csm_data[i].current_strength > max_strength)
            max_strength = csm_data[i].current_strength;
    }

    double range = max_strength - min_strength;

    if(range > 0.001)
    {
        for(int i = 0; i < 9; i++)
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
        for(int i = 0; i < 9; i++)
        {
            csm_data[i].current_strength = 50.0;
        }
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
//| Get Pair Index                                                    |
//+------------------------------------------------------------------+
int GetPairIndex(string pair)
{
    for(int i = 0; i < 21; i++)
    {
        if(pair_list[i] == pair)
            return i;
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Export CSM to File (Live Mode)                                   |
//+------------------------------------------------------------------+
void ExportCSM()
{
    string filename = ExportFolder + "\\csm_current.txt";
    int handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI);

    if(handle == INVALID_HANDLE)
    {
        Print("❌ ERROR: Failed to open file for writing: ", filename);
        return;
    }

    FileWriteString(handle, "# CSM Alpha - 9 Currency Strength Meter\n");
    FileWriteString(handle, "# Updated: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + "\n");
    FileWriteString(handle, "# Format: CURRENCY,STRENGTH\n\n");

    for(int i = 0; i < 9; i++)
    {
        if(csm_data[i].data_valid)
        {
            FileWriteString(handle, csm_data[i].currency + "," +
                          DoubleToString(csm_data[i].current_strength, 2) + "\n");
        }
    }

    FileClose(handle);

    if(VerboseLogging)
        Print("✅ CSM exported to: ", filename);
}

//+------------------------------------------------------------------+
//| Export Backtest Results (JSON format)                            |
//+------------------------------------------------------------------+
void ExportBacktestResults()
{
    string filename = ExportFolder + "\\backtest_" + _Symbol + "_" +
                      TimeToString(TimeCurrent(), TIME_DATE) + ".json";

    // Replace colons (not allowed in filenames)
    StringReplace(filename, ":", "-");

    int handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI);

    if(handle == INVALID_HANDLE)
    {
        Print("❌ ERROR: Failed to open backtest file: ", filename);
        return;
    }

    // Write JSON header
    FileWriteString(handle, "{\n");
    FileWriteString(handle, "  \"backtest_info\": {\n");
    FileWriteString(handle, "    \"symbol\": \"" + _Symbol + "\",\n");
    FileWriteString(handle, "    \"total_signals\": " + IntegerToString(signalCount) + ",\n");
    FileWriteString(handle, "    \"total_trades\": " + IntegerToString(tradeCount) + ",\n");
    FileWriteString(handle, "    \"timeframe\": \"" + EnumToString(SignalTimeframe) + "\"\n");
    FileWriteString(handle, "  },\n");

    // Write signals array
    FileWriteString(handle, "  \"signals\": [\n");
    for(int i = 0; i < signalCount; i++)
    {
        FileWriteString(handle, "    {\n");
        FileWriteString(handle, "      \"timestamp\": \"" + TimeToString(signalBuffer[i].timestamp, TIME_DATE|TIME_MINUTES) + "\",\n");
        FileWriteString(handle, "      \"symbol\": \"" + signalBuffer[i].symbol + "\",\n");
        FileWriteString(handle, "      \"signal\": " + IntegerToString(signalBuffer[i].signal) + ",\n");
        FileWriteString(handle, "      \"confidence\": " + IntegerToString(signalBuffer[i].confidence) + ",\n");
        FileWriteString(handle, "      \"csm_diff\": " + DoubleToString(signalBuffer[i].csmDiff, 2) + ",\n");
        FileWriteString(handle, "      \"regime\": \"" + signalBuffer[i].regime + "\",\n");
        FileWriteString(handle, "      \"sl\": " + DoubleToString(signalBuffer[i].stopLossDollars, 5) + ",\n");
        FileWriteString(handle, "      \"tp\": " + DoubleToString(signalBuffer[i].takeProfitDollars, 5) + "\n");
        FileWriteString(handle, "    }" + (i < signalCount - 1 ? "," : "") + "\n");
    }
    FileWriteString(handle, "  ],\n");

    // Write trades array
    FileWriteString(handle, "  \"trades\": [\n");
    for(int i = 0; i < tradeCount; i++)
    {
        FileWriteString(handle, "    {\n");
        FileWriteString(handle, "      \"entry_time\": \"" + TimeToString(tradeBuffer[i].entry_time, TIME_DATE|TIME_MINUTES) + "\",\n");
        FileWriteString(handle, "      \"symbol\": \"" + tradeBuffer[i].symbol + "\",\n");
        FileWriteString(handle, "      \"direction\": " + IntegerToString(tradeBuffer[i].direction) + ",\n");
        FileWriteString(handle, "      \"entry_price\": " + DoubleToString(tradeBuffer[i].entry_price, 5) + ",\n");
        FileWriteString(handle, "      \"sl_price\": " + DoubleToString(tradeBuffer[i].sl_price, 5) + ",\n");
        FileWriteString(handle, "      \"tp_price\": " + DoubleToString(tradeBuffer[i].tp_price, 5) + "\n");
        FileWriteString(handle, "    }" + (i < tradeCount - 1 ? "," : "") + "\n");
    }
    FileWriteString(handle, "  ]\n");

    FileWriteString(handle, "}\n");

    FileClose(handle);

    Print("✅ Backtest results exported to: ", filename);
}

//+------------------------------------------------------------------+
//| Print CSM Summary                                                 |
//+------------------------------------------------------------------+
void PrintCSMSummary()
{
    Print("\n╔════════════════════════════════════════════╗");
    Print("║      CSM Alpha - Currency Strengths        ║");
    Print("╠════════════════════════════════════════════╣");

    for(int i = 0; i < 9; i++)
    {
        if(csm_data[i].data_valid)
        {
            string bar = "";
            int strength_bars = (int)(csm_data[i].current_strength / 5.0);
            for(int j = 0; j < strength_bars; j++)
                bar += "█";

            Print("║ ", csm_data[i].currency, ": ",
                  StringFormat("%5.1f", csm_data[i].current_strength),
                  " ", bar);
        }
    }

    Print("╚════════════════════════════════════════════╝\n");
}
//+------------------------------------------------------------------+
