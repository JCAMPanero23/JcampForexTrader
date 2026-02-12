//+------------------------------------------------------------------+
//|                                        SmartOrderManager.mqh      |
//|                                            JcampForexTrader       |
//|                     Session 20: Smart Pending Order System        |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include "SignalReader.mqh"

//+------------------------------------------------------------------+
//| Pending Order Strategy Enum                                      |
//+------------------------------------------------------------------+
enum ENUM_PENDING_STRATEGY
{
   PENDING_STRATEGY_RETRACEMENT,  // Strategy A: Wait for pullback to EMA20
   PENDING_STRATEGY_BREAKOUT,     // Strategy B: Swing high/low breakout
   PENDING_STRATEGY_MARKET        // Fallback: Immediate market order
};

//+------------------------------------------------------------------+
//| Pending Order Data Structure                                     |
//+------------------------------------------------------------------+
struct PendingOrderData
{
   ulong             ticket;              // Order ticket
   string            symbol;              // Symbol
   datetime          placedTime;          // When order was placed
   datetime          expiryTime;          // When order expires
   ENUM_PENDING_STRATEGY strategy;        // Which strategy was used
   double            orderPrice;          // Pending order price
   double            stopLoss;            // SL level
   double            takeProfit;          // TP level
   double            originalEMA20;       // EMA20 at signal time (for retracement)
   double            swingLevel;          // Swing high/low (for breakout)
   int               signalDirection;     // 1 = BUY, -1 = SELL
   bool              active;              // Is order still pending?
};

//+------------------------------------------------------------------+
//| Smart Order Manager Class                                        |
//| Manages intelligent pending order placement and cancellation     |
//+------------------------------------------------------------------+
class SmartOrderManager
{
private:
   CTrade   trade;
   int      magic;
   bool     verboseLogging;

   // Configuration parameters
   int      retracementTriggerPips;       // EMA20 + X pips for retracement entry
   int      extensionThresholdPips;       // Price > EMA20 + X = extended
   int      maxRetracementPips;           // Cancel if retraces too much
   int      swingLookbackBars;            // Bars to find swing high/low
   int      breakoutTriggerPips;          // Pips above swing high for breakout
   int      maxSwingDistancePips;         // Max distance to swing level
   int      retracementExpiryHours;       // Retracement order expiry time
   int      breakoutExpiryHours;          // Breakout order expiry time

   // Active pending orders
   PendingOrderData pendingOrders[];

   // EMA handle cache
   int      emaHandles[];
   string   emaSymbols[];

public:
   SmartOrderManager(int magicNum = 100001,
                     bool verbose = false,
                     int retraceTrigger = 3,
                     int extThreshold = 15,
                     int maxRetrace = 30,
                     int swingLookback = 20,
                     int breakoutTrigger = 1,
                     int maxSwingDist = 30,
                     int retraceExpiry = 4,
                     int breakoutExpiry = 8)
   {
      magic = magicNum;
      verboseLogging = verbose;
      retracementTriggerPips = retraceTrigger;
      extensionThresholdPips = extThreshold;
      maxRetracementPips = maxRetrace;
      swingLookbackBars = swingLookback;
      breakoutTriggerPips = breakoutTrigger;
      maxSwingDistancePips = maxSwingDist;
      retracementExpiryHours = retraceExpiry;
      breakoutExpiryHours = breakoutExpiry;

      trade.SetExpertMagicNumber(magic);
      trade.SetMarginMode();
      trade.SetTypeFillingBySymbol(_Symbol);
      trade.SetDeviationInPoints(10);

      ArrayResize(pendingOrders, 0);
      ArrayResize(emaHandles, 0);
      ArrayResize(emaSymbols, 0);
   }

   ~SmartOrderManager()
   {
      // Release EMA handles
      for(int i = 0; i < ArraySize(emaHandles); i++)
      {
         if(emaHandles[i] != INVALID_HANDLE)
            IndicatorRelease(emaHandles[i]);
      }
   }

