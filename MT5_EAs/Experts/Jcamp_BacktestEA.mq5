//+------------------------------------------------------------------+
//|                                           Jcamp_BacktestEA.mq5   |
//|                                            JcampForexTrader       |
//|                                                                   |
//| PURPOSE: Strategy validation via MT5 Strategy Tester             |
//| - Single-symbol backtest (run separately for each asset)         |
//| - Embedded CSM calculation (9 currencies including Gold)         |
//| - Modular architecture using proven components                   |
//| - Optimization ready (OnTester returns Profit Factor)            |
//|                                                                   |
//| USAGE:                                                            |
//| 1. Attach to chart: EURUSD, GBPUSD, AUDJPY, or XAUUSD           |
//| 2. Run Strategy Tester (Ctrl+R)                                  |
//| 3. Set date range (e.g., 1 year: 2024.01.01 - 2025.01.01)       |
//| 4. Enable "Every tick" mode for accuracy                         |
//| 5. Run backtest and analyze results                              |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "1.00"
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

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input group "=== Risk Management ==="
input double   RiskPercent = 1.0;           // Risk per trade (% of balance)
input int      MinConfidence = 70;          // Minimum confidence to trade
input double   MaxSpreadPips = 2.0;         // Max spread (pips)
input double   GoldSpreadMultiplier = 5.0;  // Gold spread multiplier

input group "=== Position Management ==="
input bool     EnableTrailing = true;       // Enable trailing stop
input int      TrailingStopPips = 20;       // Trailing stop distance (pips)
input int      TrailingStartPips = 30;      // Start trailing after profit (pips)

input group "=== Strategy Settings ==="
input int      RegimeCheckMinutes = 15;     // Regime check interval (minutes)
input bool     VerboseLogging = false;      // Enable detailed logs

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

// Trailing Stop Tracking
double trailingHighWaterMark = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("========================================");
   Print("🚀 BACKTEST EA INITIALIZING");
   Print("========================================");

   currentSymbol = _Symbol;

   // Check if this is a Gold symbol
   isGoldSymbol = (StringFind(currentSymbol, "XAU") >= 0 || StringFind(currentSymbol, "GOLD") >= 0);

   Print("Symbol: ", currentSymbol);
   Print("Is Gold: ", (isGoldSymbol ? "YES (TrendRider only)" : "NO (Both strategies)"));
   Print("Risk: ", RiskPercent, "%");
   Print("Min Confidence: ", MinConfidence);
   Print("Max Spread: ", MaxSpreadPips, " pips", (isGoldSymbol ? " (x" + DoubleToString(GoldSpreadMultiplier, 1) + " for Gold)" : ""));
   Print("Trailing Stop: ", (EnableTrailing ? "ENABLED" : "DISABLED"));

   // Initialize trade manager
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(currentSymbol);
   trade.SetDeviationInPoints(10);

   // Initialize strategies (indicators and regime are functions, not classes)
   trendRider = new TrendRiderStrategy(MinConfidence, 15.0, VerboseLogging);

   if(!isGoldSymbol)
   {
      rangeRider = new RangeRiderStrategy(MinConfidence, 15.0, VerboseLogging);
   }

   // Initialize regime to TRANSITIONAL
   currentRegime = REGIME_TRANSITIONAL;

   Print("✅ All modules initialized successfully");
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
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check regime periodically (every RegimeCheckMinutes)
   if(TimeCurrent() - lastRegimeCheck >= RegimeCheckMinutes * 60)
   {
      currentRegime = DetectMarketRegime(currentSymbol, PERIOD_H1, VerboseLogging);
      lastRegimeCheck = TimeCurrent();

      if(VerboseLogging)
      {
         string regimeStr = (currentRegime == REGIME_TRENDING) ? "TRENDING" :
                           (currentRegime == REGIME_RANGING) ? "RANGING" : "TRANSITIONAL";
         Print("🔍 Regime: ", regimeStr);
      }
   }

   // Calculate CSM (9 currencies)
   CalculateCSM();

   // Check if we have an open position
   bool hasPosition = HasOpenPosition();

   if(hasPosition)
   {
      // Manage existing position
      ManagePosition();
   }
   else
   {
      // Look for new trade opportunity
      EvaluateAndTrade();
   }
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

   // Synthetic Gold pairs (calculated from cross-rates)
   string goldPairs[] = {"XAUEUR", "XAUJPY", "XAUGBP", "XAUAUD"};

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

   if(VerboseLogging)
   {
      Print("💹 CSM: USD=", DoubleToString(csmStrengths[0], 1),
            " EUR=", DoubleToString(csmStrengths[1], 1),
            " GBP=", DoubleToString(csmStrengths[2], 1),
            " JPY=", DoubleToString(csmStrengths[3], 1),
            " XAU=", DoubleToString(csmStrengths[8], 1));
   }
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
      // Gold pair (XAUUSD, XAUUSD.sml, etc.)
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

   // Prepare signal result
   StrategySignal result;
   result.signal = 0;
   result.confidence = 0;
   result.analysis = "";
   result.strategyName = "";
   result.stopLossDollars = 0;
   result.takeProfitDollars = 0;

   bool analyzed = false;

   if(isGoldSymbol)
   {
      // Gold: TrendRider only
      if(currentRegime == REGIME_TRENDING)
      {
         analyzed = trendRider.Analyze(currentSymbol, PERIOD_H1, csmDiff, result);
      }
   }
   else
   {
      // Other pairs: TrendRider or RangeRider based on regime
      if(currentRegime == REGIME_TRENDING)
      {
         analyzed = trendRider.Analyze(currentSymbol, PERIOD_H1, csmDiff, result);
      }
      else if(currentRegime == REGIME_RANGING)
      {
         analyzed = rangeRider.Analyze(currentSymbol, PERIOD_H1, csmDiff, result);
      }
   }

   // Check if strategy returned valid signal
   if(!analyzed || result.signal == 0 || result.confidence < MinConfidence)
      return;

   // Check spread
   if(!CheckSpread())
   {
      if(VerboseLogging)
         Print("⚠️ Spread too high, skipping trade");
      return;
   }

   // Prevent rapid-fire trades (min 1 hour between trades)
   if(TimeCurrent() - lastTradeTime < 3600)
      return;

   // Execute trade
   ExecuteTrade(result.signal, result.confidence, result.strategyName);
}

