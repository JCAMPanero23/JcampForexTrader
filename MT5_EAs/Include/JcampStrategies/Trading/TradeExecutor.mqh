//+------------------------------------------------------------------+
//|                                           TradeExecutor.mqh       |
//|                                            JcampForexTrader       |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include "SignalReader.mqh"

//+------------------------------------------------------------------+
//| Trade Executor Class                                              |
//| Executes trades based on signals with risk management            |
//+------------------------------------------------------------------+
class TradeExecutor
{
private:
   CTrade   trade;
   double   riskPercent;          // Risk per trade (% of account balance)
   int      minConfidence;        // Minimum confidence to trade
   double   maxSpreadPips;        // Base maximum spread (pips)
   int      magic;                // Magic number for this EA
   string   tradeComment;         // Comment for trades
   bool     verboseLogging;

   // Symbol-specific spread multipliers
   struct SpreadMultiplier {
      string symbol;
      double multiplier;
   };
   SpreadMultiplier spreadMultipliers[];

   // Track last executed signals to prevent duplicates
   struct LastTrade {
      string   symbol;
      datetime timestamp;
      int      signal;
   };
   LastTrade lastTrades[];

public:
   TradeExecutor(double riskPct = 1.0,
                 int minConf = 70,
                 double maxSpread = 2.0,
                 int magicNum = 100001,
                 bool verbose = false,
                 double eurMultiplier = 1.0,
                 double gbpMultiplier = 1.0,
                 double audMultiplier = 1.0,
                 double xauMultiplier = 5.0)
   {
      riskPercent = riskPct;
      minConfidence = minConf;
      maxSpreadPips = maxSpread;
      magic = magicNum;
      tradeComment = "JcampCSM";
      verboseLogging = verbose;

      // Initialize spread multipliers for CSM Alpha symbols
      ArrayResize(spreadMultipliers, 4);
      spreadMultipliers[0].symbol = "EURUSD";  spreadMultipliers[0].multiplier = eurMultiplier;
      spreadMultipliers[1].symbol = "GBPUSD";  spreadMultipliers[1].multiplier = gbpMultiplier;
      spreadMultipliers[2].symbol = "AUDJPY";  spreadMultipliers[2].multiplier = audMultiplier;
      spreadMultipliers[3].symbol = "XAUUSD";  spreadMultipliers[3].multiplier = xauMultiplier;

      trade.SetExpertMagicNumber(magic);
      trade.SetMarginMode();
      trade.SetTypeFillingBySymbol(_Symbol);
      trade.SetDeviationInPoints(10); // 1.0 pip slippage

      ArrayResize(lastTrades, 0);
   }

   ~TradeExecutor() {}