   //+------------------------------------------------------------------+
   //| Main Entry Point: Place Smart Pending Order                      |
   //| Return values:                                                    |
   //|  > 0 : Pending order placed (ticket number)                      |
   //|  = 0 : Use market order fallback (conditions not met)            |
   //|  ULONG_MAX : Skip entirely (position or pending exists)          |
   //+------------------------------------------------------------------+
   ulong PlaceSmartPendingOrder(const SignalData &signal, double lots)
   {
      // CHECK 1: Is there already an open position for this symbol?
      if(HasOpenPosition(signal.symbol))
      {
         if(verboseLogging)
            Print("⚠️  Position already exists for ", signal.symbol, " - skipping signal");
         return ULONG_MAX; // Skip entirely (don't execute market order)
      }

      // CHECK 2: Count existing pending orders for this symbol
      int existingPending = CountPendingOrdersForSymbol(signal.symbol);
      if(existingPending >= 2)
      {
         if(verboseLogging)
            Print("⚠️  Already have ", existingPending, " pending orders for ", signal.symbol, " - skipping signal");
         return ULONG_MAX; // Skip entirely
      }

      // CHECK 3: Do we already have a pending order for the same strategy?
      ENUM_PENDING_STRATEGY requestedStrategy = DeterminePendingStrategy(signal);
      if(HasPendingOrderForStrategy(signal.symbol, requestedStrategy))
      {
         if(verboseLogging)
            Print("⚠️  Already have ", EnumToString(requestedStrategy), " order for ", signal.symbol, " - skipping signal");
         return ULONG_MAX; // Skip entirely
      }

      if(verboseLogging)
         Print("🎯 Smart Pending Order: ", signal.symbol, " | Strategy: ", EnumToString(requestedStrategy));

      ulong ticket = 0;

      // Execute appropriate strategy
      switch(requestedStrategy)
      {
         case PENDING_STRATEGY_RETRACEMENT:
            ticket = PlaceRetracementOrder(signal, lots);
            break;

         case PENDING_STRATEGY_BREAKOUT:
            ticket = PlaceBreakoutOrder(signal, lots);
            break;

         case PENDING_STRATEGY_MARKET:
            if(verboseLogging)
               Print("⚡ Market order (fallback) for ", signal.symbol);
            // Return 0 to signal market order should be used instead
            return 0;
      }

      return ticket;
   }

   //+------------------------------------------------------------------+
   //| Strategy A: Retracement to EMA20                                 |
   //| Used when price is extended from EMA20                           |
   //+------------------------------------------------------------------+
   ulong PlaceRetracementOrder(const SignalData &signal, double lots)
   {
      // Get current EMA20
      double ema20 = GetEMA20(signal.symbol, PERIOD_H1);
      if(ema20 <= 0)
      {
         Print("❌ Failed to get EMA20 for ", signal.symbol);
         return 0;
      }

      // Get current price
      double currentPrice = (signal.signal > 0) ?
                            SymbolInfoDouble(signal.symbol, SYMBOL_ASK) :
                            SymbolInfoDouble(signal.symbol, SYMBOL_BID);

      // Calculate pip size
      double pipSize = GetPipSize(signal.symbol);

      // Determine order price (EMA20 +/- trigger pips)
      double orderPrice = 0;
      ENUM_ORDER_TYPE orderType;

      if(signal.signal > 0) // BUY signal
      {
         // Price extended below EMA20, waiting for retracement UP
         // Place BUY LIMIT at EMA20 - 3 pips (below EMA20)
         orderPrice = ema20 - (retracementTriggerPips * pipSize);
         orderType = ORDER_TYPE_BUY_LIMIT;
      }
      else // SELL signal
      {
         // Price extended above EMA20, waiting for retracement DOWN
         // Place SELL LIMIT at EMA20 + 3 pips (above EMA20)
         orderPrice = ema20 + (retracementTriggerPips * pipSize);
         orderType = ORDER_TYPE_SELL_LIMIT;
      }

      // Calculate SL/TP from signal data
      double sl = 0, tp = 0;
      if(signal.signal > 0)
      {
         sl = orderPrice - signal.stopLossDollars;
         tp = orderPrice + signal.takeProfitDollars;
      }
      else
      {
         sl = orderPrice + signal.stopLossDollars;
         tp = orderPrice - signal.takeProfitDollars;
      }

      // Set expiry time (4 hours for retracement)
      datetime expiry = TimeCurrent() + (retracementExpiryHours * 3600);

      // Place pending order
      bool success = trade.OrderOpen(signal.symbol,
                                      orderType,
                                      lots,
                                      0,           // No limit price
                                      orderPrice,  // Stop price
                                      sl,
                                      tp,
                                      ORDER_TIME_SPECIFIED,
                                      expiry,
                                      "Retracement Entry");

      if(success)
      {
         ulong ticket = trade.ResultOrder();

         if(verboseLogging)
         {
            Print("✅ Retracement Order Placed: ", signal.symbol);
            Print("   Price: ", orderPrice, " | EMA20: ", ema20, " | Expiry: ", TimeToString(expiry));
         }

         // Store pending order data
         AddPendingOrder(ticket, signal, PENDING_STRATEGY_RETRACEMENT, orderPrice, sl, tp, ema20, 0, expiry);

         return ticket;
      }
      else
      {
         Print("❌ Failed to place retracement order: ", signal.symbol, " | Error: ", trade.ResultRetcode());
         return 0;
      }
   }

