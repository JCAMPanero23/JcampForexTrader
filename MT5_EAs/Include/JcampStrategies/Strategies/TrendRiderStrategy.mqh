//+------------------------------------------------------------------+
//|                                        TrendRiderStrategy.mqh     |
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
//| TrendRider Strategy Implementation                               |
//| Confidence Scoring System: 0-135 points                          |
//|   - EMA Alignment: 30 points                                     |
//|   - ADX Strength: 0-25 points                                    |
//|   - RSI Momentum: 0-20 points                                    |
//|   - CSM Confirmation: 0-25 points                                |
//|   - Price Action: 15 points (bonus)                              |
//|   - Volume: 10 points (bonus)                                    |
//|   - MTF Alignment: 10 points (bonus)                             |
//+------------------------------------------------------------------+
class TrendRiderStrategy : public IStrategy
{
private:
   int minConfidence;
   double minCSMDiff;
   bool verboseLogging;

public:
   TrendRiderStrategy(int minConf = 65, double minCSM = 15.0, bool verbose = false)
   {
      minConfidence = minConf;
      minCSMDiff = minCSM;
      verboseLogging = verbose;
   }

   ~TrendRiderStrategy() {}

   virtual string GetName() override { return "TREND_RIDER"; }
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
         Print("\n====== TREND RIDER ANALYSIS ======");

      // Calculate indicators using functions (not classes)
      double ema20 = GetEMA(symbol, timeframe, 20);
      double ema50 = GetEMA(symbol, timeframe, 50);
      double ema100 = GetEMA(symbol, timeframe, 100);
      double adx = GetADX(symbol, timeframe, 14);
      double rsi = GetRSI(symbol, timeframe, 14);

      if(ema20 == 0 || ema50 == 0 || ema100 == 0)
         return false;

      // Get current price for direction validation
      double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);

      // Initialize result
      result.signal = 0;
      result.confidence = 0;
      result.analysis = "";
      result.strategyName = GetName();

      // Check EMA alignment AND price position
      // BUY: EMAs bullish aligned AND price above EMA20
      // SELL: EMAs bearish aligned AND price below EMA20
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
      }
      else
      {
         return false; // No clear trend
      }

      if(verboseLogging)
      {
         Print("Signal: ", result.signal > 0 ? "BUY" : "SELL");
         Print("Confidence: ", result.confidence, "/135");
         Print("Analysis: ", result.analysis);
      }

      return IsValidSignal(result);
   }

private:
   //+------------------------------------------------------------------+
   //| Score ADX (0-25 points)                                          |
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
   //| Score CSM Confirmation (0-25 points)                             |
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
   //| Detect Price Action Pattern (returns +1 bullish, -1 bearish)    |
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
         // Hammer (long lower wick)
         if(lowerWick > body * 2 && upperWick < body * 0.3)
            return 1;
         // Strong bullish candle
         if(body > totalRange * 0.7)
            return 1;
      }
      // Bearish patterns
      else if(close[0] < open[0])
      {
         // Shooting star (long upper wick)
         if(upperWick > body * 2 && lowerWick < body * 0.3)
            return -1;
         // Strong bearish candle
         if(body > totalRange * 0.7)
            return -1;
      }

      return 0;
   }

   //+------------------------------------------------------------------+
   //| Check Volume Confirmation (current > 1.2x average)              |
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

   //+------------------------------------------------------------------+
   //| Check Multi-Timeframe Alignment (H4 EMA alignment)              |
   //+------------------------------------------------------------------+
   bool CheckMTFAlignment(string symbol, int signal)
   {
      double ema20_h4 = GetEMA(symbol, PERIOD_H4, 20);
      double ema50_h4 = GetEMA(symbol, PERIOD_H4, 50);

      if(ema20_h4 == 0 || ema50_h4 == 0)
         return false;

      bool h4Bullish = (ema20_h4 > ema50_h4);
      bool h4Bearish = (ema20_h4 < ema50_h4);

      bool aligned = false;
      if(signal == 1 && h4Bullish)
         aligned = true;
      else if(signal == -1 && h4Bearish)
         aligned = true;

      return aligned;
   }
};
//+------------------------------------------------------------------+
