//+------------------------------------------------------------------+
//|                                   GoldTrendRiderStrategy.mqh     |
//|                                            JcampForexTrader       |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "1.00"
#property strict

#include "../Indicators/EmaCalculator.mqh"
#include "../Indicators/AdxCalculator.mqh"
#include "../Indicators/RsiCalculator.mqh"
#include "../Indicators/AtrCalculator.mqh"
#include "IStrategy.mqh"

//+------------------------------------------------------------------+
//| Gold-Specific TrendRider Strategy                                |
//| Optimized for Gold's unique characteristics:                     |
//|   - ATR-based dynamic SL/TP (not fixed dollar amounts)          |
//|   - Spread-aware confidence scoring                              |
//|   - Higher volatility adaptation                                 |
//|   - Confidence Scoring: 0-135 points (same as TrendRider)       |
//+------------------------------------------------------------------+
class GoldTrendRiderStrategy : public IStrategy
{
private:
   int minConfidence;
   double minCSMDiff;
   bool verboseLogging;

   // Gold-specific parameters
   double atrMultiplierSL;     // ATR multiplier for stop loss (default: 2.0)
   double atrMultiplierTP;     // ATR multiplier for take profit (default: 4.0)
   double minSLDollars;        // Minimum SL in dollars (default: 30)
   double maxSLDollars;        // Maximum SL in dollars (default: 100)
   double spreadPenaltyThreshold;  // Spread threshold for penalty (default: 10 pips)

public:
   GoldTrendRiderStrategy(int minConf = 70,
                          double minCSM = 15.0,
                          bool verbose = false,
                          double atrSL = 2.0,
                          double atrTP = 4.0,
                          double minSL = 30.0,
                          double maxSL = 100.0,
                          double spreadThreshold = 10.0)
   {
      minConfidence = minConf;
      minCSMDiff = minCSM;
      verboseLogging = verbose;
      atrMultiplierSL = atrSL;
      atrMultiplierTP = atrTP;
      minSLDollars = minSL;
      maxSLDollars = maxSL;
      spreadPenaltyThreshold = spreadThreshold;
   }

   ~GoldTrendRiderStrategy() {}

   virtual string GetName() override { return "GOLD_TREND_RIDER"; }
   virtual int GetMinConfidence() override { return minConfidence; }