   //+------------------------------------------------------------------+
   //| Strategy B: Swing High/Low Breakout                              |
   //| Used when price is near EMA20 (not extended)                     |
   //+------------------------------------------------------------------+
   ulong PlaceBreakoutOrder(const SignalData &signal, double lots)
   {
      // Find swing level (high for BUY, low for SELL)
      double swingLevel = 0;

      if(signal.signal > 0) // BUY signal - find recent swing high
         swingLevel = FindRecentSwingHigh(signal.symbol, swingLookbackBars);
      else // SELL signal - find recent swing low
         swingLevel = FindRecentSwingLow(signal.symbol, swingLookbackBars);

      if(swingLevel <= 0)
      {
         Print("❌ Failed to find swing level for ", signal.symbol);
         return 0;
      }

      // Calculate pip size
      double pipSize = GetPipSize(signal.symbol);

      // Get current price
      double currentPrice = (signal.signal > 0) ?
                            SymbolInfoDouble(signal.symbol, SYMBOL_ASK) :
                            SymbolInfoDouble(signal.symbol, SYMBOL_BID);

      // Check if swing level is within acceptable distance
      double distancePips = MathAbs(swingLevel - currentPrice) / pipSize;
      if(distancePips > maxSwingDistancePips)
      {
         if(verboseLogging)
            Print("⚠️  Swing level too far (", distancePips, " pips), using market order");
         return 0; // Use market order instead
      }

      // Determine order price (swing level + breakout trigger pips)
      double orderPrice = 0;
      ENUM_ORDER_TYPE orderType;

      if(signal.signal > 0) // BUY signal
      {
         orderPrice = swingLevel + (breakoutTriggerPips * pipSize);
         orderType = ORDER_TYPE_BUY_STOP;
      }
      else // SELL signal
      {
         orderPrice = swingLevel - (breakoutTriggerPips * pipSize);
         orderType = ORDER_TYPE_SELL_STOP;
      }

      // Calculate SL/TP from signal data
      double sl = 0, tp = 0;
      if(signal.signal > 0)
      {
         sl = orderPrice - signal.stopLossDollars;
         tp = orderPrice + signal.takeProfitDollars;
      }
      else
      {
         sl = orderPrice + signal.stopLossDollars;
         tp = orderPrice - signal.takeProfitDollars;
      }

      // Set expiry time (8 hours for breakout)
      datetime expiry = TimeCurrent() + (breakoutExpiryHours * 3600);

      // Place pending order
      bool success = trade.OrderOpen(signal.symbol,
                                      orderType,
                                      lots,
                                      0,           // No limit price
                                      orderPrice,  // Stop price
                                      sl,
                                      tp,
                                      ORDER_TIME_SPECIFIED,
                                      expiry,
                                      "Breakout Entry");

      if(success)
      {
         ulong ticket = trade.ResultOrder();

         if(verboseLogging)
         {
            Print("✅ Breakout Order Placed: ", signal.symbol);
            Print("   Price: ", orderPrice, " | Swing: ", swingLevel, " | Expiry: ", TimeToString(expiry));
         }

         // Store pending order data
         AddPendingOrder(ticket, signal, PENDING_STRATEGY_BREAKOUT, orderPrice, sl, tp, 0, swingLevel, expiry);

         return ticket;
      }
      else
      {
         Print("❌ Failed to place breakout order: ", signal.symbol, " | Error: ", trade.ResultRetcode());
         return 0;
      }
   }

