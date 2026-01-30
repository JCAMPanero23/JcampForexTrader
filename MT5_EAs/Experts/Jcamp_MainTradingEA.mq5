//+------------------------------------------------------------------+
//|                                        Jcamp_MainTradingEA.mq5   |
//|                                            JcampForexTrader       |
//|                                       CSM Main Trading EA         |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "2.00"
#property description "CSM Alpha Main Trading EA - 4 Asset System"
#property description "Trades: EURUSD.sml, GBPUSD.sml, AUDJPY, XAUUSD.sml (with broker suffix)"
#property strict

// Include modular components
#include <JcampStrategies/Trading/SignalReader.mqh>
#include <JcampStrategies/Trading/TradeExecutor.mqh>
#include <JcampStrategies/Trading/PositionManager.mqh>
#include <JcampStrategies/Trading/PerformanceTracker.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

// --- Symbol Configuration ---
input string TradedSymbols = "EURUSD.sml,GBPUSD.sml,AUDJPY,XAUUSD.sml";  // ✅ CSM Alpha: 4 assets (with broker suffix)

// --- Signal Settings ---
input string SignalFolder = "CSM_Signals";             // Folder containing signal files
input int SignalCheckIntervalSeconds = 60;             // Check for new signals every X seconds
input int MinConfidence = 70;                          // Minimum confidence to execute trade (0-135)
input int MaxSignalAgeMinutes = 30;                    // Max age of signal to be valid (minutes)

// --- Risk Management ---
input double RiskPercent = 1.0;                        // Risk per trade (% of account balance)
input double MaxSpreadPips = 2.0;                      // Base spread limit (pips) - multiplied per symbol
input double SpreadMultiplierEURUSD = 1.0;             // EURUSD spread multiplier (1x = 2.0 pips)
input double SpreadMultiplierGBPUSD = 1.0;             // GBPUSD spread multiplier (1x = 2.0 pips)
input double SpreadMultiplierAUDJPY = 1.0;             // AUDJPY spread multiplier (1x = 2.0 pips)
input double SpreadMultiplierXAUUSD = 5.0;             // XAUUSD (Gold) spread multiplier (5x = 10.0 pips)
input int MaxPositionsPerSymbol = 1;                   // Max simultaneous positions per symbol
input int MaxTotalPositions = 3;                       // Max total open positions

// --- Position Management ---
input bool EnableTrailingStop = true;                  // Enable trailing stop
input int TrailingStopPips = 20;                       // Trailing stop distance (pips)
input int TrailingStartPips = 30;                      // Start trailing after X pips profit

// --- Performance Export ---
input string ExportFolder = "CSM_Data";                // Folder for performance data export
input int TradeHistoryCheckIntervalSeconds = 5;        // Check for closed trades every X seconds (real-time detection)
input int ExportIntervalSeconds = 300;                 // Export performance data every X seconds (5 min)

// --- System Settings ---
input int MagicNumber = 100001;                        // Magic number for this EA
input bool VerboseLogging = true;                      // Enable detailed logging

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
SignalReader*       signalReader;
TradeExecutor*      tradeExecutor;
PositionManager*    positionManager;
PerformanceTracker* performanceTracker;

datetime lastSignalCheck = 0;
datetime lastTradeHistoryCheck = 0;
datetime lastExport = 0;

//+------------------------------------------------------------------+
//| Expert Initialization Function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("========================================");
   Print("Jcamp MainTradingEA - Initializing");
   Print("========================================");
   Print("Traded Symbols: ", TradedSymbols);
   Print("Signal Folder: ", SignalFolder);
   Print("Risk Per Trade: ", RiskPercent, "%");
   Print("Min Confidence: ", MinConfidence);
   Print("Magic Number: ", MagicNumber);
   Print("Trade History Check: Every ", TradeHistoryCheckIntervalSeconds, " seconds (real-time)");
   Print("Performance Export: Every ", ExportIntervalSeconds, " seconds");
   Print("========================================");

   // Initialize modules
   signalReader = new SignalReader(SignalFolder, VerboseLogging);
   tradeExecutor = new TradeExecutor(RiskPercent, MinConfidence, MaxSpreadPips, MagicNumber, VerboseLogging,
                                     SpreadMultiplierEURUSD, SpreadMultiplierGBPUSD,
                                     SpreadMultiplierAUDJPY, SpreadMultiplierXAUUSD);
   positionManager = new PositionManager(MagicNumber, EnableTrailingStop, TrailingStopPips, TrailingStartPips, VerboseLogging);
   performanceTracker = new PerformanceTracker(ExportFolder, MagicNumber, VerboseLogging);

   // Verify modules initialized
   if(signalReader == NULL || tradeExecutor == NULL ||
      positionManager == NULL || performanceTracker == NULL)
   {
      Print("ERROR: Failed to initialize modules");
      return(INIT_FAILED);
   }

   // Initial export
   performanceTracker.ExportAll();

   Print("✅ MainTradingEA initialized successfully");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert Deinitialization Function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("========================================");
   Print("Jcamp MainTradingEA - Shutting Down");
   Print("Reason: ", reason);
   Print("========================================");

   // Final export before shutdown
   if(performanceTracker != NULL)
   {
      performanceTracker.ExportAll();
      Print("📊 Final performance data exported");
   }

   // Cleanup
   if(signalReader != NULL) delete signalReader;
   if(tradeExecutor != NULL) delete tradeExecutor;
   if(positionManager != NULL) delete positionManager;
   if(performanceTracker != NULL) delete performanceTracker;

   Print("✅ MainTradingEA shutdown complete");
}

