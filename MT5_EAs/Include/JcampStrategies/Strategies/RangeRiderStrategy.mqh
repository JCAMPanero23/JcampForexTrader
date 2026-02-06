//+------------------------------------------------------------------+
//|                                        RangeRiderStrategy.mqh     |
//|                                            JcampForexTrader       |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "1.00"
#property strict

#include "../Indicators/RsiCalculator.mqh"
#include "IStrategy.mqh"

//+------------------------------------------------------------------+
//| Range Data Structure (for range detection)                       |
//| NOTE: This strategy requires a range detection system to be      |
//| implemented separately. The range detector should identify       |
//| support/resistance levels and track active ranges.               |
//+------------------------------------------------------------------+
struct RangeData
{
   bool     isValid;
   double   topLevel;
   double   bottomLevel;
   double   midLevel;
   double   rangeWidth;
   int      topTouches;
   int      bottomTouches;
   int      qualityScore;
   datetime detectedTime;
   string   symbol;
};

//+------------------------------------------------------------------+
//| RangeRider Strategy Implementation                               |
//| Confidence Scoring System: 0-100 points                          |
//|   - Proximity: 0-15 points                                       |
//|   - Rejection Pattern: 0-15 points                               |
//|   - RSI: 0-20 points                                             |
//|   - Stochastic: 0-15 points                                      |
//|   - CSM: 0-25 points                                             |
//|   - Volume: 10 points (bonus)                                    |
//|                                                                   |
//| IMPORTANT: This strategy requires an active range to be detected |
//| before it can generate signals. Range detection logic should be  |
//| implemented in the calling EA or as a separate module.           |
//+------------------------------------------------------------------+
class RangeRiderStrategy : public IStrategy
{
private:
   int minConfidence;
   bool verboseLogging;

   // Range management (to be populated by calling EA)
   RangeData activeRange;
   bool hasActiveRange;

public:
   RangeRiderStrategy(int minConf = 65, bool verbose = false)
   {
      minConfidence = minConf;
      verboseLogging = verbose;
      hasActiveRange = false;
   }

   ~RangeRiderStrategy() {}

   virtual string GetName() override { return "RANGE_RIDER"; }
   virtual int GetMinConfidence() override { return minConfidence; }

   //+------------------------------------------------------------------+
   //| Set Active Range (must be called before Analyze)                |
   //+------------------------------------------------------------------+
   void SetActiveRange(const RangeData &range)
   {
      activeRange = range;
      hasActiveRange = range.isValid;
   }

