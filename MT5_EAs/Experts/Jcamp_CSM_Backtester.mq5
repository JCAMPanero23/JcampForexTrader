//+------------------------------------------------------------------+
//|                                      Jcamp_CSM_Backtester.mq5    |
//|                                            JcampForexTrader       |
//|                                                                   |
//| PURPOSE: CSM Alpha Strategy Validation via MT5 Strategy Tester   |
//| - Single-symbol backtest (run separately for each asset)         |
//| - Embedded CSM calculation (9 currencies including Gold)         |
//| - Modular architecture using proven components                   |
//| - Optimization ready (OnTester returns Profit Factor)            |
//|                                                                   |
//| USAGE:                                                            |
//| 1. Attach to M15 chart: EURUSD, GBPUSD, AUDJPY, USDJPY, USDCHF  |
//| 2. Run Strategy Tester (Ctrl+R)                                  |
//| 3. Set date range (e.g., 1 year: 2024.01.01 - 2025.01.01)       |
//| 4. Enable "Every tick" mode for accuracy                         |
//| 5. Run backtest and analyze results                              |
//|                                                                   |
//| NOTE: 5-Asset System (Session 19) - Focus on 5 forex pairs      |
//|       CSM still tracks 9 currencies (including Gold as indicator)|
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "3.10"
#property description "Session 20: Smart Pending Order System Integration"
#property description "CSM Alpha Backtester - With RangeRider + Smart Pending Orders"
#property strict

//+------------------------------------------------------------------+
//| INCLUDES - Modular Components                                    |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <JcampStrategies/Indicators/EmaCalculator.mqh>
#include <JcampStrategies/Indicators/AtrCalculator.mqh>
#include <JcampStrategies/Indicators/AdxCalculator.mqh>
#include <JcampStrategies/Indicators/RsiCalculator.mqh>
#include <JcampStrategies/RegimeDetector.mqh>
#include <JcampStrategies/Strategies/TrendRiderStrategy.mqh>
#include <JcampStrategies/Strategies/RangeRiderStrategy.mqh>
#include <JcampStrategies/Trading/SmartOrderManager.mqh>  // Session 20: Smart Pending Orders
#include <JcampStrategies/Trading/PositionManager.mqh>    // Session 21: Chandelier + Profit Lock

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input group "=== Risk Management ==="
input double   RiskPercent = 1.0;           // Risk per trade (% of balance)
input int      MinConfidence = 65;          // Minimum confidence to trade (Session 19)
input double   MaxSpreadPips = 2.0;         // Max spread (pips)
input double   GoldSpreadMultiplier = 5.0;  // Gold spread multiplier

input group "=== Position Management (Session 21) ==="
input bool     UseConditionalLock = true;                // Enable 1.5R profit lock (within 4 hours)
input double   ProfitLockTriggerR = 1.5;                 // Trigger profit lock at +1.5R
input double   ProfitLockLevelR = 0.5;                   // Lock SL at +0.5R when triggered
input int      FixedSLPeriodHours = 4;                   // Fixed SL period (no trailing for X hours)

input group "=== Chandelier Trailing Stop (Session 21) ==="
input bool     UseChandelierStop = true;                 // Enable Chandelier trailing
input int      ChandelierLookback = 20;                  // Chandelier lookback bars (H1)
input double   ChandelierATRMultiplier = 2.5;            // Chandelier ATR multiplier

input group "=== Strategy Settings ==="
input int      RegimeCheckMinutes = 15;     // Regime check interval (minutes)
input bool     UseRangeRider = true;        // Enable RangeRider ✅ (Session 19)

input group "=== Smart Pending Order System (Session 20) ==="
input bool     UseSmartPending = true;                    // Enable Smart Pending Orders
input int      RetracementTriggerPips = 3;                // Retracement entry: EMA20 + X pips
input int      ExtensionThresholdPips = 15;               // Price > EMA20 + X = extended
input int      MaxRetracementPips = 30;                   // Cancel if retraces beyond this
input int      SwingLookbackBars = 20;                    // Bars to find swing high/low
input int      BreakoutTriggerPips = 1;                   // Breakout entry: Swing + X pips
input int      MaxSwingDistancePips = 30;                 // Max distance to swing
input int      RetracementExpiryHours = 4;                // Retracement order expiry
input int      BreakoutExpiryHours = 8;                   // Breakout order expiry

input group "=== Regime Detection Tuning ==="
input double   TrendingThreshold = 55.0;    // Trending classification threshold (%)
input double   RangingThreshold = 40.0;     // Ranging classification threshold (%)
input double   MinADXForTrending = 20.0;    // Min ADX for strong trend (lowered from 30)

