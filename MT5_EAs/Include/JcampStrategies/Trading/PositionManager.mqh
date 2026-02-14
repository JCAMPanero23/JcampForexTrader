//+------------------------------------------------------------------+
//|                                           PositionManager.mqh     |
//|                                            JcampForexTrader       |
//|           Session 21 - 4-Hour Fixed SL + Profit Lock + Chandelier|
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "3.00"
#property strict

#include <Trade\Trade.mqh>
#include "PositionTracker.mqh"
#include "ChandelierStop.mqh"

//+------------------------------------------------------------------+
//| Position Manager Class (Session 21 Enhanced)                     |
//| - 4-hour fixed SL period (no trailing)                           |
//| - 1.5R profit lock at +0.5R (within 4 hours)                     |
//| - Chandelier trailing after 4 hours OR profit lock               |
//+------------------------------------------------------------------+
class PositionManager
{
private:
   CTrade   trade;
   CPositionTracker tracker;
   CChandelierStop chandelier;
   int      magic;
   
   // Session 21: Profit Lock Settings
   bool     useConditionalLock;
   double   profitLockTriggerR;
   double   profitLockLevelR;
   int      fixedSLPeriodHours;
   
   // Session 21: Chandelier Settings  
   bool     useChandelierStop;
   int      chandelierLookback;
   double   chandelierATRMultiplier;
   
   // Legacy (for backwards compatibility)
   bool     verboseLogging;

public:
   PositionManager(int magicNum = 100001,
                   bool useCondLock = true,
                   double lockTriggerR = 1.5,
                   double lockLevelR = 0.5,
                   int fixedPeriodHours = 4,
                   bool useChandelier = true,
                   int lookbackBars = 20,
                   double chandelierATRMult = 2.5,
                   bool verbose = false)
   {
      magic = magicNum;
      
      // Session 21 settings
      useConditionalLock = useCondLock;
      profitLockTriggerR = lockTriggerR;
      profitLockLevelR = lockLevelR;
      fixedSLPeriodHours = fixedPeriodHours;
      useChandelierStop = useChandelier;
      chandelierLookback = lookbackBars;
      chandelierATRMultiplier = chandelierATRMult;
      
      verboseLogging = verbose;
      
      // Initialize Chandelier with configured settings
      chandelier = new CChandelierStop(lookbackBars, chandelierATRMult, PERIOD_H1, 14);
      
      trade.SetExpertMagicNumber(magic);
   }

