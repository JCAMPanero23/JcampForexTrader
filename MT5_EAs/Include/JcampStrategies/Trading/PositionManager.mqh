//+------------------------------------------------------------------+
//|                                           PositionManager.mqh     |
//|                                            JcampForexTrader       |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Position Manager Class                                            |
//| Manages open positions: trailing stops, partial closes, monitoring|
//+------------------------------------------------------------------+
class PositionManager
{
private:
   CTrade   trade;
   int      magic;
   bool     enableTrailingStop;
   int      trailingStopPips;
   int      trailingStartPips;     // Start trailing after X pips profit
   bool     verboseLogging;

   // Track position high water marks for trailing stops
   struct PositionTracker {
      ulong    ticket;
      double   highWaterMark;      // Highest price for BUY, lowest for SELL
   };
   PositionTracker trackers[];

public:
   PositionManager(int magicNum = 100001,
                   bool enableTrailing = true,
                   int trailingPips = 20,
                   int trailingStart = 30,
                   bool verbose = false)
   {
      magic = magicNum;
      enableTrailingStop = enableTrailing;
      trailingStopPips = trailingPips;
      trailingStartPips = trailingStart;
      verboseLogging = verbose;

      trade.SetExpertMagicNumber(magic);
      ArrayResize(trackers, 0);
   }

   ~PositionManager() {}

   //+------------------------------------------------------------------+
   //| Update All Positions                                             |
   //| Call this on every OnTick or periodically                        |
   //+------------------------------------------------------------------+
   void UpdatePositions()
   {
      int totalPositions = PositionsTotal();

      for(int i = totalPositions - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket <= 0) continue;

         // Only manage positions from this EA
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;

         // Get position info
         string symbol = PositionGetString(POSITION_SYMBOL);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentPrice = (posType == POSITION_TYPE_BUY) ?
                               SymbolInfoDouble(symbol, SYMBOL_BID) :
                               SymbolInfoDouble(symbol, SYMBOL_ASK);
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         double profit = PositionGetDouble(POSITION_PROFIT);

         // Apply trailing stop if enabled
         if(enableTrailingStop)
         {
            CheckAndApplyTrailingStop(ticket, symbol, posType, openPrice, currentPrice, sl);
         }

         // Log position status if verbose
         if(verboseLogging)
         {
            double pips = CalculatePips(symbol, openPrice, currentPrice, posType);
            Print("Position #", ticket, " | ", symbol, " ",
                  EnumToString(posType), " | P&L: $", profit,
                  " | Pips: ", pips);
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Get Count of Open Positions for this EA                          |
   //+------------------------------------------------------------------+
   int GetOpenPositionCount()
   {
      int count = 0;
      int totalPositions = PositionsTotal();

      for(int i = 0; i < totalPositions; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket <= 0) continue;

         if(PositionGetInteger(POSITION_MAGIC) == magic)
            count++;
      }

      return count;
   }

   //+------------------------------------------------------------------+
   //| Get Count of Open Positions for a Symbol                         |
   //+------------------------------------------------------------------+
   int GetOpenPositionCountForSymbol(string symbol)
   {
      int count = 0;
      int totalPositions = PositionsTotal();

      for(int i = 0; i < totalPositions; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket <= 0) continue;

         if(PositionGetInteger(POSITION_MAGIC) == magic &&
            PositionGetString(POSITION_SYMBOL) == symbol)
            count++;
      }

      return count;
   }

   //+------------------------------------------------------------------+
   //| Close Position by Ticket                                         |
   //+------------------------------------------------------------------+
   bool ClosePosition(ulong ticket, string reason = "")
   {
      if(!PositionSelectByTicket(ticket))
         return false;

      string symbol = PositionGetString(POSITION_SYMBOL);
      double lots = PositionGetDouble(POSITION_VOLUME);

      bool success = trade.PositionClose(ticket);

      if(success)
      {
         Print("✅ Position Closed: #", ticket, " | ", symbol,
               " | Reason: ", reason);
         RemoveTracker(ticket);
         return true;
      }
      else
      {
         Print("ERROR: Failed to close position #", ticket,
               " | Error: ", GetLastError());
         return false;
      }
   }

   //+------------------------------------------------------------------+
   //| Close All Positions for a Symbol                                 |
   //+------------------------------------------------------------------+
   int CloseAllPositionsForSymbol(string symbol, string reason = "")
   {
      int closedCount = 0;
      int totalPositions = PositionsTotal();

      for(int i = totalPositions - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket <= 0) continue;

         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;

         if(PositionGetString(POSITION_SYMBOL) != symbol)
            continue;

         if(ClosePosition(ticket, reason))
            closedCount++;
      }