   //+------------------------------------------------------------------+
   //| Main Analysis Function                                           |
   //+------------------------------------------------------------------+
   virtual bool Analyze(string symbol,
                       ENUM_TIMEFRAMES timeframe,
                       double csmDiff,
                       StrategySignal &result) override
   {
      if(verboseLogging)
         Print("\n====== RANGE RIDER ANALYSIS ======");

      // Initialize result first (always)
      result.signal = 0;
      result.confidence = 0;
      result.analysis = "";
      result.strategyName = GetName();

      // Initialize component scores (always, even if no range)
      result.emaScore = 0;
      result.adxScore = 0;
      result.rsiScore = 0;
      result.csmScore = 0;
      result.priceActionScore = 0;
      result.volumeScore = 0;
      result.mtfScore = 0;
      result.proximityScore = 0;
      result.rejectionScore = 0;
      result.stochasticScore = 0;

      // Step 1: Check if we have an active range
      if(!hasActiveRange)
      {
         result.analysis = "No active range detected";
         if(verboseLogging)
            Print("  No active range for ", symbol);
         return true;  // ✅ Return true with empty components (so dashboard can show 0/X)
      }

      // Step 2: Check price proximity to boundaries
      double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
      bool nearSupport = false;
      bool nearResistance = false;

      double distancePips = CheckBoundaryProximity(symbol, currentPrice, nearSupport, nearResistance);

      if(distancePips < 0)
      {
         result.analysis = "Price mid-range (not near boundaries)";
         if(verboseLogging)
            Print("  Price not near any boundary (mid-range)");
         return true;  // ✅ Return true with empty components
      }

      // SCORE 1: Boundary Proximity (0-15 points)
      if(distancePips <= 3.0)
         result.proximityScore = 15;     // Very close (0-3 pips)
      else if(distancePips <= 5.0)
         result.proximityScore = 12;     // Close (3-5 pips)
      else if(distancePips <= 8.0)
         result.proximityScore = 10;     // Near (5-8 pips)
      else
         result.proximityScore = 7;      // Within zone (8-10 pips)

      result.confidence += result.proximityScore;
      result.analysis += "PROX+" + IntegerToString(result.proximityScore) + " ";

      // Determine direction based on boundary
      if(nearSupport)
      {
         result.signal = 1;     // BUY at support
         result.analysis += "AT_SUPPORT ";
      }
      else if(nearResistance)
      {
         result.signal = -1;     // SELL at resistance
         result.analysis += "AT_RESISTANCE ";
      }

      // SCORE 2: Rejection Pattern (0-15 points)
      bool lookingForBullish = (result.signal == 1);
      result.rejectionScore = DetectRejectionPattern(symbol, timeframe, lookingForBullish);
      result.confidence += result.rejectionScore;
      if(result.rejectionScore > 0)
         result.analysis += "REJ+" + IntegerToString(result.rejectionScore) + " ";

      // SCORE 3: RSI Confirmation (0-20 points)
      double rsi = GetRSI(symbol, timeframe, 14);

      if(result.signal == 1)     // BUY at support
      {
         if(rsi < 30)
            result.rsiScore = 20;     // Oversold (perfect)
         else if(rsi < 40)
            result.rsiScore = 17;     // Below neutral (great)
         else if(rsi < 50)
            result.rsiScore = 14;     // Weakly bullish (good)
         else if(rsi < 60)
            result.rsiScore = 10;     // Neutral zone (acceptable)
         else
            result.rsiScore = 7;      // Above neutral (less ideal)
      }
      else if(result.signal == -1)     // SELL at resistance
      {
         if(rsi > 70)
            result.rsiScore = 20;     // Overbought (perfect)
         else if(rsi > 60)
            result.rsiScore = 17;     // Above neutral (great)
         else if(rsi > 50)
            result.rsiScore = 14;     // Weakly bearish (good)
         else if(rsi > 40)
            result.rsiScore = 10;     // Neutral zone (acceptable)
         else
            result.rsiScore = 7;      // Below neutral (less ideal)
      }

      result.confidence += result.rsiScore;
      result.analysis += "RSI+" + IntegerToString(result.rsiScore) + " ";

      // SCORE 4: Stochastic Confirmation (0-15 points)
      double stochMain = 0, stochSignal = 0;

      if(GetStochastic(symbol, timeframe, stochMain, stochSignal))
      {
         if(result.signal == 1)     // BUY at support
         {
            if(stochMain < 20 && stochMain > stochSignal)
               result.stochasticScore = 15;     // Oversold + crossing up
            else if(stochMain < 30)
               result.stochasticScore = 12;     // Oversold
            else if(stochMain < 50 && stochMain > stochSignal)
               result.stochasticScore = 10;     // Below neutral + crossing up
            else if(stochMain < 50)
               result.stochasticScore = 7;      // Below neutral
         }
         else if(result.signal == -1)     // SELL at resistance
         {
            if(stochMain > 80 && stochMain < stochSignal)
               result.stochasticScore = 15;     // Overbought + crossing down
            else if(stochMain > 70)
               result.stochasticScore = 12;     // Overbought
            else if(stochMain > 50 && stochMain < stochSignal)
               result.stochasticScore = 10;     // Above neutral + crossing down
            else if(stochMain > 50)
               result.stochasticScore = 7;      // Above neutral
         }

         result.confidence += result.stochasticScore;
         if(result.stochasticScore > 0)
            result.analysis += "STOCH+" + IntegerToString(result.stochasticScore) + " ";
      }

      // SCORE 5: CSM Confirmation (0-25 points)
      // At support (BUY), we want base currency weak (negative CSM diff)
      // At resistance (SELL), we want base currency strong (positive CSM diff)
      if(result.signal == 1)     // BUY at support
      {
         // Want negative CSM diff (base oversold)
         if(csmDiff < -20)
            result.csmScore = 25;
         else if(csmDiff < -15)
            result.csmScore = 20;
         else if(csmDiff < -10)
            result.csmScore = 15;
         else if(csmDiff < -5)
            result.csmScore = 10;
         else if(csmDiff < 0)
            result.csmScore = 5;
      }
      else if(result.signal == -1)     // SELL at resistance
      {
         // Want positive CSM diff (base overbought)
         if(csmDiff > 20)
            result.csmScore = 25;
         else if(csmDiff > 15)
            result.csmScore = 20;
         else if(csmDiff > 10)
            result.csmScore = 15;
         else if(csmDiff > 5)
            result.csmScore = 10;
         else if(csmDiff > 0)
            result.csmScore = 5;
      }

      result.confidence += result.csmScore;
      result.analysis += "CSM+" + IntegerToString(result.csmScore);

      // SCORE 6: Volume Confirmation (0-10 points) - BONUS
      if(CheckVolumeConfirmation(symbol, timeframe))
      {
         result.volumeScore = 10;
         result.confidence += result.volumeScore;
         result.analysis += " VOL+10";
      }

      if(verboseLogging)
      {
         Print("Signal: ", result.signal > 0 ? "BUY (Support)" : "SELL (Resistance)");
         Print("Confidence: ", result.confidence, "/100");
         Print("Analysis: ", result.analysis);
      }

      // ✅ Always return true now (with component data), let IsValidSignal() determine tradeability
      return true;
   }

private:
   //+------------------------------------------------------------------+
   //| Check Boundary Proximity                                         |
   //| Returns: distance in pips, or -1 if not near boundary           |
   //+------------------------------------------------------------------+
   double CheckBoundaryProximity(string symbol, double currentPrice, bool &nearSupport, bool &nearResistance)
   {
      double pipSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 3 ||
         SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 5)
         pipSize *= 10;