input group "=== Debug Settings ==="
input bool     ShowChartInfo = true;        // Show CSM/Regime on chart
input bool     VerboseLogging = true;       // Enable detailed logs (CRITICAL for debugging!)

input group "=== Backtest Settings ==="
input int      MagicNumber = 999999;        // Magic number for backtest

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
CTrade trade;
string currentSymbol;
bool isGoldSymbol;

// Strategy Modules (indicators and regime are functions, not classes)
TrendRiderStrategy* trendRider;
RangeRiderStrategy* rangeRider;
SmartOrderManager*  smartOrderManager;  // Session 20: Smart pending orders
PositionManager*    positionManager;    // Session 21: Chandelier + Profit Lock

// Current regime (cached from DetectMarketRegime function)
MARKET_REGIME currentRegime;

// CSM Data (9 currencies)
double csmStrengths[9];
string csmNames[9] = {"USD", "EUR", "GBP", "JPY", "CHF", "AUD", "CAD", "NZD", "XAU"};

// Currency pair indices for CSM lookup
int usdIdx = 0, eurIdx = 1, gbpIdx = 2, jpyIdx = 3;
int chfIdx = 4, audIdx = 5, cadIdx = 6, nzdIdx = 7, xauIdx = 8;

// Performance Tracking
int totalTrades = 0;
int winningTrades = 0;
int losingTrades = 0;
double totalProfit = 0;
double totalLoss = 0;
double maxDrawdown = 0;
double peakBalance = 0;

// Timing
datetime lastRegimeCheck = 0;
datetime lastTradeTime = 0;

// Bar tracking for M15/H1 optimization (matches live system)
datetime lastM15Bar = 0;
datetime lastH1Bar = 0;

// Last signal data (for chart display)
int lastSignal = 0;
int lastConfidence = 0;
string lastStrategy = "";
string lastRegimeStr = "";

// Debug tracking
datetime lastDebugPrint = 0;
int tickCounter = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("========================================");
   Print("🚀 CSM BACKTESTER INITIALIZING");
   Print("========================================");

   currentSymbol = _Symbol;

   // Check if this is a Gold symbol
   isGoldSymbol = (StringFind(currentSymbol, "XAU") >= 0 || StringFind(currentSymbol, "GOLD") >= 0);

   Print("Symbol: ", currentSymbol);
   Print("Is Gold: ", (isGoldSymbol ? "YES (TrendRider only)" : "NO (Both strategies)"));
   Print("Risk: ", RiskPercent, "%");
   Print("Min Confidence: ", MinConfidence);
   Print("Max Spread: ", MaxSpreadPips, " pips", (isGoldSymbol ? " (x" + DoubleToString(GoldSpreadMultiplier, 1) + " for Gold)" : ""));
   Print("Session 21: Profit Lock @ +", ProfitLockTriggerR, "R → Lock @ +", ProfitLockLevelR, "R | Fixed SL: ", FixedSLPeriodHours, "h");
   Print("Session 21: Chandelier Stop: ", (UseChandelierStop ? "ENABLED" : "DISABLED"), " | Lookback: ", ChandelierLookback, " | ATR Mult: ", ChandelierATRMultiplier);

   // Initialize trade manager
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(currentSymbol);
   trade.SetDeviationInPoints(10);

   // Initialize strategies (indicators and regime are functions, not classes)
   trendRider = new TrendRiderStrategy(MinConfidence, 15.0, VerboseLogging);

   if(!isGoldSymbol && UseRangeRider)
   {
      rangeRider = new RangeRiderStrategy(MinConfidence, VerboseLogging);
      Print("RangeRider: ENABLED (requires range detection)");
   }
   else
   {
      Print("RangeRider: DISABLED (TrendRider only mode)");
   }

   // Initialize regime to TRANSITIONAL
   currentRegime = REGIME_TRANSITIONAL;

   // Session 20: Initialize Smart Order Manager
   smartOrderManager = new SmartOrderManager(MagicNumber,
                                             VerboseLogging,
                                             RetracementTriggerPips,
                                             ExtensionThresholdPips,
                                             MaxRetracementPips,
                                             SwingLookbackBars,
                                             BreakoutTriggerPips,
                                             MaxSwingDistancePips,
                                             RetracementExpiryHours,
                                             BreakoutExpiryHours);

   // Session 21: Initialize Position Manager (Chandelier + Profit Lock)
   positionManager = new PositionManager(MagicNumber,
                                         UseConditionalLock,
                                         ProfitLockTriggerR,
                                         ProfitLockLevelR,
                                         FixedSLPeriodHours,
                                         UseChandelierStop,
                                         ChandelierLookback,
                                         ChandelierATRMultiplier,
                                         VerboseLogging);

   Print("✅ All modules initialized successfully");
   if(UseSmartPending)
      Print("✅ Smart Pending Order System is ACTIVE");
   Print("========================================");
   Print("🎯 BACKTEST READY");
   Print("========================================");

   peakBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clear chart display objects
   ClearChartDisplay();

   Print("========================================");
   Print("📊 BACKTEST RESULTS SUMMARY");
   Print("========================================");
   Print("Total Trades: ", totalTrades);
   Print("Winners: ", winningTrades, " (", (totalTrades > 0 ? winningTrades * 100.0 / totalTrades : 0), "%)");
   Print("Losers: ", losingTrades, " (", (totalTrades > 0 ? losingTrades * 100.0 / totalTrades : 0), "%)");
   Print("Total Profit: $", DoubleToString(totalProfit, 2));
   Print("Total Loss: $", DoubleToString(totalLoss, 2));
   Print("Net Profit: $", DoubleToString(totalProfit - totalLoss, 2));
   Print("Profit Factor: ", (totalLoss > 0 ? DoubleToString(totalProfit / totalLoss, 2) : "N/A"));
   Print("Max Drawdown: $", DoubleToString(maxDrawdown, 2));
   Print("========================================");

   // Cleanup strategies only (indicators and regime are functions, not classes)
   if(trendRider != NULL) delete trendRider;
   if(rangeRider != NULL && !isGoldSymbol) delete rangeRider;
   if(smartOrderManager != NULL) delete smartOrderManager;  // Session 20
}

