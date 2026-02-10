//+------------------------------------------------------------------+
//|                                        Jcamp_MainTradingEA.mq5   |
//|                                            JcampForexTrader       |
//|                                       CSM Main Trading EA         |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "2.10"
#property description "CSM Alpha Main Trading EA - 5 Asset System (Session 19)"
#property description "Trades: EURUSD.r, GBPUSD.r, AUDJPY.r, USDJPY.r, USDCHF.r (with broker suffix)"
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
input string TradedSymbols = "EURUSD.r,GBPUSD.r,AUDJPY.r,USDJPY.r,USDCHF.r";  // ✅ Session 19: 5 assets (Gold removed, replaced with USDJPY + USDCHF)

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
input double SpreadMultiplierUSDJPY = 1.0;             // USDJPY spread multiplier (1x = 2.0 pips) - Session 19
input double SpreadMultiplierUSDCHF = 1.0;             // USDCHF spread multiplier (1x = 2.0 pips) - Session 19
// input double SpreadMultiplierXAUUSD = 15.0;         // XAUUSD (Gold) - Disabled Session 19 (resume at $1000+ account)
input int MaxPositionsPerSymbol = 1;                   // Max simultaneous positions per symbol
input int MaxTotalPositions = 3;                       // Max total open positions

// --- Position Management (Session 16: 3-Phase Trailing) ---
input group "═══ 3-PHASE TRAILING SYSTEM ═══"
input bool UseAdvancedTrailing = true;                 // Enable 3-phase trailing system
input double TrailingActivationR = 0.5;                // Start trailing at +0.5R

input group "═══ PHASE 1: Early Protection (0.5R - 1.0R) ═══"
input double Phase1EndR = 1.0;                         // Phase 1 ends at this R
input double Phase1TrailDistance = 0.3;                // Trail 0.3R behind (tight lock)

input group "═══ PHASE 2: Profit Building (1.0R - 2.0R) ═══"
input double Phase2EndR = 2.0;                         // Phase 2 ends at this R
input double Phase2TrailDistance = 0.5;                // Trail 0.5R behind (balanced)

input group "═══ PHASE 3: Let Winners Run (2.0R+) ═══"
input double Phase3TrailDistance = 0.8;                // Trail 0.8R behind (loose)

// --- Performance Export ---
input string ExportFolder = "CSM_Data";                // Folder for performance data export
input int TradeHistoryCheckIntervalSeconds = 5;        // Check for closed trades every X seconds (real-time detection)
input int PositionExportIntervalSeconds = 5;           // Export positions.txt every X seconds (real-time for monitor)
input int PerformanceExportIntervalSeconds = 300;      // Export performance.txt every X seconds (5 min)

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
datetime lastPositionExport = 0;
datetime lastPerformanceExport = 0;

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
   Print("Position Export: Every ", PositionExportIntervalSeconds, " seconds (REAL-TIME for monitor)");
   Print("Performance Export: Every ", PerformanceExportIntervalSeconds, " seconds");
   Print("========================================");

   // Initialize modules
   signalReader = new SignalReader(SignalFolder, VerboseLogging);
   tradeExecutor = new TradeExecutor(RiskPercent, MinConfidence, MaxSpreadPips, MagicNumber, VerboseLogging,
                                     SpreadMultiplierEURUSD, SpreadMultiplierGBPUSD,
                                     SpreadMultiplierAUDJPY, SpreadMultiplierUSDJPY, SpreadMultiplierUSDCHF);
   positionManager = new PositionManager(MagicNumber,
                                         UseAdvancedTrailing,
                                         TrailingActivationR,
                                         Phase1EndR, Phase1TrailDistance,
                                         Phase2EndR, Phase2TrailDistance,
                                         Phase3TrailDistance,
                                         VerboseLogging);
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

   // ✅ NEW: Export positions.txt in REAL-TIME (every 5 seconds for CSMMonitor)
   if(currentTime - lastPositionExport >= PositionExportIntervalSeconds)
   {
      lastPositionExport = currentTime;

      if(performanceTracker != NULL)
         performanceTracker.ExportOpenPositions();  // Real-time position updates
   }

   // Export performance stats periodically (5 minutes - less frequently)
   if(currentTime - lastPerformanceExport >= PerformanceExportIntervalSeconds)
   {
      lastPerformanceExport = currentTime;

      if(performanceTracker != NULL)
      {
         performanceTracker.ExportTradeHistory();      // Update trade history
         performanceTracker.ExportPerformanceStats();  // Update performance.txt
      }
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

         // ✅ SESSION 16: Register position for 3-phase trailing
         if(PositionSelectByTicket(ticket))
         {
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double sl = PositionGetDouble(POSITION_SL);

            // Calculate SL distance in price units
            double slDistance = MathAbs(entryPrice - sl);

            // Register with position manager
            bool registered = positionManager.RegisterPosition(
               ticket,
               signal.symbol,
               signal.strategy,
               signal.signal,
               entryPrice,
               slDistance
            );

            if(registered && VerboseLogging)
            {
               Print("📊 Position Registered for 3-Phase Trailing: #", ticket,
                     " | Strategy: ", signal.strategy,
                     " | Entry: ", entryPrice,
                     " | SL Distance: ", slDistance);
            }
         }
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
