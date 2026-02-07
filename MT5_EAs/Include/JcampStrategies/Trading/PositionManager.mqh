//+------------------------------------------------------------------+
//|                                           PositionManager.mqh     |
//|                                            JcampForexTrader       |
//|                         Session 16 - 3-Phase Trailing System     |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>
#include "PositionTracker.mqh"

//+------------------------------------------------------------------+
//| Position Manager Class (Enhanced with 3-Phase Trailing)          |
//| Manages open positions with asymmetric trailing stop system      |
//+------------------------------------------------------------------+
class PositionManager
{
private:
   CTrade   trade;
   CPositionTracker tracker;
   int      magic;
   bool     useAdvancedTrailing;
   double   trailingActivationR;
   double   phase1EndR;
   double   phase1TrailDistance;
   double   phase2EndR;
   double   phase2TrailDistance;
   double   phase3TrailDistance;
   bool     verboseLogging;

public:
   PositionManager(int magicNum = 100001,
                   bool useAdvanced = true,
                   double activationR = 0.5,
                   double p1End = 1.0,
                   double p1Trail = 0.3,
                   double p2End = 2.0,
                   double p2Trail = 0.5,
                   double p3Trail = 0.8,
                   bool verbose = false)
   {
      magic = magicNum;
      useAdvancedTrailing = useAdvanced;
      trailingActivationR = activationR;
      phase1EndR = p1End;
      phase1TrailDistance = p1Trail;
      phase2EndR = p2End;
      phase2TrailDistance = p2Trail;
      phase3TrailDistance = p3Trail;
      verboseLogging = verbose;

      trade.SetExpertMagicNumber(magic);
   }

   ~PositionManager() {}

   //+------------------------------------------------------------------+
   //| Register New Position for Tracking                               |
   //| Call this immediately after trade execution                       |
   //+------------------------------------------------------------------+
   bool RegisterPosition(ulong ticket,
                          string symbol,
                          string strategy,
                          int signal,
                          double entryPrice,
                          double slDistance)
   {
      return tracker.AddPosition(ticket, symbol, strategy, signal, entryPrice, slDistance);
   }

   //+------------------------------------------------------------------+
   //| Update All Positions (3-Phase Trailing System)                   |
   //| Call this on every OnTick                                         |
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

         // Check if position still exists
         if(!PositionSelectByTicket(ticket))
         {
            // Position closed, remove from tracker
            tracker.RemovePosition(ticket);
            continue;
         }

         // Get position data from tracker
         PositionData* pos = tracker.GetPosition(ticket);
         if(pos == NULL)
         {
            // Position not tracked (opened externally or before EA start)
            continue;
        }

         // Get current position info
         string symbol = PositionGetString(POSITION_SYMBOL);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double currentPrice = (posType == POSITION_TYPE_BUY) ?
                               SymbolInfoDouble(symbol, SYMBOL_BID) :
                               SymbolInfoDouble(symbol, SYMBOL_ASK);
         double currentSL = PositionGetDouble(POSITION_SL);
         double currentTP = PositionGetDouble(POSITION_TP);

         // Calculate current R-multiple
         double currentR = tracker.CalculateCurrentR(ticket, currentPrice);

         // Update high water mark
         tracker.UpdateHighWaterMark(ticket, currentPrice);

         // ✅ RANGE RIDER EARLY BREAKEVEN (at +0.5R)
         if(!pos.breakevenSet && StringFind(pos.strategy, "RANGE") >= 0 && currentR >= 0.5)
         {
            ApplyBreakeven(ticket, symbol, posType, pos.entryPrice, currentSL, currentTP);
            tracker.SetBreakevenSet(ticket, true);
            continue; // Skip trailing this tick (breakeven just set)
         }

         // Check if advanced trailing should activate
         if(!useAdvancedTrailing || currentR < trailingActivationR)
            continue; // Not profitable enough yet

         // Activate trailing if not already
         if(!pos.trailingActivated)
         {
            tracker.SetTrailingActivated(ticket, true);
            if(verboseLogging)
            {
               Print("⚡ Trailing Activated: #", ticket, " | ",
                     symbol, " | R=+", DoubleToString(currentR, 2));
            }
         }

         // Determine current phase
         int phase = tracker.GetCurrentPhase(currentR, phase1EndR, phase2EndR);

         // Get trail distance for current phase
         double trailDistance = 0;
         if(phase == 1)
            trailDistance = phase1TrailDistance;
         else if(phase == 2)
            trailDistance = phase2TrailDistance;
         else
            trailDistance = phase3TrailDistance;

         // Calculate new SL in R-multiples
         double newSL_R = currentR - trailDistance;

         // Prevent negative R (don't move SL below entry)
         if(newSL_R < 0)
            newSL_R = 0;

         // Convert R to price
         double newSL_Price;
         if(posType == POSITION_TYPE_BUY)
            newSL_Price = pos.entryPrice + (newSL_R * pos.originalSLDistance);
         else
            newSL_Price = pos.entryPrice - (newSL_R * pos.originalSLDistance);

         // Only move SL if better than current
         bool shouldUpdate = false;
         if(posType == POSITION_TYPE_BUY && newSL_Price > currentSL)
            shouldUpdate = true;
         else if(posType == POSITION_TYPE_SELL && newSL_Price < currentSL)
            shouldUpdate = true;

         if(shouldUpdate)
         {
            // Normalize price
            int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
            newSL_Price = NormalizeDouble(newSL_Price, digits);

            if(trade.PositionModify(ticket, newSL_Price, currentTP))
            {
               // Update phase if changed
               if(phase != pos.currentPhase)
               {
                  tracker.SetPhase(ticket, phase);
                  if(verboseLogging)
                  {
                     Print("🎯 Phase Transition: #", ticket, " | ",
                           symbol, " | Phase ", pos.currentPhase, " → ", phase,
                           " | R=+", DoubleToString(currentR, 2));
                  }
               }

               if(verboseLogging)
               {
                  Print("✓ Trailing Phase ", phase, " | #", ticket, " | ",
                        symbol, " | R=+", DoubleToString(currentR, 2),
                        " | SL→+", DoubleToString(newSL_R, 2), "R");
               }
            }
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
         tracker.RemovePosition(ticket);
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
   //| Apply Breakeven Stop Loss (RangeRider at +0.5R)                  |
   //+------------------------------------------------------------------+
   void ApplyBreakeven(ulong ticket,
                       string symbol,
                       ENUM_POSITION_TYPE posType,
                       double entryPrice,
                       double currentSL,
                       double currentTP)
   {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

      // Move to breakeven + 2 pips
      double bePrice;
      if(posType == POSITION_TYPE_BUY)
         bePrice = entryPrice + (2.0 * 10 * point); // +2 pips
      else
         bePrice = entryPrice - (2.0 * 10 * point); // -2 pips

      bePrice = NormalizeDouble(bePrice, digits);

      // Only update if better than current SL
      bool shouldUpdate = false;
      if(posType == POSITION_TYPE_BUY && bePrice > currentSL)
         shouldUpdate = true;
      else if(posType == POSITION_TYPE_SELL && bePrice < currentSL)
         shouldUpdate = true;

      if(shouldUpdate)
      {
         if(trade.PositionModify(ticket, bePrice, currentTP))
         {
            Print("🛡️ RangeRider Breakeven | #", ticket, " | ",
                  symbol, " | SL→Entry+2 pips (worst case: -0.08R)");
         }
      }
   }
};
//+------------------------------------------------------------------+
