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
   double   maxSpreadPips;        // Maximum spread allowed (pips)
   int      magic;                // Magic number for this EA
   string   tradeComment;         // Comment for trades
   bool     verboseLogging;

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
                 bool verbose = false)
   {
      riskPercent = riskPct;
      minConfidence = minConf;
      maxSpreadPips = maxSpread;
      magic = magicNum;
      tradeComment = "JcampCSM";
      verboseLogging = verbose;

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

      // Calculate SL/TP based on ATR or fixed pips (simple version: use CSM-based logic)
      double sl = CalculateStopLoss(signal.symbol, orderType, price);
      double tp = CalculateTakeProfit(signal.symbol, orderType, price);

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

      // Check spread
      double spread = SymbolInfoInteger(signal.symbol, SYMBOL_SPREAD) * SymbolInfoDouble(signal.symbol, SYMBOL_POINT);
      double spreadPips = spread / SymbolInfoDouble(signal.symbol, SYMBOL_POINT) / 10.0;

      if(spreadPips > maxSpreadPips)
      {
         if(verboseLogging)
            Print("Spread too high: ", spreadPips, " pips > ", maxSpreadPips, " pips");
         return false;
      }

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
   //| Calculate Position Size Based on Risk%                           |
   //| Risk% of account balance per trade                               |
   //+------------------------------------------------------------------+
   double CalculatePositionSize(string symbol, double entryPrice)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = balance * (riskPercent / 100.0);

      // Calculate stop loss distance in pips (simplified: use ATR or fixed pips)
      // For now, use a fixed 50 pips stop loss
      double slPips = 50.0;
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double slDistance = slPips * point * 10.0; // Convert pips to price distance

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
         Print("Position Size Calculation: ", symbol,
               " | Risk: $", riskAmount,
               " | SL Pips: ", slPips,
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
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double slPips = 50.0; // Fixed 50 pips for now

      if(orderType == ORDER_TYPE_BUY)
      {
         return entryPrice - (slPips * point * 10.0);
      }
      else
      {
         return entryPrice + (slPips * point * 10.0);
      }
   }

   //+------------------------------------------------------------------+
   //| Calculate Take Profit                                            |
   //| Simple version: 2x stop loss (Risk:Reward = 1:2)                |
   //+------------------------------------------------------------------+
   double CalculateTakeProfit(string symbol, ENUM_ORDER_TYPE orderType, double entryPrice)
   {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double tpPips = 100.0; // 2x SL = 100 pips

      if(orderType == ORDER_TYPE_BUY)
      {
         return entryPrice + (tpPips * point * 10.0);
      }
      else
      {
         return entryPrice - (tpPips * point * 10.0);
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