   //+------------------------------------------------------------------+
   //| Main Analysis Function                                           |
   //+------------------------------------------------------------------+
   virtual bool Analyze(string symbol,
                       ENUM_TIMEFRAMES timeframe,
                       double csmDiff,
                       StrategySignal &result) override
   {
      if(verboseLogging)
         Print("\n====== GOLD TREND RIDER ANALYSIS ======");

      // Calculate indicators
      double ema20 = GetEMA(symbol, timeframe, 20);
      double ema50 = GetEMA(symbol, timeframe, 50);
      double ema100 = GetEMA(symbol, timeframe, 100);
      double adx = GetADX(symbol, timeframe, 14);
      double rsi = GetRSI(symbol, timeframe, 14);
      double atr = GetATR(symbol, timeframe, 14);

      if(ema20 == 0 || ema50 == 0 || ema100 == 0 || atr == 0)
         return false;

      // Get current price and spread
      double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
      double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
      double spreadPips = spread / SymbolInfoDouble(symbol, SYMBOL_POINT) / 10.0;

      // Initialize result
      result.signal = 0;
      result.confidence = 0;
      result.analysis = "";
      result.strategyName = GetName();

      // Check EMA alignment AND price position (same as TrendRider)
      bool bullishEMA = (ema20 > ema50 && ema50 > ema100 && currentPrice > ema20);
      bool bearishEMA = (ema20 < ema50 && ema50 < ema100 && currentPrice < ema20);

      if(bullishEMA)
      {
         result.signal = 1; // BUY
         result.confidence += 30;
         result.analysis += "EMA+30 ";

         // ADX Score (0-25)
         int adxScore = ScoreADX(adx);
         result.confidence += adxScore;
         result.analysis += "ADX+" + IntegerToString(adxScore) + " ";

         // RSI Score (0-20)
         int rsiScore = 0;
         if(rsi > 50 && rsi < 70) rsiScore = 20;
         else if(rsi > 40 && rsi < 80) rsiScore = 10;
         else rsiScore = 5;
         result.confidence += rsiScore;
         result.analysis += "RSI+" + IntegerToString(rsiScore) + " ";

         // CSM Score (0-25)
         int csmScore = ScoreCSM(csmDiff, true);
         result.confidence += csmScore;
         result.analysis += "CSM+" + IntegerToString(csmScore) + " ";

         // Price Action Pattern (bonus 15)
         int paScore = DetectPriceActionPattern(symbol, timeframe);
         if(paScore > 0)
         {
            result.confidence += 15;
            result.analysis += "PA+15 ";
         }

         // Volume Confirmation (bonus 10)
         if(CheckVolumeConfirmation(symbol, timeframe))
         {
            result.confidence += 10;
            result.analysis += "VOL+10 ";
         }

         // MTF Alignment (bonus 10)
         if(CheckMTFAlignment(symbol, result.signal))
         {
            result.confidence += 10;
            result.analysis += "MTF+10 ";
         }

         // Apply spread penalty for wide spreads
         int spreadPenalty = CalculateSpreadPenalty(spreadPips);
         if(spreadPenalty > 0)
         {
            result.confidence -= spreadPenalty;
            result.analysis += "SPREAD-" + IntegerToString(spreadPenalty) + " ";
         }

         // Calculate and store ATR-based SL/TP
         result.stopLossDollars = CalculateStopLoss(symbol, timeframe);
         result.takeProfitDollars = CalculateTakeProfit(symbol, timeframe);
      }
      else if(bearishEMA)
      {
         result.signal = -1; // SELL
         result.confidence += 30;
         result.analysis += "EMA+30 ";

         // ADX Score (0-25)
         int adxScore = ScoreADX(adx);
         result.confidence += adxScore;
         result.analysis += "ADX+" + IntegerToString(adxScore) + " ";

         // RSI Score (0-20)
         int rsiScore = 0;
         if(rsi < 50 && rsi > 30) rsiScore = 20;
         else if(rsi < 60 && rsi > 20) rsiScore = 10;
         else rsiScore = 5;
         result.confidence += rsiScore;
         result.analysis += "RSI+" + IntegerToString(rsiScore) + " ";

         // CSM Score (0-25)
         int csmScore = ScoreCSM(csmDiff, false);
         result.confidence += csmScore;
         result.analysis += "CSM+" + IntegerToString(csmScore) + " ";

         // Price Action Pattern (bonus 15)
         int paScore = DetectPriceActionPattern(symbol, timeframe);
         if(paScore < 0)
         {
            result.confidence += 15;
            result.analysis += "PA+15 ";
         }

         // Volume Confirmation (bonus 10)
         if(CheckVolumeConfirmation(symbol, timeframe))
         {
            result.confidence += 10;
            result.analysis += "VOL+10 ";
         }

         // MTF Alignment (bonus 10)
         if(CheckMTFAlignment(symbol, result.signal))
         {
            result.confidence += 10;
            result.analysis += "MTF+10 ";
         }

         // Apply spread penalty
         int spreadPenalty = CalculateSpreadPenalty(spreadPips);
         if(spreadPenalty > 0)
         {
            result.confidence -= spreadPenalty;
            result.analysis += "SPREAD-" + IntegerToString(spreadPenalty) + " ";
         }

         // Calculate and store ATR-based SL/TP
         result.stopLossDollars = CalculateStopLoss(symbol, timeframe);
         result.takeProfitDollars = CalculateTakeProfit(symbol, timeframe);
      }
      else
      {
         return false; // No clear trend
      }

      if(verboseLogging)
      {
         Print("Signal: ", result.signal > 0 ? "BUY" : "SELL");
         Print("Confidence: ", result.confidence, "/135 (after spread penalty)");
         Print("ATR: $", DoubleToString(atr, 2), " | Spread: ", DoubleToString(spreadPips, 1), " pips");
         Print("Analysis: ", result.analysis);
      }

      return IsValidSignal(result);
   }

   //+------------------------------------------------------------------+
   //| Calculate ATR-based Stop Loss (in dollars)                       |
   //+------------------------------------------------------------------+
   double CalculateStopLoss(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      double atr = GetATR(symbol, timeframe, 14);
      if(atr == 0) return minSLDollars;

      double sl = atr * atrMultiplierSL;

      // Clamp to min/max
      if(sl < minSLDollars) sl = minSLDollars;
      if(sl > maxSLDollars) sl = maxSLDollars;

      return sl;
   }