      return closedCount;
   }

private:
   //+------------------------------------------------------------------+
   //| Check and Apply Trailing Stop                                    |
   //+------------------------------------------------------------------+
   void CheckAndApplyTrailingStop(ulong ticket,
                                   string symbol,
                                   ENUM_POSITION_TYPE posType,
                                   double openPrice,
                                   double currentPrice,
                                   double currentSL)
   {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double pipValue = 10 * point; // 1 pip = 10 points

      // Calculate current profit in pips
      double profitPips = CalculatePips(symbol, openPrice, currentPrice, posType);

      // Only start trailing after position is in profit by trailingStartPips
      if(profitPips < trailingStartPips)
         return;

      // Get or create tracker for this position (returns index)
      int trackerIdx = GetOrCreateTracker(ticket);
      if(trackerIdx < 0)
         return;

      // Update high water mark
      if(posType == POSITION_TYPE_BUY)
      {
         if(trackers[trackerIdx].highWaterMark == 0 || currentPrice > trackers[trackerIdx].highWaterMark)
            trackers[trackerIdx].highWaterMark = currentPrice;
      }
      else // SELL
      {
         if(trackers[trackerIdx].highWaterMark == 0 || currentPrice < trackers[trackerIdx].highWaterMark)
            trackers[trackerIdx].highWaterMark = currentPrice;
      }

      // Calculate new trailing stop
      double newSL = 0;
      if(posType == POSITION_TYPE_BUY)
      {
         newSL = trackers[trackerIdx].highWaterMark - (trailingStopPips * pipValue);

         // Only update if new SL is better (higher) than current SL
         if(newSL > currentSL || currentSL == 0)
         {
            newSL = NormalizeDouble(newSL, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));

            if(trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP)))
            {
               if(verboseLogging)
               {
                  Print("📈 Trailing Stop Updated: #", ticket, " | ",
                        symbol, " BUY | New SL: ", newSL,
                        " | High: ", trackers[trackerIdx].highWaterMark);
               }
            }
         }
      }
      else // SELL
      {
         newSL = trackers[trackerIdx].highWaterMark + (trailingStopPips * pipValue);

         // Only update if new SL is better (lower) than current SL
         if(newSL < currentSL || currentSL == 0)
         {
            newSL = NormalizeDouble(newSL, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));

            if(trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP)))
            {
               if(verboseLogging)
               {
                  Print("📉 Trailing Stop Updated: #", ticket, " | ",
                        symbol, " SELL | New SL: ", newSL,
                        " | Low: ", trackers[trackerIdx].highWaterMark);
               }
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Calculate Pips Profit/Loss                                       |
   //+------------------------------------------------------------------+
   double CalculatePips(string symbol, double openPrice, double currentPrice, ENUM_POSITION_TYPE posType)
   {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double priceDiff = 0;

      if(posType == POSITION_TYPE_BUY)
         priceDiff = currentPrice - openPrice;
      else
         priceDiff = openPrice - currentPrice;

      return priceDiff / (point * 10.0); // Convert to pips
   }

   //+------------------------------------------------------------------+
   //| Get or Create Position Tracker (returns array index)             |
   //+------------------------------------------------------------------+
   int GetOrCreateTracker(ulong ticket)
   {
      // Find existing tracker
      for(int i = 0; i < ArraySize(trackers); i++)
      {
         if(trackers[i].ticket == ticket)
            return i;  // Return index
      }

      // Create new tracker
      int size = ArraySize(trackers);
      ArrayResize(trackers, size + 1);
      trackers[size].ticket = ticket;
      trackers[size].highWaterMark = 0;

      return size;  // Return index of new tracker
   }

   //+------------------------------------------------------------------+
   //| Remove Tracker (when position closes)                            |
   //+------------------------------------------------------------------+
   void RemoveTracker(ulong ticket)
   {
      for(int i = 0; i < ArraySize(trackers); i++)
      {
         if(trackers[i].ticket == ticket)
         {
            // Shift array
            for(int j = i; j < ArraySize(trackers) - 1; j++)
            {
               trackers[j] = trackers[j + 1];
            }
            ArrayResize(trackers, ArraySize(trackers) - 1);
            break;
         }
      }
   }
};
//+------------------------------------------------------------------+