      double distanceToTop = MathAbs(currentPrice - activeRange.topLevel) / pipSize;
      double distanceToBottom = MathAbs(currentPrice - activeRange.bottomLevel) / pipSize;

      double maxProximityPips = 10.0; // Within 10 pips

      nearSupport = false;
      nearResistance = false;

      if(distanceToBottom <= maxProximityPips)
      {
         nearSupport = true;
         return distanceToBottom;
      }
      else if(distanceToTop <= maxProximityPips)
      {
         nearResistance = true;
         return distanceToTop;
      }

      return -1; // Not near any boundary
   }

   //+------------------------------------------------------------------+
   //| Detect Rejection Pattern (returns 0-15 points)                  |
   //+------------------------------------------------------------------+
   int DetectRejectionPattern(string symbol, ENUM_TIMEFRAMES tf, bool lookingForBullish)
   {
      double open[], high[], low[], close[];
      ArraySetAsSeries(open, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(close, true);

      if(CopyOpen(symbol, tf, 0, 3, open) <= 0) return 0;
      if(CopyHigh(symbol, tf, 0, 3, high) <= 0) return 0;
      if(CopyLow(symbol, tf, 0, 3, low) <= 0) return 0;
      if(CopyClose(symbol, tf, 0, 3, close) <= 0) return 0;

      double body = MathAbs(close[0] - open[0]);
      double totalRange = high[0] - low[0];
      double upperWick = high[0] - MathMax(open[0], close[0]);
      double lowerWick = MathMin(open[0], close[0]) - low[0];

      if(totalRange == 0) return 0;

      int score = 0;

      if(lookingForBullish)
      {
         // Looking for bullish rejection at support
         // Long lower wick = buyers rejecting lower prices

         // Perfect: Lower wick > 2x body, small upper wick, bullish close
         if(lowerWick > body * 2.0 && upperWick < body * 0.5 && close[0] > open[0])
         {
            score = 15;     // Perfect bullish rejection
         }
         // Strong: Lower wick > 1.5x body
         else if(lowerWick > body * 1.5 && close[0] >= open[0])
         {
            score = 12;     // Strong bullish rejection
         }
         // Good: Lower wick dominant, bullish close
         else if(lowerWick > upperWick && lowerWick > body && close[0] > open[0])
         {
            score = 10;     // Good bullish rejection
         }
         // Moderate: Any bullish sign
         else if(close[0] > open[0] && lowerWick > body * 0.5)
         {
            score = 7;      // Moderate bullish
         }
      }
      else
      {
         // Looking for bearish rejection at resistance
         // Long upper wick = sellers rejecting higher prices

         // Perfect: Upper wick > 2x body, small lower wick, bearish close
         if(upperWick > body * 2.0 && lowerWick < body * 0.5 && close[0] < open[0])
         {
            score = 15;     // Perfect bearish rejection
         }
         // Strong: Upper wick > 1.5x body
         else if(upperWick > body * 1.5 && close[0] <= open[0])
         {
            score = 12;     // Strong bearish rejection
         }
         // Good: Upper wick dominant, bearish close
         else if(upperWick > lowerWick && upperWick > body && close[0] < open[0])
         {
            score = 10;     // Good bearish rejection
         }
         // Moderate: Any bearish sign
         else if(close[0] < open[0] && upperWick > body * 0.5)
         {
            score = 7;      // Moderate bearish
         }
      }

      return score;
   }

   //+------------------------------------------------------------------+
   //| Get Stochastic Indicator                                         |
   //+------------------------------------------------------------------+
   bool GetStochastic(string symbol, ENUM_TIMEFRAMES tf, double &main, double &signal)
   {
      int handle = iStochastic(symbol, tf, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
      if(handle == INVALID_HANDLE) return false;

      double mainBuffer[], signalBuffer[];
      ArraySetAsSeries(mainBuffer, true);
      ArraySetAsSeries(signalBuffer, true);

      bool success = false;
      if(CopyBuffer(handle, 0, 0, 2, mainBuffer) > 0 &&
         CopyBuffer(handle, 1, 0, 2, signalBuffer) > 0)
      {
         main = mainBuffer[0];
         signal = signalBuffer[0];
         success = true;
      }

      IndicatorRelease(handle);
      return success;
   }

   //+------------------------------------------------------------------+
   //| Check Volume Confirmation                                        |
   //+------------------------------------------------------------------+
   bool CheckVolumeConfirmation(string symbol, ENUM_TIMEFRAMES tf)
   {
      long volume[];
      ArraySetAsSeries(volume, true);

      int copied = CopyTickVolume(symbol, tf, 0, 16, volume);
      if(copied <= 15) return false;

      long currentVol = volume[0];

      long totalVol = 0;
      for(int i = 1; i <= 15; i++)
      {
         totalVol += volume[i];
      }
      long avgVol = totalVol / 15;

      return (currentVol > avgVol * 1.2);
   }
};
//+------------------------------------------------------------------+
