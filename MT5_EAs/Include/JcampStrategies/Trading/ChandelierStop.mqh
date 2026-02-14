//+------------------------------------------------------------------+
//|                                            ChandelierStop.mqh     |
//|                                            JcampForexTrader       |
//|                    Session 21 - Market Structure-Based Trailing  |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Chandelier Stop Class                                             |
//| Market structure-based trailing stop                              |
//| SL = Highest High (20 bars) - (2.5 × ATR)  [for BUY]             |
//| SL = Lowest Low (20 bars) + (2.5 × ATR)    [for SELL]            |
//+------------------------------------------------------------------+
class CChandelierStop
{
private:
    int      lookbackBars;       // Number of bars for HH/LL (default: 20)
    double   atrMultiplier;      // ATR multiplier (default: 2.5)
    ENUM_TIMEFRAMES timeframe;   // Timeframe for calculation (default: H1)
    int      atrPeriod;          // ATR period (default: 14)

public:
    //+------------------------------------------------------------------+
    //| Constructor                                                       |
    //+------------------------------------------------------------------+
    CChandelierStop(int lookback = 20,
                    double atrMult = 2.5,
                    ENUM_TIMEFRAMES tf = PERIOD_H1,
                    int atrPer = 14)
    {
        lookbackBars = lookback;
        atrMultiplier = atrMult;
        timeframe = tf;
        atrPeriod = atrPer;
    }

    ~CChandelierStop() {}

    //+------------------------------------------------------------------+
    //| Calculate Chandelier SL for BUY Position                         |
    //| SL = Highest High (lookback) - (atrMultiplier × ATR)            |
    //+------------------------------------------------------------------+
    double CalculateBuySL(string symbol)
    {
        // Get Highest High over lookback bars
        double highestHigh = GetHighestHigh(symbol, lookbackBars);
        if(highestHigh <= 0)
        {
            Print("ERROR: Failed to get Highest High for ", symbol);
            return 0;
        }

        // Get ATR
        double atr = GetATR(symbol);
        if(atr <= 0)
        {
            Print("ERROR: Failed to get ATR for ", symbol);
            return 0;
        }

        // Calculate Chandelier SL
        double chandelierSL = highestHigh - (atrMultiplier * atr);

        // Normalize price
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        chandelierSL = NormalizeDouble(chandelierSL, digits);

        return chandelierSL;
    }

    //+------------------------------------------------------------------+
    //| Calculate Chandelier SL for SELL Position                        |
    //| SL = Lowest Low (lookback) + (atrMultiplier × ATR)              |
    //+------------------------------------------------------------------+
    double CalculateSellSL(string symbol)
    {
        // Get Lowest Low over lookback bars
        double lowestLow = GetLowestLow(symbol, lookbackBars);
        if(lowestLow <= 0)
        {
            Print("ERROR: Failed to get Lowest Low for ", symbol);
            return 0;
        }

        // Get ATR
        double atr = GetATR(symbol);
        if(atr <= 0)
        {
            Print("ERROR: Failed to get ATR for ", symbol);
            return 0;
        }

        // Calculate Chandelier SL
        double chandelierSL = lowestLow + (atrMultiplier * atr);

        // Normalize price
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        chandelierSL = NormalizeDouble(chandelierSL, digits);

        return chandelierSL;
    }

    //+------------------------------------------------------------------+
    //| Check if Chandelier SL should update current SL                  |
    //| Only update if new SL is better (higher for BUY, lower for SELL) |
    //+------------------------------------------------------------------+
    bool ShouldUpdate(double currentSL,
                      double newSL,
                      ENUM_POSITION_TYPE posType)
    {
        if(newSL <= 0 || currentSL <= 0)
            return false;

        // BUY: New SL must be higher than current
        if(posType == POSITION_TYPE_BUY && newSL > currentSL)
            return true;

        // SELL: New SL must be lower than current
        if(posType == POSITION_TYPE_SELL && newSL < currentSL)
            return true;

        return false;
    }

    //+------------------------------------------------------------------+
    //| Get Chandelier Distance from Entry (for profit lock calculation) |
    //+------------------------------------------------------------------+
    double GetChandelierDistance(string symbol, double entryPrice, ENUM_POSITION_TYPE posType)
    {
        double chandelierSL = 0;
        if(posType == POSITION_TYPE_BUY)
            chandelierSL = CalculateBuySL(symbol);
        else
            chandelierSL = CalculateSellSL(symbol);

        if(chandelierSL <= 0)
            return 0;

        return MathAbs(entryPrice - chandelierSL);
    }

private:
    //+------------------------------------------------------------------+
    //| Get Highest High over specified bars                             |
    //+------------------------------------------------------------------+
    double GetHighestHigh(string symbol, int bars)
    {
        double highBuffer[];
        ArraySetAsSeries(highBuffer, true);

        if(CopyHigh(symbol, timeframe, 0, bars, highBuffer) != bars)
            return 0;

        int maxIndex = ArrayMaximum(highBuffer, 0, WHOLE_ARRAY);
        return highBuffer[maxIndex];
    }

    //+------------------------------------------------------------------+
    //| Get Lowest Low over specified bars                               |
    //+------------------------------------------------------------------+
    double GetLowestLow(string symbol, int bars)
    {
        double lowBuffer[];
        ArraySetAsSeries(lowBuffer, true);

        if(CopyLow(symbol, timeframe, 0, bars, lowBuffer) != bars)
            return 0;

        int minIndex = ArrayMinimum(lowBuffer, 0, WHOLE_ARRAY);
        return lowBuffer[minIndex];
    }

    //+------------------------------------------------------------------+
    //| Get ATR value                                                     |
    //+------------------------------------------------------------------+
    double GetATR(string symbol)
    {
        int atrHandle = iATR(symbol, timeframe, atrPeriod);
        if(atrHandle == INVALID_HANDLE)
            return 0;

        double atrBuffer[];
        ArraySetAsSeries(atrBuffer, true);

        if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) != 1)
            return 0;

        return atrBuffer[0];
    }
};
//+------------------------------------------------------------------+
