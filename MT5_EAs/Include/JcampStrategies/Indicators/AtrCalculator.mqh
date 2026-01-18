//+------------------------------------------------------------------+
//|                                              AtrCalculator.mqh   |
//|                                   Jcamp Forex Trading System     |
//+------------------------------------------------------------------+
//| Description: ATR (Average True Range) calculation                |
//| Usage: #include <JcampStrategies/Indicators/AtrCalculator.mqh>   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get ATR value for specified symbol, timeframe, and period        |
//| Returns: ATR value, or 0 on error                                |
//+------------------------------------------------------------------+
double GetATR(string symbol, ENUM_TIMEFRAMES tf, int period)
{
    int handle = iATR(symbol, tf, period);
    if(handle == INVALID_HANDLE) return 0;

    double buffer[];
    ArraySetAsSeries(buffer, true);

    if(CopyBuffer(handle, 0, 0, 1, buffer) <= 0)
    {
        IndicatorRelease(handle);
        return 0;
    }

    IndicatorRelease(handle);
    return buffer[0];
}