   //+------------------------------------------------------------------+
   //| Determine Best Pending Strategy                                  |
   //| Returns which strategy to use based on market conditions         |
   //+------------------------------------------------------------------+
   ENUM_PENDING_STRATEGY DeterminePendingStrategy(const SignalData &signal)
   {
      // Get current EMA20
      double ema20 = GetEMA20(signal.symbol, PERIOD_H1);
      if(ema20 <= 0)
      {
         if(verboseLogging)
            Print("⚠️  EMA20 unavailable, using market order");
         return PENDING_STRATEGY_MARKET;
      }

      // Get current price
      double currentPrice = (signal.signal > 0) ?
                            SymbolInfoDouble(signal.symbol, SYMBOL_ASK) :
                            SymbolInfoDouble(signal.symbol, SYMBOL_BID);

      // Calculate distance from EMA20
      double pipSize = GetPipSize(signal.symbol);
      double distancePips = 0;

      if(signal.signal > 0) // BUY signal
         distancePips = (currentPrice - ema20) / pipSize;
      else // SELL signal
         distancePips = (ema20 - currentPrice) / pipSize;

      // Decision logic:
      // If price is extended (beyond threshold), use retracement strategy
      if(distancePips >= extensionThresholdPips)
      {
         if(verboseLogging)
            Print("📊 Price extended +", distancePips, " pips from EMA20 → Retracement Strategy");
         return PENDING_STRATEGY_RETRACEMENT;
      }
      // If price is near EMA20, use breakout strategy
      else if(distancePips >= -5) // Within 5 pips (or above)
      {
         if(verboseLogging)
            Print("📊 Price near EMA20 (", distancePips, " pips) → Breakout Strategy");
         return PENDING_STRATEGY_BREAKOUT;
      }
      // If price is below EMA20 on BUY signal (or above on SELL), use market order
      else
      {
         if(verboseLogging)
            Print("⚡ Price ", distancePips, " pips from EMA20 → Market Order");
         return PENDING_STRATEGY_MARKET;
      }
   }