   //+------------------------------------------------------------------+
   //| Calculate ATR-based Take Profit (in dollars)                     |
   //+------------------------------------------------------------------+
   double CalculateTakeProfit(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      double atr = GetATR(symbol, timeframe, 14);
      if(atr == 0) return minSLDollars * 2.0;

      double tp = atr * atrMultiplierTP;

      // Ensure minimum 2:1 risk:reward
      double sl = CalculateStopLoss(symbol, timeframe);
      if(tp < sl * 2.0) tp = sl * 2.0;

      return tp;
   }

private:
   //+------------------------------------------------------------------+
   //| Score ADX (0-25 points) - Same as TrendRider                     |
   //+------------------------------------------------------------------+
   int ScoreADX(double adx)
   {
      if(adx > 50) return 25;
      else if(adx > 40) return 23;
      else if(adx > 30) return 20;
      else if(adx > 25) return 15;
      else return 5;
   }

   //+------------------------------------------------------------------+
   //| Score CSM Confirmation (0-25 points) - Same as TrendRider        |
   //+------------------------------------------------------------------+
   int ScoreCSM(double csmDiff, bool isBuy)
   {
      if(isBuy) // Want positive CSM (base strong)
      {
         if(csmDiff > 20) return 25;
         else if(csmDiff > 15) return 20;
         else if(csmDiff > 10) return 15;
         else if(csmDiff > 5) return 10;
         else return 5;
      }
      else // Want negative CSM (base weak)
      {
         if(csmDiff < -20) return 25;
         else if(csmDiff < -15) return 20;
         else if(csmDiff < -10) return 15;
         else if(csmDiff < -5) return 10;
         else return 5;
      }
   }

   //+------------------------------------------------------------------+
   //| Calculate Spread Penalty (GOLD-SPECIFIC)                         |
   //| Reduces confidence when spread is too wide                       |
   //| Penalty: -5 points for every 5 pips over threshold               |
   //+------------------------------------------------------------------+
   int CalculateSpreadPenalty(double spreadPips)
   {
      if(spreadPips <= spreadPenaltyThreshold)
         return 0;

      double excessSpread = spreadPips - spreadPenaltyThreshold;
      int penalty = (int)(excessSpread / 5.0) * 5;  // -5 per 5 pips

      // Cap penalty at 30 points (don't completely kill confidence)
      if(penalty > 30) penalty = 30;

      return penalty;
   }

   //+------------------------------------------------------------------+
   //| Detect Price Action Pattern (same as TrendRider)                 |
   //+------------------------------------------------------------------+
   int DetectPriceActionPattern(string symbol, ENUM_TIMEFRAMES tf)
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

      // Bullish patterns
      if(close[0] > open[0])
      {
         if(lowerWick > body * 2 && upperWick < body * 0.3) return 1;  // Hammer
         if(body > totalRange * 0.7) return 1;  // Strong bullish candle
      }
      // Bearish patterns
      else if(close[0] < open[0])
      {
         if(upperWick > body * 2 && lowerWick < body * 0.3) return -1;  // Shooting star
         if(body > totalRange * 0.7) return -1;  // Strong bearish candle
      }

      return 0;
   }

   //+------------------------------------------------------------------+
   //| Check Volume Confirmation (same as TrendRider)                   |
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
         totalVol += volume[i];

      long avgVol = totalVol / 15;

      return (currentVol > avgVol * 1.2);
   }

   //+------------------------------------------------------------------+
   //| Check Multi-Timeframe Alignment (same as TrendRider)             |
   //+------------------------------------------------------------------+
   bool CheckMTFAlignment(string symbol, int signal)
   {
      double ema20_h4 = GetEMA(symbol, PERIOD_H4, 20);
      double ema50_h4 = GetEMA(symbol, PERIOD_H4, 50);

      if(ema20_h4 == 0 || ema50_h4 == 0)
         return false;

      bool h4Bullish = (ema20_h4 > ema50_h4);
      bool h4Bearish = (ema20_h4 < ema50_h4);

      if(signal == 1 && h4Bullish) return true;
      if(signal == -1 && h4Bearish) return true;

      return false;
   }
};
//+------------------------------------------------------------------+