   ~PositionManager() 
   {
      delete chandelier;
   }
   }

   //+------------------------------------------------------------------+
   //| Register New Position for Tracking                               |
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
   //| Update All Positions (Session 21 Logic)                          |
   //| Flow:                                                             |
   //| 1. Check 1.5R profit lock (within 4 hours)                       |
   //| 2. Check if 4-hour period elapsed                                |
   //| 3. Apply Chandelier trailing (if activated)                      |
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
            tracker.RemovePosition(ticket);
            continue;
         }

         // Get position data from tracker
         PositionData pos;
         if(!tracker.GetPosition(ticket, pos))
         {
            continue; // Not tracked
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

         // ═════════════════════════════════════════════════════════════
         // SESSION 21 LOGIC: 4-Hour Fixed SL + Conditional Profit Lock
         // ═════════════════════════════════════════════════════════════

         // ✅ STEP 1: Check for 1.5R Profit Lock (within 4 hours)
         if(useConditionalLock && !pos.profitLocked && !pos.chandelierActive)
         {
            // Check if 4-hour period NOT yet elapsed
            bool withinFixedPeriod = !tracker.HasFixedPeriodElapsed(ticket, fixedSLPeriodHours);
            
            if(withinFixedPeriod && currentR >= profitLockTriggerR)
            {
               // PROFIT LOCK TRIGGERED! Lock at +0.5R and activate Chandelier
               ApplyProfitLock(ticket, symbol, posType, pos.entryPrice, pos.originalSLDistance, currentSL, currentTP);
               tracker.SetProfitLocked(ticket, true);
               tracker.SetChandelierActive(ticket, true);
               
               if(verboseLogging)
               {
                  Print("🔒 PROFIT LOCK | #", ticket, " | ", symbol,
                        " | Hit +", DoubleToString(profitLockTriggerR, 1), "R in ", fixedSLPeriodHours, "h",
                        " | Locked +", DoubleToString(profitLockLevelR, 1), "R | Chandelier ON");
               }
               
               continue; // Skip further processing this tick
            }
         }

         // ✅ STEP 2: Check if 4-hour fixed period has elapsed
         if(!pos.chandelierActive)
         {
            bool fixedPeriodElapsed = tracker.HasFixedPeriodElapsed(ticket, fixedSLPeriodHours);
            
            if(fixedPeriodElapsed)
            {
               // Activate Chandelier after 4 hours
               tracker.SetChandelierActive(ticket, true);
               
               if(verboseLogging)
               {
                  Print("⏰ 4-HOUR ELAPSED | #", ticket, " | ", symbol,
                        " | Chandelier ON | R: +", DoubleToString(currentR, 2));
               }
            }
            else
            {
               // Still in fixed SL period, no trailing
               continue;
            }
         }

         // ✅ STEP 3: Apply Chandelier Trailing (if active)
         if(pos.chandelierActive && useChandelierStop)
         {
            double newChandelierSL = 0;
            
            if(posType == POSITION_TYPE_BUY)
               newChandelierSL = chandelier.CalculateBuySL(symbol);
            else
               newChandelierSL = chandelier.CalculateSellSL(symbol);

            if(newChandelierSL <= 0)
            {
               if(verboseLogging)
                  Print("⚠️ Chandelier calc failed: ", symbol);
               continue;
            }

            // Check if should update
            if(chandelier.ShouldUpdate(currentSL, newChandelierSL, posType))
            {
               int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
               newChandelierSL = NormalizeDouble(newChandelierSL, digits);

               if(trade.PositionModify(ticket, newChandelierSL, currentTP))
               {
                  if(verboseLogging)
                  {
                     Print("📊 Chandelier | #", ticket, " | ", symbol,
                           " | R: +", DoubleToString(currentR, 2),
                           " | SL: ", DoubleToString(newChandelierSL, digits));
                  }
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
         Print("ERROR: Failed to close #", ticket, " | Error: ", GetLastError());
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
   //| Session 21: Apply Profit Lock (Move SL to +0.5R)                 |
   //+------------------------------------------------------------------+
   void ApplyProfitLock(ulong ticket,
                        string symbol,
                        ENUM_POSITION_TYPE posType,
                        double entryPrice,
                        double slDistance,
                        double currentSL,
                        double currentTP)
   {
      // Calculate +0.5R price level
      double lockPrice;
      if(posType == POSITION_TYPE_BUY)
         lockPrice = entryPrice + (profitLockLevelR * slDistance);
      else
         lockPrice = entryPrice - (profitLockLevelR * slDistance);

      // Normalize
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      lockPrice = NormalizeDouble(lockPrice, digits);

      // Only update if better than current SL
      bool shouldUpdate = false;
      if(posType == POSITION_TYPE_BUY && lockPrice > currentSL)
         shouldUpdate = true;
      else if(posType == POSITION_TYPE_SELL && lockPrice < currentSL)
         shouldUpdate = true;

      if(shouldUpdate)
      {
         if(trade.PositionModify(ticket, lockPrice, currentTP))
         {
            if(verboseLogging)
            {
               Print("🔐 Profit Lock Applied | #", ticket, " | ", symbol,
                     " | SL → +", DoubleToString(profitLockLevelR, 1), "R (",
                     DoubleToString(lockPrice, digits), ")");
            }
         }
      }
   }
};
//+------------------------------------------------------------------+