   //+------------------------------------------------------------------+
   //| Update Pending Orders (Check Cancellation Conditions)            |
   //| Call this regularly (OnTick) to monitor active orders            |
   //+------------------------------------------------------------------+
   void UpdatePendingOrders()
   {
      // STEP 1: Check for executed orders and cancel conflicting ones
      for(int i = ArraySize(pendingOrders) - 1; i >= 0; i--)
      {
         if(!pendingOrders[i].active)
            continue;

         // Check if order still exists
         if(!OrderSelect(pendingOrders[i].ticket))
         {
            // Order no longer pending (executed or cancelled)
            string executedSymbol = pendingOrders[i].symbol;
            pendingOrders[i].active = false;

            // Check if position was created (order executed)
            if(HasOpenPosition(executedSymbol))
            {
               if(verboseLogging)
                  Print("✅ Pending order executed for ", executedSymbol, " → Cancelling other pending orders");

               // Cancel all other pending orders for this symbol
               CancelPendingOrdersForSymbol(executedSymbol);
            }

            continue;
         }

         // Check if order expired
         if(TimeCurrent() >= pendingOrders[i].expiryTime)
         {
            if(verboseLogging)
               Print("⏰ Pending order expired: ", pendingOrders[i].symbol, " | Ticket: ", pendingOrders[i].ticket);
            pendingOrders[i].active = false;
            continue;
         }

         // Check cancellation conditions based on strategy
         bool shouldCancel = false;

         if(pendingOrders[i].strategy == PENDING_STRATEGY_RETRACEMENT)
         {
            shouldCancel = CheckRetracementCancellation(pendingOrders[i]);
         }
         else if(pendingOrders[i].strategy == PENDING_STRATEGY_BREAKOUT)
         {
            shouldCancel = CheckBreakoutCancellation(pendingOrders[i]);
         }

         if(shouldCancel)
         {
            if(trade.OrderDelete(pendingOrders[i].ticket))
            {
               if(verboseLogging)
                  Print("🚫 Pending order cancelled: ", pendingOrders[i].symbol, " | Reason: Conditions violated");
               pendingOrders[i].active = false;
            }
         }
      }

      // STEP 2: Periodic check - cancel pending orders if position exists
      //         (handles cases where position opened via market order)
      for(int i = ArraySize(pendingOrders) - 1; i >= 0; i--)
      {
         if(!pendingOrders[i].active)
            continue;

         if(HasOpenPosition(pendingOrders[i].symbol))
         {
            if(verboseLogging)
               Print("🚫 Position exists for ", pendingOrders[i].symbol, " → Cancelling pending order #", pendingOrders[i].ticket);

            if(OrderSelect(pendingOrders[i].ticket))
            {
               trade.OrderDelete(pendingOrders[i].ticket);
            }
            pendingOrders[i].active = false;
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Check if retracement order should be cancelled                   |
   //+------------------------------------------------------------------+
   bool CheckRetracementCancellation(const PendingOrderData &order)
   {
      // Get current price
      double currentPrice = (order.signalDirection > 0) ?
                            SymbolInfoDouble(order.symbol, SYMBOL_ASK) :
                            SymbolInfoDouble(order.symbol, SYMBOL_BID);

      double pipSize = GetPipSize(order.symbol);

      // Check if price moved too far beyond EMA20 (signal invalidated)
      double ema20 = GetEMA20(order.symbol, PERIOD_H1);
      if(ema20 <= 0) return false; // Can't determine, keep order

      double retracementPips = 0;

      if(order.signalDirection > 0) // BUY order
      {
         // Cancel if price drops too far below EMA20
         retracementPips = (ema20 - currentPrice) / pipSize;
      }
      else // SELL order
      {
         // Cancel if price rises too far above EMA20
         retracementPips = (currentPrice - ema20) / pipSize;
      }

      if(retracementPips > maxRetracementPips)
      {
         if(verboseLogging)
            Print("⚠️  Retracement too deep (", retracementPips, " pips), cancelling order");
         return true;
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Check if breakout order should be cancelled                      |
   //+------------------------------------------------------------------+
   bool CheckBreakoutCancellation(const PendingOrderData &order)
   {
      // Get current price
      double currentPrice = (order.signalDirection > 0) ?
                            SymbolInfoDouble(order.symbol, SYMBOL_BID) :
                            SymbolInfoDouble(order.symbol, SYMBOL_ASK);

      // Check if price moved in opposite direction (failed breakout)
      double pipSize = GetPipSize(order.symbol);
      double distancePips = 0;

      if(order.signalDirection > 0) // BUY order
      {
         // Cancel if price drops below swing level (failed breakout)
         if(currentPrice < order.swingLevel)
         {
            distancePips = (order.swingLevel - currentPrice) / pipSize;
            if(distancePips > 5) // Allow 5 pips noise
            {
               if(verboseLogging)
                  Print("⚠️  Failed breakout (below swing -", distancePips, " pips), cancelling");
               return true;
            }
         }
      }
      else // SELL order
      {
         // Cancel if price rises above swing level (failed breakout)
         if(currentPrice > order.swingLevel)
         {
            distancePips = (currentPrice - order.swingLevel) / pipSize;
            if(distancePips > 5) // Allow 5 pips noise
            {
               if(verboseLogging)
                  Print("⚠️  Failed breakout (above swing +", distancePips, " pips), cancelling");
               return true;
            }
         }
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Helper: Get EMA20 Value                                          |
   //+------------------------------------------------------------------+
   double GetEMA20(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      // Find or create EMA handle for this symbol
      int handle = INVALID_HANDLE;
      int index = -1;

      for(int i = 0; i < ArraySize(emaSymbols); i++)
      {
         if(emaSymbols[i] == symbol)
         {
            handle = emaHandles[i];
            index = i;
            break;
         }
      }

      // Create new handle if not found
      if(handle == INVALID_HANDLE)
      {
         handle = iMA(symbol, timeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
         if(handle == INVALID_HANDLE)
         {
            Print("❌ Failed to create EMA handle for ", symbol);
            return 0;
         }

         // Store handle
         int size = ArraySize(emaHandles);
         ArrayResize(emaHandles, size + 1);
         ArrayResize(emaSymbols, size + 1);
         emaHandles[size] = handle;
         emaSymbols[size] = symbol;
      }

      // Get EMA value
      double ema[];
      ArraySetAsSeries(ema, true);

      if(CopyBuffer(handle, 0, 0, 1, ema) <= 0)
      {
         Print("❌ Failed to copy EMA buffer for ", symbol);
         return 0;
      }

      return ema[0];
   }

   //+------------------------------------------------------------------+
   //| Helper: Find Recent Swing High                                   |
   //+------------------------------------------------------------------+
   double FindRecentSwingHigh(string symbol, int lookback)
   {
      double highs[];
      ArraySetAsSeries(highs, true);

      if(CopyHigh(symbol, PERIOD_H1, 0, lookback, highs) <= 0)
      {
         Print("❌ Failed to copy highs for ", symbol);
         return 0;
      }

      // Find highest high in lookback period
      double swingHigh = highs[ArrayMaximum(highs)];
      return swingHigh;
   }

   //+------------------------------------------------------------------+
   //| Helper: Find Recent Swing Low                                    |
   //+------------------------------------------------------------------+
   double FindRecentSwingLow(string symbol, int lookback)
   {
      double lows[];
      ArraySetAsSeries(lows, true);

      if(CopyLow(symbol, PERIOD_H1, 0, lookback, lows) <= 0)
      {
         Print("❌ Failed to copy lows for ", symbol);
         return 0;
      }

      // Find lowest low in lookback period
      double swingLow = lows[ArrayMinimum(lows)];
      return swingLow;
   }

   //+------------------------------------------------------------------+
   //| Helper: Get Pip Size                                             |
   //+------------------------------------------------------------------+
   double GetPipSize(string symbol)
   {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

      // Handle 3/5 digit brokers
      if(digits == 3 || digits == 5)
         return point * 10;
      else
         return point;
   }

   //+------------------------------------------------------------------+
   //| Helper: Add Pending Order to Tracking Array                      |
   //+------------------------------------------------------------------+
   void AddPendingOrder(ulong ticket, const SignalData &signal, ENUM_PENDING_STRATEGY strategy,
                        double orderPrice, double sl, double tp, double ema20, double swingLevel,
                        datetime expiry)
   {
      int size = ArraySize(pendingOrders);
      ArrayResize(pendingOrders, size + 1);

      pendingOrders[size].ticket = ticket;
      pendingOrders[size].symbol = signal.symbol;
      pendingOrders[size].placedTime = TimeCurrent();
      pendingOrders[size].expiryTime = expiry;
      pendingOrders[size].strategy = strategy;
      pendingOrders[size].orderPrice = orderPrice;
      pendingOrders[size].stopLoss = sl;
      pendingOrders[size].takeProfit = tp;
      pendingOrders[size].originalEMA20 = ema20;
      pendingOrders[size].swingLevel = swingLevel;
      pendingOrders[size].signalDirection = signal.signal;
      pendingOrders[size].active = true;
   }

   //+------------------------------------------------------------------+
   //| Helper: Check if Open Position Exists for Symbol                 |
   //+------------------------------------------------------------------+
   bool HasOpenPosition(string symbol)
   {
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(PositionGetSymbol(i) == symbol &&
            PositionGetInteger(POSITION_MAGIC) == magic)
         {
            return true;
         }
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Helper: Count Pending Orders for Symbol                          |
   //+------------------------------------------------------------------+
   int CountPendingOrdersForSymbol(string symbol)
   {
      int count = 0;

      for(int i = 0; i < OrdersTotal(); i++)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket > 0)
         {
            if(OrderGetString(ORDER_SYMBOL) == symbol &&
               OrderGetInteger(ORDER_MAGIC) == magic)
            {
               count++;
            }
         }
      }

      return count;
   }

   //+------------------------------------------------------------------+
   //| Helper: Check if Pending Order Exists for Strategy              |
   //+------------------------------------------------------------------+
   bool HasPendingOrderForStrategy(string symbol, ENUM_PENDING_STRATEGY strategy)
   {
      // Check our tracked pending orders
      for(int i = 0; i < ArraySize(pendingOrders); i++)
      {
         if(pendingOrders[i].active &&
            pendingOrders[i].symbol == symbol &&
            pendingOrders[i].strategy == strategy)
         {
            return true;
         }
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Helper: Cancel All Pending Orders for Symbol                    |
   //+------------------------------------------------------------------+
   void CancelPendingOrdersForSymbol(string symbol)
   {
      int cancelledCount = 0;

      for(int i = ArraySize(pendingOrders) - 1; i >= 0; i--)
      {
         if(pendingOrders[i].active && pendingOrders[i].symbol == symbol)
         {
            // Try to cancel the order
            if(OrderSelect(pendingOrders[i].ticket))
            {
               if(trade.OrderDelete(pendingOrders[i].ticket))
               {
                  if(verboseLogging)
                     Print("   🚫 Cancelled pending order #", pendingOrders[i].ticket,
                           " (", EnumToString(pendingOrders[i].strategy), ")");
                  cancelledCount++;
               }
            }
            pendingOrders[i].active = false;
         }
      }

      if(verboseLogging && cancelledCount > 0)
         Print("   ✅ Total cancelled: ", cancelledCount, " pending orders for ", symbol);
   }

   //+------------------------------------------------------------------+
   //| Get Active Pending Order Count                                   |
   //+------------------------------------------------------------------+
   int GetActivePendingCount()
   {
      int count = 0;
      for(int i = 0; i < ArraySize(pendingOrders); i++)
      {
         if(pendingOrders[i].active)
            count++;
      }
      return count;
   }
};
//+------------------------------------------------------------------+