   //+------------------------------------------------------------------+
   //| Execute Signal                                                    |
   //| Returns ticket number if successful, 0 if failed                 |
   //+------------------------------------------------------------------+
   ulong ExecuteSignal(const SignalData &signal)
   {
      // Validate signal
      if(!ValidateSignal(signal))
      {
         if(verboseLogging)
            Print("❌ Signal validation failed for ", signal.symbol);
         return 0;
      }

      // Check if we already traded this signal
      if(IsSignalAlreadyTraded(signal))
      {
         if(verboseLogging)
            Print("⏭️  Signal already traded: ", signal.symbol);
         return 0;
      }

      // Determine order type
      ENUM_ORDER_TYPE orderType = (signal.signal > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

      // Get current price
      double price = (orderType == ORDER_TYPE_BUY) ?
                     SymbolInfoDouble(signal.symbol, SYMBOL_ASK) :
                     SymbolInfoDouble(signal.symbol, SYMBOL_BID);

      // Calculate position size
      double lots = CalculatePositionSize(signal.symbol, price);
      if(lots <= 0)
      {
         Print("ERROR: Invalid position size calculated for ", signal.symbol);
         return 0;
      }

     // Use ATR-based SL/TP from signal if available (Gold strategy)
        double sl = 0, tp = 0;

        if(signal.stopLossDollars > 0 && signal.takeProfitDollars > 0)
        {
           // Use ATR-based SL/TP from signal (Gold strategy)
           if(orderType == ORDER_TYPE_BUY)
           {
              sl = price - signal.stopLossDollars;
              tp = price + signal.takeProfitDollars;
           }
           else
           {
              sl = price + signal.stopLossDollars;
              tp = price - signal.takeProfitDollars;
           }

           if(verboseLogging)
              Print("📊 Using ATR-based SL/TP: SL=$", signal.stopLossDollars, " TP=$", signal.takeProfitDollars);
        }
        else
        {
           // Use default calculation for forex pairs
           sl = CalculateStopLoss(signal.symbol, orderType, price);
           tp = CalculateTakeProfit(signal.symbol, orderType, price);
        }
        
      // Execute order
      string comment = tradeComment + "|" + signal.strategy + "|C" + IntegerToString(signal.confidence);

      bool success = false;
      if(orderType == ORDER_TYPE_BUY)
      {
         success = trade.Buy(lots, signal.symbol, price, sl, tp, comment);
      }
      else
      {
         success = trade.Sell(lots, signal.symbol, price, sl, tp, comment);
      }

      if(success)
      {
         ulong ticket = trade.ResultOrder();
         Print("✅ Trade Executed: ", signal.symbol, " ", EnumToString(orderType),
               " | Lots: ", lots, " | Entry: ", price,
               " | SL: ", sl, " | TP: ", tp,
               " | Confidence: ", signal.confidence);

         // Record this trade
         RecordTrade(signal);

         return ticket;
      }
      else
      {
         Print("ERROR: Trade failed for ", signal.symbol,
               " | Error: ", GetLastError(),
               " | ", trade.ResultRetcodeDescription());
         return 0;
      }
   }

   //+------------------------------------------------------------------+
   //| Validate Signal Before Trading                                   |
   //+------------------------------------------------------------------+
   bool ValidateSignal(const SignalData &signal)
   {
      // Check if signal is valid
      if(!signal.isValid)
      {
         if(verboseLogging)
            Print("Invalid signal data");
         return false;
      }

      // Check if signal is neutral
      if(signal.signal == 0)
      {
         if(verboseLogging)
            Print("Neutral signal, no trade");
         return false;
      }

      // Check confidence threshold
      if(signal.confidence < minConfidence)
      {
         if(verboseLogging)
            Print("Confidence too low: ", signal.confidence, " < ", minConfidence);
         return false;
      }

      // Check symbol validity
      if(!SymbolSelect(signal.symbol, true))
      {
         Print("ERROR: Symbol not found: ", signal.symbol);
         return false;
      }

      // Check spread with symbol-specific multiplier
      double spread = SymbolInfoInteger(signal.symbol, SYMBOL_SPREAD) * SymbolInfoDouble(signal.symbol, SYMBOL_POINT);
      double spreadPips = spread / SymbolInfoDouble(signal.symbol, SYMBOL_POINT) / 10.0;

      // Get multiplier for this symbol
      double multiplier = GetSpreadMultiplier(signal.symbol);
      double maxSpreadForSymbol = maxSpreadPips * multiplier;

      if(spreadPips > maxSpreadForSymbol)
      {
         if(verboseLogging)
            Print("⚠️ Spread too high for ", signal.symbol, ": ", spreadPips, " pips (max: ", maxSpreadForSymbol, " pips with ", multiplier, "x multiplier)");
         return false;
      }

      if(verboseLogging)
         Print("✓ Spread OK for ", signal.symbol, ": ", spreadPips, " pips (max: ", maxSpreadForSymbol, " pips)");

      // Check if market is open
      if(!IsMarketOpen(signal.symbol))
      {
         if(verboseLogging)
            Print("Market closed for ", signal.symbol);
         return false;
      }

      // Check account balance
      if(AccountInfoDouble(ACCOUNT_BALANCE) <= 0)
      {
         Print("ERROR: Zero account balance");
         return false;
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Get Spread Multiplier for Symbol                                 |
   //| Returns multiplier for this symbol, defaults to 1.0              |
   //+------------------------------------------------------------------+
   double GetSpreadMultiplier(string symbol)
   {
      // Remove broker suffix for matching (e.g., EURUSD.sml → EURUSD)
      string cleanSymbol = symbol;
      StringReplace(cleanSymbol, ".sml", "");
      StringReplace(cleanSymbol, ".ecn", "");
      StringReplace(cleanSymbol, ".raw", "");

      // Find matching symbol multiplier
      for(int i = 0; i < ArraySize(spreadMultipliers); i++)
      {
         if(StringFind(cleanSymbol, spreadMultipliers[i].symbol) >= 0)
            return spreadMultipliers[i].multiplier;
      }

      // Default multiplier
      return 1.0;
   }

   //+------------------------------------------------------------------+
   //| Calculate Position Size Based on Risk%                           |
   //| Risk% of account balance per trade                               |
   //+------------------------------------------------------------------+
   double CalculatePositionSize(string symbol, double entryPrice)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = balance * (riskPercent / 100.0);

      // Calculate stop loss distance (symbol-aware)
      double slDistance = 0.0;
      double slDisplay = 0.0; // For logging

      // Check if Gold (XAUUSD)
      if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
      {
         // Gold: Use $50 stop loss
         slDistance = 50.0;
         slDisplay = 50.0;
      }
      else
      {
         // Forex pairs: Use 50 pips
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
         double pipSize = (digits == 3 || digits == 5) ? point * 10.0 : point;
         slDistance = 50.0 * pipSize;
         slDisplay = 50.0;
      }

      // Calculate lot size
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

      double lots = riskAmount / (slDistance / tickSize * tickValue);

      // Round to valid lot step
      double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      lots = MathFloor(lots / lotStep) * lotStep;

      // Validate lot size
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

      if(lots < minLot) lots = minLot;
      if(lots > maxLot) lots = maxLot;

      if(verboseLogging)
      {
         Print("💰 Position Size: ", symbol,
               " | Risk: $", riskAmount,
               " | SL: ", (StringFind(symbol, "XAU") >= 0 ? "$" : ""), slDisplay, (StringFind(symbol, "XAU") >= 0 ? "" : " pips"),
               " | Lots: ", lots);
      }

      return lots;
   }

private:
   //+------------------------------------------------------------------+
   //| Calculate Stop Loss                                              |
   //| Simple version: 50 pips or ATR-based                             |
   //+------------------------------------------------------------------+
   double CalculateStopLoss(string symbol, ENUM_ORDER_TYPE orderType, double entryPrice)
   {
      // Symbol-specific SL calculation
      double slDistance = 0.0;

      // Check if Gold (XAUUSD)
      if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
      {
         // Gold: Use $50 stop loss (not pips, actual price distance)
         slDistance = 50.0;
      }
      else
      {
         // Forex pairs: Use 50 pips
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
         double pipSize = (digits == 3 || digits == 5) ? point * 10.0 : point;
         slDistance = 50.0 * pipSize;
      }

      if(orderType == ORDER_TYPE_BUY)
      {
         return entryPrice - slDistance;
      }
      else
      {
         return entryPrice + slDistance;
      }
   }

   //+------------------------------------------------------------------+
   //| Calculate Take Profit                                            |
   //| Simple version: 2x stop loss (Risk:Reward = 1:2)                |
   //+------------------------------------------------------------------+
   double CalculateTakeProfit(string symbol, ENUM_ORDER_TYPE orderType, double entryPrice)
   {
      // Symbol-specific TP calculation (2x SL)
      double tpDistance = 0.0;

      // Check if Gold (XAUUSD)
      if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
      {
         // Gold: Use $100 take profit (2x SL of $50)
         tpDistance = 100.0;
      }
      else
      {
         // Forex pairs: Use 100 pips (2x SL of 50 pips)
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
         double pipSize = (digits == 3 || digits == 5) ? point * 10.0 : point;
         tpDistance = 100.0 * pipSize;
      }

      if(orderType == ORDER_TYPE_BUY)
      {
         return entryPrice + tpDistance;
      }
      else
      {
         return entryPrice - tpDistance;
      }
   }

   //+------------------------------------------------------------------+
   //| Check if Market is Open                                          |
   //+------------------------------------------------------------------+
   bool IsMarketOpen(string symbol)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);

      // Simple check: avoid weekends
      if(dt.day_of_week == 0 || dt.day_of_week == 6)
         return false;

      return true;
   }

   //+------------------------------------------------------------------+
   //| Check if Signal Already Traded                                   |
   //| Prevents duplicate trades for same signal                        |
   //+------------------------------------------------------------------+
   bool IsSignalAlreadyTraded(const SignalData &signal)
   {
      for(int i = 0; i < ArraySize(lastTrades); i++)
      {
         if(lastTrades[i].symbol == signal.symbol &&
            lastTrades[i].timestamp == signal.timestamp &&
            lastTrades[i].signal == signal.signal)
         {
            return true;
         }
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Record Traded Signal                                             |
   //+------------------------------------------------------------------+
   void RecordTrade(const SignalData &signal)
   {
      int size = ArraySize(lastTrades);
      ArrayResize(lastTrades, size + 1);

      lastTrades[size].symbol = signal.symbol;
      lastTrades[size].timestamp = signal.timestamp;
      lastTrades[size].signal = signal.signal;

      // Keep only last 100 trades in memory
      if(size > 100)
      {
         ArrayRemove(lastTrades, 0, 1);
      }
   }
};
//+------------------------------------------------------------------+