//+------------------------------------------------------------------+
//| Helper: Detect New Bar (M15 or H1)                              |
//+------------------------------------------------------------------+
bool isNewBar(ENUM_TIMEFRAMES tf)
{
   datetime currentBar = iTime(_Symbol, tf, 0);

   if(tf == PERIOD_M15 && currentBar != lastM15Bar)
   {
      lastM15Bar = currentBar;
      return true;
   }

   if(tf == PERIOD_H1 && currentBar != lastH1Bar)
   {
      lastH1Bar = currentBar;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//| OPTIMIZED: M15 signal evaluation + H1 CSM calculation           |
//+------------------------------------------------------------------+
void OnTick()
{
   // Session 20: Update pending orders (check cancellation conditions)
   if(smartOrderManager != NULL)
      smartOrderManager.UpdatePendingOrders();

   tickCounter++;

   // Periodic status update (every 1 hour of backtest time)
   if(VerboseLogging && (TimeCurrent() - lastDebugPrint >= 3600))
   {
      Print("========================================");
      Print("⏰ HOURLY STATUS UPDATE");
      Print("Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
      Print("Regime: ", lastRegimeStr, " (checked every ", RegimeCheckMinutes, " min)");
      Print("Trades: ", totalTrades, " | PF: ", (totalLoss > 0 ? DoubleToString(totalProfit/totalLoss, 2) : "N/A"));
      Print("Ticks processed: ", tickCounter);
      Print("========================================");
      lastDebugPrint = TimeCurrent();
   }

   //═══════════════════════════════════════════════════════════════
   // STEP 1: Check for M15 new bar (matches live system frequency)
   //═══════════════════════════════════════════════════════════════
   if(isNewBar(PERIOD_M15))
   {
      //────────────────────────────────────────────────────────────
      // STEP 2: Update CSM only on H1 bar close (expensive operation)
      //────────────────────────────────────────────────────────────
      if(isNewBar(PERIOD_H1))
      {
         CalculateCSM();  // 9 currencies + synthetic Gold pairs

         if(VerboseLogging)
            Print("📊 CSM Updated (H1 bar close)");
      }

      //────────────────────────────────────────────────────────────
      // STEP 3: Update regime check (every RegimeCheckMinutes)
      //────────────────────────────────────────────────────────────
      if(TimeCurrent() - lastRegimeCheck >= RegimeCheckMinutes * 60)
      {
         currentRegime = DetectMarketRegime(currentSymbol, TrendingThreshold, RangingThreshold, MinADXForTrending, VerboseLogging);
         lastRegimeCheck = TimeCurrent();

         lastRegimeStr = (currentRegime == REGIME_TRENDING) ? "TRENDING" :
                         (currentRegime == REGIME_RANGING) ? "RANGING" : "TRANSITIONAL";

         if(VerboseLogging)
         {
            Print("========================================");
            Print("🔍 Regime Detection: ", lastRegimeStr);
            Print("Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
            Print("========================================");
         }
      }

      //────────────────────────────────────────────────────────────
      // STEP 4: Evaluate strategies every M15 bar (matches live system)
      //────────────────────────────────────────────────────────────
      bool hasPosition = HasOpenPosition();

      if(!hasPosition)
      {
         // Look for new trade opportunity
         EvaluateAndTrade();
      }
   }

   //═══════════════════════════════════════════════════════════════
   // STEP 5: Manage open positions on every tick (precise execution)
   //═══════════════════════════════════════════════════════════════
   // Session 21: Auto-register any unregistered positions (for pending order executions)
   static ulong lastRegisteredTicket = 0;
   if(HasOpenPosition())
   {
      if(PositionSelect(currentSymbol))
      {
         ulong ticket = PositionGetInteger(POSITION_TICKET);

         // If this is a new position (different ticket), register it
         if(ticket != lastRegisteredTicket)
         {
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            double slDistance = MathAbs(entryPrice - currentSL);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            int signal = (posType == POSITION_TYPE_BUY) ? 1 : -1;

            // Extract strategy from comment (format: "BT|STRATEGY|CXX")
            string comment = PositionGetString(POSITION_COMMENT);
            string strategy = "UNKNOWN";
            if(StringFind(comment, "|") >= 0)
            {
               string parts[];
               StringSplit(comment, '|', parts);
               if(ArraySize(parts) >= 2)
                  strategy = parts[1];
            }

            bool registered = positionManager.RegisterPosition(ticket, currentSymbol, strategy, signal, entryPrice, slDistance);
            if(registered)
            {
               Print("🔧 Auto-Registered Position: #", ticket, " | ", strategy, " | Entry: ", entryPrice, " | SL Dist: ", slDistance);
               lastRegisteredTicket = ticket;
            }
         }
      }
   }
   else
   {
      lastRegisteredTicket = 0; // Reset when no position
   }

   // Session 21: Update positions (Chandelier + Profit Lock)
   static int updateCallCount = 0;
   if(positionManager != NULL)
   {
      updateCallCount++;
      positionManager.UpdatePositions();  // Tick-level precision for trailing

      // Debug: Log every 100 calls if we have a position
      if(HasOpenPosition() && (updateCallCount % 100 == 0))
      {
         Print("🔄 UpdatePositions() called ", updateCallCount, " times | Open Positions: ", PositionsTotal());
      }
   }

   //═══════════════════════════════════════════════════════════════
   // STEP 6: Update chart display
   //═══════════════════════════════════════════════════════════════
   UpdateChartDisplay();
}


//+------------------------------------------------------------------+
//| Calculate CSM for 9 Currencies                                   |
//| Based on CSM_AnalysisEA.mq5 competitive scoring logic           |
//+------------------------------------------------------------------+
void CalculateCSM()
{
   // Define the 8 major pairs + 4 synthetic Gold pairs (13 total)
   string pairs[] = {
      "EURUSD", "GBPUSD", "AUDUSD", "NZDUSD", "USDCAD", "USDCHF", "USDJPY",  // 7 USD pairs
      "EURGBP", "EURJPY", "GBPJPY", "AUDJPY", "CADJPY", "CHFJPY"            // 6 cross pairs
   };

   // Initialize scores (0-100 competitive scale)
   for(int i = 0; i < 9; i++)
      csmStrengths[i] = 50.0;  // Start neutral

   // Score counters for competitive scoring
   int scores[9];
   int maxComparisons[9];
   for(int i = 0; i < 9; i++)
   {
      scores[i] = 0;
      maxComparisons[i] = 0;
   }

   // Analyze 8 major forex pairs
   for(int i = 0; i < ArraySize(pairs); i++)
   {
      string pair = pairs[i];

      // Get H1 close price (current bar)
      double currentClose = iClose(pair, PERIOD_H1, 0);
      double previousClose = iClose(pair, PERIOD_H1, 1);

      if(currentClose == 0 || previousClose == 0)
         continue;

      // Determine base and quote currencies
      string baseCcy = StringSubstr(pair, 0, 3);
      string quoteCcy = StringSubstr(pair, 3, 3);

      int baseIdx = GetCurrencyIndex(baseCcy);
      int quoteIdx = GetCurrencyIndex(quoteCcy);

      if(baseIdx < 0 || quoteIdx < 0)
         continue;

      // Compare: If price rising, base stronger than quote
      if(currentClose > previousClose)
      {
         scores[baseIdx]++;  // Base wins
      }
      else if(currentClose < previousClose)
      {
         scores[quoteIdx]++; // Quote wins
      }

      // Track comparisons
      maxComparisons[baseIdx]++;
      maxComparisons[quoteIdx]++;
   }

   // Calculate synthetic Gold pairs and add to scoring
   // XAUUSD (if available on broker)
   double xauusd = iClose("XAUUSD", PERIOD_H1, 0);
   double xauusd_prev = iClose("XAUUSD", PERIOD_H1, 1);

   if(xauusd > 0 && xauusd_prev > 0)
   {
      // XAUEUR = XAUUSD / EURUSD
      double eurusd = iClose("EURUSD", PERIOD_H1, 0);
      double eurusd_prev = iClose("EURUSD", PERIOD_H1, 1);

      if(eurusd > 0 && eurusd_prev > 0)
      {
         double xaueur = xauusd / eurusd;
         double xaueur_prev = xauusd_prev / eurusd_prev;

         if(xaueur > xaueur_prev)
            scores[xauIdx]++;  // Gold stronger than EUR
         else
            scores[eurIdx]++;

         maxComparisons[xauIdx]++;
         maxComparisons[eurIdx]++;
      }

      // XAUJPY = XAUUSD * USDJPY
      double usdjpy = iClose("USDJPY", PERIOD_H1, 0);
      double usdjpy_prev = iClose("USDJPY", PERIOD_H1, 1);

      if(usdjpy > 0 && usdjpy_prev > 0)
      {
         double xaujpy = xauusd * usdjpy;
         double xaujpy_prev = xauusd_prev * usdjpy_prev;

         if(xaujpy > xaujpy_prev)
            scores[xauIdx]++;  // Gold stronger than JPY
         else
            scores[jpyIdx]++;

         maxComparisons[xauIdx]++;
         maxComparisons[jpyIdx]++;
      }

      // XAUGBP = XAUUSD / GBPUSD
      double gbpusd = iClose("GBPUSD", PERIOD_H1, 0);
      double gbpusd_prev = iClose("GBPUSD", PERIOD_H1, 1);

      if(gbpusd > 0 && gbpusd_prev > 0)
      {
         double xaugbp = xauusd / gbpusd;
         double xaugbp_prev = xauusd_prev / gbpusd_prev;

         if(xaugbp > xaugbp_prev)
            scores[xauIdx]++;  // Gold stronger than GBP
         else
            scores[gbpIdx]++;

         maxComparisons[xauIdx]++;
         maxComparisons[gbpIdx]++;
      }

      // XAUAUD = XAUUSD / AUDUSD
      double audusd = iClose("AUDUSD", PERIOD_H1, 0);
      double audusd_prev = iClose("AUDUSD", PERIOD_H1, 1);

      if(audusd > 0 && audusd_prev > 0)
      {
         double xauaud = xauusd / audusd;
         double xauaud_prev = xauusd_prev / audusd_prev;

         if(xauaud > xauaud_prev)
            scores[xauIdx]++;  // Gold stronger than AUD
         else
            scores[audIdx]++;

         maxComparisons[xauIdx]++;
         maxComparisons[audIdx]++;
      }
   }

   // Convert scores to 0-100 scale (competitive percentile)
   for(int i = 0; i < 9; i++)
   {
      if(maxComparisons[i] > 0)
         csmStrengths[i] = (scores[i] * 100.0) / maxComparisons[i];
      else
         csmStrengths[i] = 50.0;  // Neutral if no data
   }

   // CSM logging is done in EvaluateAndTrade() to avoid log spam
}

//+------------------------------------------------------------------+
//| Get Currency Index in CSM Array                                  |
//+------------------------------------------------------------------+
int GetCurrencyIndex(string currency)
{
   for(int i = 0; i < 9; i++)
   {
      if(csmNames[i] == currency)
         return i;
   }
   return -1;  // Not found
}

//+------------------------------------------------------------------+
//| Get CSM Strength for Current Pair                                |
//| Returns: base strength, quote strength                           |
//+------------------------------------------------------------------+
void GetCSMForPair(double &baseStrength, double &quoteStrength)
{
   string baseCcy = "";
   string quoteCcy = "";

   // Parse current symbol
   if(StringFind(currentSymbol, "XAU") >= 0)
   {
      // Gold pair (XAUUSD, XAUUSD.r, etc.)
      baseCcy = "XAU";
      quoteCcy = "USD";
   }
   else if(StringLen(currentSymbol) >= 6)
   {
      baseCcy = StringSubstr(currentSymbol, 0, 3);
      quoteCcy = StringSubstr(currentSymbol, 3, 3);
   }

   int baseIdx = GetCurrencyIndex(baseCcy);
   int quoteIdx = GetCurrencyIndex(quoteCcy);

   baseStrength = (baseIdx >= 0) ? csmStrengths[baseIdx] : 50.0;
   quoteStrength = (quoteIdx >= 0) ? csmStrengths[quoteIdx] : 50.0;
}

//+------------------------------------------------------------------+
//| Evaluate Strategies and Execute Trade if Signal Found           |
//+------------------------------------------------------------------+
void EvaluateAndTrade()
{
   // Get CSM for current pair
   double baseStrength = 0, quoteStrength = 0;
   GetCSMForPair(baseStrength, quoteStrength);

   // Calculate CSM difference
   double csmDiff = baseStrength - quoteStrength;

   if(VerboseLogging)
   {
      Print("💹 CSM for ", currentSymbol, ": Base=", DoubleToString(baseStrength, 1),
            " Quote=", DoubleToString(quoteStrength, 1), " Diff=", DoubleToString(csmDiff, 1));
   }

   // Prepare signal result
   StrategySignal result;
   result.signal = 0;
   result.confidence = 0;
   result.analysis = "";
   result.strategyName = "";
   result.stopLossDollars = 0;
   result.takeProfitDollars = 0;

   bool analyzed = false;
   string strategyUsed = "NONE";

   if(isGoldSymbol)
   {
      // Gold: TrendRider only
      if(currentRegime == REGIME_TRENDING)
      {
         strategyUsed = "TrendRider (Gold)";
         analyzed = trendRider.Analyze(currentSymbol, PERIOD_H1, csmDiff, result);
      }
      else
      {
         if(VerboseLogging)
            Print("⏭️  Gold skipped - Regime not TRENDING (", lastRegimeStr, ")");
      }
   }
   else
   {
      // Other pairs: TrendRider or RangeRider based on regime
      if(UseRangeRider && currentRegime == REGIME_RANGING)
      {
         // RangeRider (requires range detection - currently disabled)
         strategyUsed = "RangeRider";
         analyzed = rangeRider.Analyze(currentSymbol, PERIOD_H1, csmDiff, result);
      }
      else if(currentRegime == REGIME_TRENDING)
      {
         // TrendRider for trending markets
         strategyUsed = "TrendRider";
         analyzed = trendRider.Analyze(currentSymbol, PERIOD_H1, csmDiff, result);
      }
      else
      {
         if(VerboseLogging)
            Print("⏭️  Skipped - Regime: ", lastRegimeStr, " (not suitable for trading)");
      }
   }

   if(VerboseLogging && analyzed)
   {
      Print("📊 Strategy: ", strategyUsed, " | Signal: ", (result.signal > 0 ? "BUY" : (result.signal < 0 ? "SELL" : "NEUTRAL")),
            " | Confidence: ", result.confidence, " | Analysis: ", result.analysis);
   }

   // Store last signal for chart display
   lastSignal = result.signal;
   lastConfidence = result.confidence;
   lastStrategy = result.strategyName;

   // Check if strategy returned valid signal
   if(!analyzed)
   {
      if(VerboseLogging)
         Print("❌ No strategy analyzed (regime: ", lastRegimeStr, ")");
      return;
   }

   if(result.signal == 0)
   {
      if(VerboseLogging)
         Print("⚪ Neutral signal - no trade");
      return;
   }

   if(result.confidence < MinConfidence)
   {
      if(VerboseLogging)
         Print("❌ Confidence too low: ", result.confidence, " < ", MinConfidence);
      return;
   }

   // Check spread
   if(!CheckSpread())
   {
      if(VerboseLogging)
      {
         double spread = SymbolInfoInteger(currentSymbol, SYMBOL_SPREAD) * SymbolInfoDouble(currentSymbol, SYMBOL_POINT);
         double spreadPips = spread / SymbolInfoDouble(currentSymbol, SYMBOL_POINT) / 10.0;
         Print("⚠️ Spread too high: ", DoubleToString(spreadPips, 1), " pips");
      }
      return;
   }

   // Prevent rapid-fire trades (min 1 hour between trades)
   if(TimeCurrent() - lastTradeTime < 3600)
   {
      if(VerboseLogging)
         Print("⏰ Trade throttle - last trade was ", (TimeCurrent() - lastTradeTime) / 60, " min ago");
      return;
   }

   // Execute trade
   if(VerboseLogging)
      Print("✅ All checks passed - executing trade!");

   ExecuteTrade(result.signal, result.confidence, result.strategyName);
}

//+------------------------------------------------------------------+
//| Execute Trade (Session 20: Smart Pending Order Integration)      |
//+------------------------------------------------------------------+
void ExecuteTrade(int signal, int confidence, string strategy)
{
   ENUM_ORDER_TYPE orderType = (signal > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   double price = (orderType == ORDER_TYPE_BUY) ?
                  SymbolInfoDouble(currentSymbol, SYMBOL_ASK) :
                  SymbolInfoDouble(currentSymbol, SYMBOL_BID);

   // Calculate position size
   double lots = CalculatePositionSize();
   if(lots <= 0)
   {
      Print("ERROR: Invalid lot size");
      return;
   }

   // Calculate SL/TP
   double sl = CalculateStopLoss(orderType, price);
   double tp = CalculateTakeProfit(orderType, price);

   ulong ticket = 0;
   bool pendingOrderPlaced = false;

   // SESSION 20: Try smart pending order first (if enabled)
   if(UseSmartPending && smartOrderManager != NULL)
   {
      // Create SignalData structure for SmartOrderManager
      SignalData signalData;
      signalData.symbol = currentSymbol;
      signalData.signal = signal;
      signalData.confidence = confidence;
      signalData.strategy = strategy;
      signalData.isValid = true;

      // Calculate SL/TP distances for pending orders
      double slDistance = MathAbs(price - sl);
      double tpDistance = MathAbs(tp - price);

      signalData.stopLossDollars = slDistance;
      signalData.takeProfitDollars = tpDistance;

      // Try to place smart pending order
      ticket = smartOrderManager.PlaceSmartPendingOrder(signalData, lots);

      if(ticket > 0)
      {
         pendingOrderPlaced = true;
         Print("✅ Smart pending order placed: Ticket #", ticket);
      }
      else if(ticket == ULONG_MAX)
      {
         // Skip entirely (position or pending exists)
         if(VerboseLogging)
            Print("⏭️  Skipping signal - position or pending order exists");
         return; // Exit function, don't execute market order
      }
      else // ticket == 0
      {
         if(VerboseLogging)
            Print("Smart pending returned 0 -> Using market order (fallback)");
      }
   }

   // If pending order not placed (disabled or returned 0), use market order
   if(!pendingOrderPlaced)
   {
      // Build comment
      string comment = "BT|" + strategy + "|C" + IntegerToString(confidence);

      // Execute market order
      bool success = false;
      if(orderType == ORDER_TYPE_BUY)
         success = trade.Buy(lots, currentSymbol, price, sl, tp, comment);
      else
         success = trade.Sell(lots, currentSymbol, price, sl, tp, comment);

      if(success)
      {
         Print("✅ Market Trade Executed: ", EnumToString(orderType),
               " | Lots: ", lots,
               " | Price: ", price,
               " | SL: ", sl,
               " | TP: ", tp,
               " | Confidence: ", confidence,
               " | Strategy: ", strategy);

         lastTradeTime = TimeCurrent();

         // Session 21: Register position with PositionManager for trailing
         // Select the position that was just opened (by symbol and magic)
         if(PositionSelect(currentSymbol))
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            double slDistance = MathAbs(entryPrice - currentSL);
            int signal = (orderType == ORDER_TYPE_BUY) ? 1 : -1;

            bool registered = positionManager.RegisterPosition(ticket, currentSymbol, strategy, signal, entryPrice, slDistance);

            if(registered)
            {
               Print("📊 Position Registered: #", ticket, " | ", strategy, " | Entry: ", entryPrice, " | SL Dist: ", slDistance);
            }
            else
            {
               Print("⚠️ Position Registration FAILED: #", ticket);
            }
         }
         else
         {
            Print("⚠️ Could not select position after trade execution!");
         }
      }
      else
      {
         Print("ERROR: Trade failed - ", trade.ResultRetcodeDescription());
      }
   }
   else
   {
      // Pending order placed successfully
      Print("📋 Pending order placed successfully: Ticket #", ticket);
      lastTradeTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Calculate Position Size Based on Risk%                           |
//+------------------------------------------------------------------+
double CalculatePositionSize()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (RiskPercent / 100.0);

   // Calculate SL distance
   double slDistance = 0;
   if(isGoldSymbol)
      slDistance = 50.0;  // Gold: $50 SL
   else
   {
      double point = SymbolInfoDouble(currentSymbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(currentSymbol, SYMBOL_DIGITS);
      double pipSize = (digits == 3 || digits == 5) ? point * 10.0 : point;
      slDistance = 50.0 * pipSize;  // Forex: 50 pips
   }

   // Calculate lots
   double tickValue = SymbolInfoDouble(currentSymbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(currentSymbol, SYMBOL_TRADE_TICK_SIZE);
   double lots = riskAmount / (slDistance / tickSize * tickValue);

   // Round to lot step
   double lotStep = SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_STEP);
   lots = MathFloor(lots / lotStep) * lotStep;

   // Validate
   double minLot = SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_MAX);

   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;

   return lots;
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss                                              |
//+------------------------------------------------------------------+
double CalculateStopLoss(ENUM_ORDER_TYPE orderType, double entryPrice)
{
   double slDistance = 0;

   if(isGoldSymbol)
      slDistance = 50.0;  // Gold: $50
   else
   {
      double point = SymbolInfoDouble(currentSymbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(currentSymbol, SYMBOL_DIGITS);
      double pipSize = (digits == 3 || digits == 5) ? point * 10.0 : point;
      slDistance = 50.0 * pipSize;  // Forex: 50 pips
   }

   if(orderType == ORDER_TYPE_BUY)
      return entryPrice - slDistance;
   else
      return entryPrice + slDistance;
}

//+------------------------------------------------------------------+
//| Calculate Take Profit (2x SL)                                    |
//+------------------------------------------------------------------+
double CalculateTakeProfit(ENUM_ORDER_TYPE orderType, double entryPrice)
{
   double tpDistance = 0;

   if(isGoldSymbol)
      tpDistance = 100.0;  // Gold: $100 (2x SL)
   else
   {
      double point = SymbolInfoDouble(currentSymbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(currentSymbol, SYMBOL_DIGITS);
      double pipSize = (digits == 3 || digits == 5) ? point * 10.0 : point;
      tpDistance = 100.0 * pipSize;  // Forex: 100 pips (2x SL)
   }

   if(orderType == ORDER_TYPE_BUY)
      return entryPrice + tpDistance;
   else
      return entryPrice - tpDistance;
}

//+------------------------------------------------------------------+
//| Check if Spread is Acceptable                                    |
//+------------------------------------------------------------------+
bool CheckSpread()
{
   double spread = SymbolInfoInteger(currentSymbol, SYMBOL_SPREAD) * SymbolInfoDouble(currentSymbol, SYMBOL_POINT);
   double spreadPips = spread / SymbolInfoDouble(currentSymbol, SYMBOL_POINT) / 10.0;

   double maxSpread = MaxSpreadPips;
   if(isGoldSymbol)
      maxSpread *= GoldSpreadMultiplier;

   return (spreadPips <= maxSpread);
}

//+------------------------------------------------------------------+
//| Check if We Have Open Position                                   |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
         PositionGetString(POSITION_SYMBOL) == currentSymbol)
      {
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Update Chart Display (Top Left Corner)                          |
//+------------------------------------------------------------------+
void UpdateChartDisplay()
{
   if(!ShowChartInfo)
      return;

   int y_offset = 20;
   int line_height = 18;
   int x_pos = 10;

   // CSM Display
   string csmText = StringFormat("CSM: USD=%.1f EUR=%.1f GBP=%.1f JPY=%.1f XAU=%.1f",
                                 csmStrengths[0], csmStrengths[1], csmStrengths[2],
                                 csmStrengths[3], csmStrengths[8]);
   CreateLabel("CSM_Display", csmText, x_pos, y_offset, clrWhite, 9);
   y_offset += line_height;

   // Regime Display
   color regimeColor = (currentRegime == REGIME_TRENDING) ? clrLime :
                       (currentRegime == REGIME_RANGING) ? clrYellow : clrOrange;
   CreateLabel("Regime_Display", "Regime: " + lastRegimeStr, x_pos, y_offset, regimeColor, 9);
   y_offset += line_height;

   // Last Signal Display
   if(lastConfidence > 0)
   {
      string signalText = StringFormat("Signal: %s | Confidence: %d | Strategy: %s",
                                      (lastSignal > 0 ? "BUY" : (lastSignal < 0 ? "SELL" : "NEUTRAL")),
                                      lastConfidence, lastStrategy);
      color signalColor = (lastSignal > 0) ? clrLime : (lastSignal < 0) ? clrRed : clrGray;
      CreateLabel("Signal_Display", signalText, x_pos, y_offset, signalColor, 9);
   }
   else
   {
      CreateLabel("Signal_Display", "Signal: WAITING...", x_pos, y_offset, clrGray, 9);
   }
   y_offset += line_height;

   // Trades Display
   string tradesText = StringFormat("Trades: %d | Winners: %d | PF: %s",
                                   totalTrades, winningTrades,
                                   (totalLoss > 0 ? DoubleToString(totalProfit / totalLoss, 2) : "N/A"));
   CreateLabel("Trades_Display", tradesText, x_pos, y_offset, clrCyan, 9);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Create or Update Label on Chart                                 |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int fontSize)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   }

   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
//| Clear Chart Display Objects                                     |
//+------------------------------------------------------------------+
void ClearChartDisplay()
{
   ObjectDelete(0, "CSM_Display");
   ObjectDelete(0, "Regime_Display");
   ObjectDelete(0, "Signal_Display");
   ObjectDelete(0, "Trades_Display");
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| OnTester - Return Performance Metric for Optimization           |
//+------------------------------------------------------------------+
double OnTester()
{
   // Get backtest statistics
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double initialBalance = TesterStatistics(STAT_INITIAL_DEPOSIT);

   // Calculate metrics
   double netProfit = balance - initialBalance;
   double profitFactor = (totalLoss > 0) ? (totalProfit / totalLoss) : 0;

   // Return Profit Factor for optimization
   // MT5 will maximize this value during optimization
   return profitFactor;
}
//+------------------------------------------------------------------+