//+------------------------------------------------------------------+
//| Expert Tick Function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Always update positions (trailing stops, etc.)
   if(positionManager != NULL)
      positionManager.UpdatePositions();

   datetime currentTime = TimeCurrent();

   // ✅ NEW: Check for closed trades frequently (every 5 seconds for real-time detection)
   if(currentTime - lastTradeHistoryCheck >= TradeHistoryCheckIntervalSeconds)
   {
      lastTradeHistoryCheck = currentTime;

      if(performanceTracker != NULL)
         performanceTracker.Update();  // Check for new closed trades (lightweight, returns early if none)
   }

   // Check for new signals (throttled)
   if(currentTime - lastSignalCheck >= SignalCheckIntervalSeconds)
   {
      lastSignalCheck = currentTime;
      CheckAndExecuteSignals();
   }

   // Export performance data periodically (separate from checking for trades)
   if(currentTime - lastExport >= ExportIntervalSeconds)
   {
      lastExport = currentTime;

      if(performanceTracker != NULL)
         performanceTracker.ExportAll();  // Export files (Update already called above)
   }
}

//+------------------------------------------------------------------+
//| Check for New Signals and Execute Trades                         |
//+------------------------------------------------------------------+
void CheckAndExecuteSignals()
{
   if(signalReader == NULL || tradeExecutor == NULL || positionManager == NULL)
      return;

   // Read signals for all traded symbols
   SignalData signals[];
   int validSignals = signalReader.ReadMultipleSignals(TradedSymbols, signals);

   if(validSignals == 0)
   {
      if(VerboseLogging)
         Print("No valid signals found");
      return;
   }

   if(VerboseLogging)
      Print("📡 Found ", validSignals, " valid signals");

   // Check current positions
   int totalPositions = positionManager.GetOpenPositionCount();

   // Process each signal
   for(int i = 0; i < ArraySize(signals); i++)
   {
      SignalData signal = signals[i];

      // Skip invalid signals
      if(!signal.isValid)
         continue;

      // Check if signal is tradeable
      if(!signalReader.IsSignalTradeable(signal, MinConfidence, MaxSignalAgeMinutes))
      {
         if(VerboseLogging)
            Print("Signal not tradeable: ", signal.symbol);
         continue;
      }

      // Check position limits
      if(totalPositions >= MaxTotalPositions)
      {
         if(VerboseLogging)
            Print("Max total positions reached: ", totalPositions);
         break;
      }

      int symbolPositions = positionManager.GetOpenPositionCountForSymbol(signal.symbol);
      if(symbolPositions >= MaxPositionsPerSymbol)
      {
         if(VerboseLogging)
            Print("Max positions for ", signal.symbol, " reached: ", symbolPositions);
         continue;
      }

      // Execute trade
      Print("🎯 Executing signal: ", signal.symbol, " ", signal.signalText,
            " | Confidence: ", signal.confidence, " | Strategy: ", signal.strategy);

      ulong ticket = tradeExecutor.ExecuteSignal(signal);

      if(ticket > 0)
      {
         totalPositions++;
         Print("✅ Trade opened successfully: Ticket #", ticket);
      }
      else
      {
         Print("⚠️ Failed to execute signal for ", signal.symbol);
      }
   }
}

//+------------------------------------------------------------------+
//| Trade Transaction Event                                           |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // Track trades for performance monitoring
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(performanceTracker != NULL)
         performanceTracker.Update();
   }
}

//+------------------------------------------------------------------+
//| Timer Event (Optional)                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Could be used for additional periodic tasks
   // For now, we handle everything in OnTick
}

//+------------------------------------------------------------------+
//| Chart Event (Optional)                                            |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Could be used for manual controls or UI interaction
   // For now, EA runs fully automated
}

//+------------------------------------------------------------------+