//+------------------------------------------------------------------+
//| Execute Trade                                                     |
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

   // Build comment
   string comment = "BT|" + strategy + "|C" + IntegerToString(confidence);

   // Execute order
   bool success = false;
   if(orderType == ORDER_TYPE_BUY)
      success = trade.Buy(lots, currentSymbol, price, sl, tp, comment);
   else
      success = trade.Sell(lots, currentSymbol, price, sl, tp, comment);

   if(success)
   {
      Print("✅ Trade Executed: ", EnumToString(orderType),
            " | Lots: ", lots,
            " | Price: ", price,
            " | SL: ", sl,
            " | TP: ", tp,
            " | Confidence: ", confidence,
            " | Strategy: ", strategy);

      lastTradeTime = TimeCurrent();
      trailingHighWaterMark = 0;  // Reset trailing tracker
   }
   else
   {
      Print("ERROR: Trade failed - ", trade.ResultRetcodeDescription());
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
//| Manage Open Position (Trailing Stop)                            |
//+------------------------------------------------------------------+
void ManagePosition()
{
   if(!EnableTrailing)
      return;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber ||
         PositionGetString(POSITION_SYMBOL) != currentSymbol)
         continue;

      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = (posType == POSITION_TYPE_BUY) ?
                            SymbolInfoDouble(currentSymbol, SYMBOL_BID) :
                            SymbolInfoDouble(currentSymbol, SYMBOL_ASK);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);

      // Calculate profit in pips
      double point = SymbolInfoDouble(currentSymbol, SYMBOL_POINT);
      double priceDiff = 0;
      if(posType == POSITION_TYPE_BUY)
         priceDiff = currentPrice - openPrice;
      else
         priceDiff = openPrice - currentPrice;

      double profitPips = priceDiff / (point * 10.0);

      // Only trail if profit > TrailingStartPips
      if(profitPips < TrailingStartPips)
         return;

      // Update high water mark
      if(posType == POSITION_TYPE_BUY)
      {
         if(trailingHighWaterMark == 0 || currentPrice > trailingHighWaterMark)
            trailingHighWaterMark = currentPrice;
      }
      else
      {
         if(trailingHighWaterMark == 0 || currentPrice < trailingHighWaterMark)
            trailingHighWaterMark = currentPrice;
      }

      // Calculate new trailing SL
      double pipValue = point * 10.0;
      double newSL = 0;

      if(posType == POSITION_TYPE_BUY)
      {
         newSL = trailingHighWaterMark - (TrailingStopPips * pipValue);
         if(newSL > sl || sl == 0)
         {
            newSL = NormalizeDouble(newSL, (int)SymbolInfoInteger(currentSymbol, SYMBOL_DIGITS));
            trade.PositionModify(ticket, newSL, tp);

            if(VerboseLogging)
               Print("📈 Trailing Stop Updated: SL=", newSL);
         }
      }
      else
      {
         newSL = trailingHighWaterMark + (TrailingStopPips * pipValue);
         if(newSL < sl || sl == 0)
         {
            newSL = NormalizeDouble(newSL, (int)SymbolInfoInteger(currentSymbol, SYMBOL_DIGITS));
            trade.PositionModify(ticket, newSL, tp);

            if(VerboseLogging)
               Print("📉 Trailing Stop Updated: SL=", newSL);
         }
      }
   }
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
