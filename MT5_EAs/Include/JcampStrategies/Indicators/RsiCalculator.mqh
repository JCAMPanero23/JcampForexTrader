//+------------------------------------------------------------------+
//|                                              RsiCalculator.mqh   |
//|                                   Jcamp Forex Trading System     |
//+------------------------------------------------------------------+
//| Description: RSI (Relative Strength Index) calculation           |
//| Usage: #include <JcampStrategies/Indicators/RsiCalculator.mqh>   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get RSI value for specified symbol, timeframe, and period        |
//| Returns: RSI value, or 50 (neutral) on error                     |
//+------------------------------------------------------------------+
double GetRSI(string symbol, ENUM_TIMEFRAMES tf, int period)
{
    int handle = iRSI(symbol, tf, period, PRICE_CLOSE);
    if(handle == INVALID_HANDLE) return 50;

    double buffer[];
    ArraySetAsSeries(buffer, true);

    if(CopyBuffer(handle, 0, 0, 1, buffer) <= 0)
    {
        IndicatorRelease(handle);
        return 50;
    }

    IndicatorRelease(handle);
    return buffer[0];
}
