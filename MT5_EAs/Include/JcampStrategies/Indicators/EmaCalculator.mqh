//+------------------------------------------------------------------+
//|                                              EmaCalculator.mqh   |
//|                                   Jcamp Forex Trading System     |
//+------------------------------------------------------------------+
//| Description: EMA (Exponential Moving Average) calculation        |
//| Usage: #include <JcampStrategies/Indicators/EmaCalculator.mqh>   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get EMA value for specified symbol, timeframe, and period        |
//| Returns: EMA value, or 0 on error                                |
//+------------------------------------------------------------------+
double GetEMA(string symbol, ENUM_TIMEFRAMES tf, int period)
{
    int handle = iMA(symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
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

//+------------------------------------------------------------------+
//| Calculate EMA separation as percentage                           |
//| Returns: Average separation between EMAs as % of price           |
//+------------------------------------------------------------------+
double CalculateEMASeparation(string symbol, double ema20, double ema50, double ema100)
{
    if(ema20 == 0 || ema50 == 0) return 0;

    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    if(currentPrice == 0) return 0;

    // Calculate separation between EMAs as percentage of price
    double sep_20_50 = MathAbs(ema20 - ema50) / currentPrice * 100.0;

    if(ema100 > 0)
    {
        double sep_50_100 = MathAbs(ema50 - ema100) / currentPrice * 100.0;
        return (sep_20_50 + sep_50_100) / 2.0;  // Average separation
    }

    return sep_20_50;
}
